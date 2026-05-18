#!/bin/sh
# Ariba NOC Center - Self-healing Watchdog
# Monitors containers and sends Telegram alerts on failures.
# Requires: Docker socket mount, curl, TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID env vars.
set -eu

TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
CHECK_INTERVAL="${CHECK_INTERVAL:-30}"

log() { echo "[watchdog] $(date '+%Y-%m-%d %H:%M:%S') $*"; }

telegram_notify() {
  local msg="$1"
  if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    curl -sSf "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d chat_id="$TELEGRAM_CHAT_ID" \
      -d parse_mode="Markdown" \
      --data-urlencode text="$msg" \
      -o /dev/null 2>/dev/null || true
  fi
}

log "Watchdog started. Checking every ${CHECK_INTERVAL}s"
telegram_notify "✅ *NOC Watchdog started* on $(hostname)"

while true; do
  docker ps -a --format '{{.Names}}\t{{.Status}}' 2>/dev/null | while IFS='	' read -r name status; do
    # Skip the watchdog container itself
    case "$name" in
      noc-watchdog) continue ;;
    esac

    case "$status" in
      Up*|running*)
        # Container is healthy — reset counter if previously failing
        ;;
      Exited*|Dead*|Created*)
        log "Container $name is down (status: $status). Attempting restart..."
        if docker restart "$name" >/dev/null 2>&1; then
          log "Restarted $name successfully"
          telegram_notify "⚠️ *NOC Watchdog*: Container \`$name\` was down and has been *restarted*."
        else
          log "Failed to restart $name"
          telegram_notify "🚨 *NOC Watchdog*: Container \`$name\` is down and *could not be restarted*. Manual intervention required!"
        fi
        ;;
      Restarting*)
        log "Container $name is in restart loop: $status"
        telegram_notify "🔄 *NOC Watchdog*: Container \`$name\` is in a *restart loop*. Status: $status"
        ;;
    esac
  done

  sleep "$CHECK_INTERVAL"
done

