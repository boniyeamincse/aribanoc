#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "[ERROR] Docker Compose not found. Install Docker Compose first." >&2
  exit 1
fi

run_compose() {
  (cd "$PROJECT_DIR" && "${COMPOSE_CMD[@]}" "$@")
}

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Ariba NOC Center - Container Management CLI

Usage:
  ./scripts/nocctl.sh <command> [args]

Commands:
  help                            Show this help
  status                          Show compose service status
  services                        List all compose services
  up                              Start all services
  down                            Stop and remove compose stack
  pull                            Pull latest images
  start <service|all>             Start a service (or all)
  stop <service|all>              Stop a service (or all)
  restart <service|all>           Restart a service (or all)
  logs <service> [lines]          Follow logs for service (default lines: 200)
  shell <service>                 Open interactive shell in service container
  exec <service> <command...>     Run command in service container
  inspect <service>               Show docker inspect output for service container
  health                          Show health status for all service containers
  doctor                          Troubleshooting summary (config, status, failures)

Examples:
  ./scripts/nocctl.sh status
  ./scripts/nocctl.sh logs logstash 300
  ./scripts/nocctl.sh restart prometheus
  ./scripts/nocctl.sh doctor
EOF
}

require_arg() {
  local value="${1:-}"
  local name="$2"
  [[ -n "$value" ]] || die "Missing required argument: $name"
}

get_container_id() {
  local service="$1"
  run_compose ps -q "$service"
}

cmd_status() {
  run_compose ps
}

cmd_services() {
  run_compose config --services
}

cmd_up() {
  run_compose up -d
}

cmd_down() {
  run_compose down
}

cmd_pull() {
  run_compose pull
}

cmd_start() {
  local target="${1:-}"
  require_arg "$target" "service|all"
  if [[ "$target" == "all" ]]; then
    run_compose start
  else
    run_compose start "$target"
  fi
}

cmd_stop() {
  local target="${1:-}"
  require_arg "$target" "service|all"
  if [[ "$target" == "all" ]]; then
    run_compose stop
  else
    run_compose stop "$target"
  fi
}

cmd_restart() {
  local target="${1:-}"
  require_arg "$target" "service|all"
  if [[ "$target" == "all" ]]; then
    run_compose restart
  else
    run_compose restart "$target"
  fi
}

cmd_logs() {
  local service="${1:-}"
  local lines="${2:-200}"
  require_arg "$service" "service"
  run_compose logs --tail "$lines" -f "$service"
}

cmd_shell() {
  local service="${1:-}"
  require_arg "$service" "service"

  local container_id
  container_id="$(get_container_id "$service")"
  [[ -n "$container_id" ]] || die "Service '$service' is not running."

  if docker exec -it "$container_id" sh -c 'command -v bash >/dev/null 2>&1'; then
    docker exec -it "$container_id" bash
  else
    docker exec -it "$container_id" sh
  fi
}

cmd_exec() {
  local service="${1:-}"
  shift || true
  require_arg "$service" "service"
  [[ "$#" -gt 0 ]] || die "Missing command to execute"

  local container_id
  container_id="$(get_container_id "$service")"
  [[ -n "$container_id" ]] || die "Service '$service' is not running."
  docker exec -it "$container_id" "$@"
}

cmd_inspect() {
  local service="${1:-}"
  require_arg "$service" "service"

  local container_id
  container_id="$(get_container_id "$service")"
  [[ -n "$container_id" ]] || die "Service '$service' is not running."
  docker inspect "$container_id"
}

cmd_health() {
  local services
  services="$(run_compose config --services)"
  if [[ -z "$services" ]]; then
    die "No services found in compose config."
  fi

  printf "%-20s %-12s %-20s\n" "SERVICE" "STATE" "HEALTH"
  printf "%-20s %-12s %-20s\n" "-------" "-----" "------"

  while IFS= read -r svc; do
    [[ -z "$svc" ]] && continue
    cid="$(run_compose ps -q "$svc")"
    if [[ -z "$cid" ]]; then
      printf "%-20s %-12s %-20s\n" "$svc" "stopped" "n/a"
      continue
    fi
    state="$(docker inspect -f '{{.State.Status}}' "$cid" 2>/dev/null || echo unknown)"
    health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$cid" 2>/dev/null || echo unknown)"
    printf "%-20s %-12s %-20s\n" "$svc" "$state" "$health"
  done <<< "$services"
}

cmd_doctor() {
  echo "== Ariba NOC Doctor =="
  echo

  echo "[1/5] Compose configuration"
  if run_compose config --quiet; then
    echo "OK: docker compose config is valid"
  else
    die "Compose configuration is invalid."
  fi
  echo

  echo "[2/5] Service status"
  run_compose ps
  echo

  echo "[3/5] Non-running services"
  failed_services="$(run_compose ps --services --filter status=exited)"
  if [[ -z "$failed_services" ]]; then
    echo "OK: no exited services"
  else
    echo "WARNING: exited services detected:"
    echo "$failed_services"
  fi
  echo

  echo "[4/5] Health snapshot"
  cmd_health
  echo

  echo "[5/5] Tail logs for unhealthy/exited services"
  problem_services=""
  all_services="$(run_compose config --services)"
  while IFS= read -r svc; do
    [[ -z "$svc" ]] && continue
    cid="$(run_compose ps -q "$svc")"
    [[ -z "$cid" ]] && continue
    state="$(docker inspect -f '{{.State.Status}}' "$cid" 2>/dev/null || echo unknown)"
    health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$cid" 2>/dev/null || echo unknown)"
    if [[ "$state" != "running" || "$health" == "unhealthy" ]]; then
      problem_services+="$svc "$'\n'
    fi
  done <<< "$all_services"

  if [[ -z "${problem_services// }" ]]; then
    echo "OK: no unhealthy or stopped running containers detected"
  else
    while IFS= read -r svc; do
      [[ -z "$svc" ]] && continue
      echo "--- logs: $svc (last 80 lines) ---"
      run_compose logs --tail 80 "$svc" || true
      echo
    done <<< "$problem_services"
  fi
}

main() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    help|-h|--help) usage ;;
    status) cmd_status ;;
    services) cmd_services ;;
    up) cmd_up ;;
    down) cmd_down ;;
    pull) cmd_pull ;;
    start) cmd_start "$@" ;;
    stop) cmd_stop "$@" ;;
    restart) cmd_restart "$@" ;;
    logs) cmd_logs "$@" ;;
    shell) cmd_shell "$@" ;;
    exec) cmd_exec "$@" ;;
    inspect) cmd_inspect "$@" ;;
    health) cmd_health ;;
    doctor) cmd_doctor ;;
    *)
      usage
      die "Unknown command: $cmd"
      ;;
  esac
}

main "$@"