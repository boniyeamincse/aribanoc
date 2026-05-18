#!/bin/bash
# Ariba NOC Center - First-time Setup Script
# Run this ONCE before `docker compose up -d`
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

info()    { echo -e "\033[0;32m[INFO]\033[0m  $*"; }
warn()    { echo -e "\033[0;33m[WARN]\033[0m  $*"; }
error()   { echo -e "\033[0;31m[ERROR]\033[0m $*"; exit 1; }

info "=== Ariba NOC Center Setup ==="
cd "$PROJECT_DIR"

# ── 1. Check prerequisites ────────────────────────────────────────────────────
command -v docker >/dev/null 2>&1   || error "Docker not found. Install Docker first."
command -v docker-compose >/dev/null 2>&1 || \
  docker compose version >/dev/null 2>&1   || error "Docker Compose not found."

# ── 2. Create .env from .env.example ─────────────────────────────────────────
if [ ! -f ".env" ]; then
  cp .env.example .env
  warn ".env created from .env.example — edit it and set your secrets before continuing!"
  warn "  Required: ELASTIC_PASSWORD, NETBOX_SECRET_KEY, alert credentials"
  read -rp "Press Enter after editing .env to continue, or Ctrl+C to abort... " _
else
  info ".env already exists, skipping."
fi

# ── 3. Create required host directories ───────────────────────────────────────
info "Creating host directories..."
mkdir -p suricata/log suricata/var-lib \
         librenms/rrd \
         zabbix/alertscripts zabbix/externalscripts \
         elk/filebeat

# ── 4. Fix permissions ────────────────────────────────────────────────────────
info "Setting permissions on alertscripts..."
chmod +x zabbix/alertscripts/telegram.sh
chmod +x zabbix/alertscripts/email.sh
chmod +x scripts/watchdog.sh
chmod +x scripts/nocctl.sh

# ── 5. Tune kernel parameters for Elasticsearch ───────────────────────────────
info "Tuning kernel parameters for Elasticsearch (vm.max_map_count)..."
current_mmc=$(sysctl -n vm.max_map_count 2>/dev/null || echo 0)
if [ "$current_mmc" -lt 262144 ]; then
  sudo sysctl -w vm.max_map_count=262144
  # Persist across reboots
  grep -q vm.max_map_count /etc/sysctl.conf || echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
  info "vm.max_map_count set to 262144"
else
  info "vm.max_map_count already adequate ($current_mmc)"
fi

# ── 6. Pull images ────────────────────────────────────────────────────────────
info "Pulling Docker images (this may take a few minutes)..."
docker compose pull --quiet

# ── 7. Start core services first (DB + ES need to warm up) ────────────────────
info "Starting database and Elasticsearch services..."
docker compose up -d zabbix-db librenms-db netbox-db redis elasticsearch
info "Waiting 30s for databases to initialise..."
sleep 30

# ── 8. Start remaining services ───────────────────────────────────────────────
info "Starting all services..."
docker compose up -d

info ""
info "=== Setup Complete ==="
info "Service URLs:"
info "  Grafana:       http://localhost:3000  (admin / see GF_SECURITY_ADMIN_PASSWORD in .env)"
info "  Prometheus:    http://localhost:9090"
info "  Alertmanager:  http://localhost:9093"
info "  Kibana:        http://localhost:5601"
info "  Zabbix Web:    http://localhost:8090  (Admin / zabbix)"
info "  LibreNMS:      http://localhost:8000"
info "  NetBox:        http://localhost:8080"
info "  ntopng:        http://localhost:3001"
info ""
warn "Next steps:"
warn "  1. Log into Zabbix and configure Telegram/email media type using scripts in zabbix/alertscripts/"
warn "  2. In LibreNMS, go to Devices → Add Device to start SNMP discovery"
warn "  3. In NetBox, create your network topology under Infrastructure"
warn "  4. Review Grafana dashboards at http://localhost:3000"
warn "  5. Use scripts/nocctl.sh for troubleshooting and container management"
