# Ariba NOC Center — Setup Guide

## Prerequisites

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| Docker | 24+ | latest |
| Docker Compose | v2.20+ | latest |
| RAM | 8 GB | 16 GB |
| Disk | 40 GB | 100 GB SSD |
| OS | Linux (Ubuntu 22.04+) | Ubuntu 22.04 LTS |
| CPU | 4 cores | 8 cores |

## Quick Start

```bash
# 1. Clone / enter the project directory
cd /home/boni/Desktop/SOC_Akij/noc

# 2. Preferred: auto-installer (installs Docker/Compose and required tools)
bash install.sh

# 3. OR run setup directly if dependencies already exist
bash scripts/setup.sh

# 4. OR fully manual startup:
cp .env.example .env
# Edit .env — fill in passwords and alert credentials
nano .env

# Tune kernel for Elasticsearch
sudo sysctl -w vm.max_map_count=262144

# Create required host directories
mkdir -p suricata/log suricata/var-lib librenms/rrd

# Set alertscript permissions
chmod +x zabbix/alertscripts/*.sh scripts/watchdog.sh

# Start all services
docker compose up -d

# Optional: start watchdog (disabled by default for security)
docker compose --profile ops up -d watchdog
```

Security defaults in this stack:

- `BIND_ADDRESS=127.0.0.1` binds web ports to localhost by default.
- Watchdog is placed behind the `ops` profile because it mounts the Docker socket.
- Critical secrets are required from `.env` (no insecure runtime fallback values).

## Service-by-Service Configuration

## Container Management and Troubleshooting CLI

Ariba NOC Center includes a built-in operations CLI:

```bash
./scripts/nocctl.sh help
./scripts/nocctl.sh status
./scripts/nocctl.sh health
./scripts/nocctl.sh doctor
./scripts/nocctl.sh logs elasticsearch 200
./scripts/nocctl.sh restart all
```

Common workflow:

1. Run `./scripts/nocctl.sh doctor` for quick diagnostics.
2. Check failing service logs with `./scripts/nocctl.sh logs <service> 300`.
3. Restart only affected service with `./scripts/nocctl.sh restart <service>`.
4. Re-check health with `./scripts/nocctl.sh health`.

### Grafana (Port 3000)

1. Open `http://localhost:3000`
2. Login: `admin` / `<GF_SECURITY_ADMIN_PASSWORD from .env>`
3. Dashboards are auto-provisioned:
   - **NOC Overview** — CPU, RAM, Disk, Network per host
   - **Suricata IDS** — Alert counts, top signatures, geo map
   - **Node Exporter** — Detailed host metrics
4. Alerting is pre-configured to route to Telegram/Email (set `ALERT_TELEGRAM_BOT_TOKEN` + `ALERT_TELEGRAM_CHAT_ID` in `.env`)

### Prometheus (Port 9090)

- Prometheus scrapes `node_exporter` every 15 seconds
- Alert rules in `prometheus/alerts/`:
  - `node.yml` — CPU, memory, disk, network interface alerts
  - `network.yml` — Traffic spike, high bandwidth, packet drop alerts
- To add more scrape targets, edit `prometheus/prometheus.yml` and reload:
  ```bash
  curl -X POST http://localhost:9090/-/reload
  ```

### Alertmanager (Port 9093)

1. Edit `alertmanager/alertmanager.yml` to configure routes
2. Set env vars in `.env`:
   ```
   ALERT_TELEGRAM_BOT_TOKEN=<your_bot_token>
   ALERT_TELEGRAM_CHAT_ID=<your_chat_id>
   ALERT_SMTP_HOST=smtp.gmail.com
   ALERT_SMTP_USER=you@gmail.com
   ALERT_SMTP_PASS=<app_password>
   ALERT_EMAIL_TO=oncall@example.com
   ```
3. Reload: `docker compose restart alertmanager`

**Getting Telegram credentials:**
```bash
# 1. Message @BotFather on Telegram → /newbot
# 2. Get your chat_id:
curl "https://api.telegram.org/bot<TOKEN>/getUpdates"
```

### Zabbix (Port 8090)

1. Open `http://localhost:8090`
2. Login: `Admin` / `zabbix` (change immediately)
3. **Add a host:** Configuration → Hosts → Create Host
4. **Configure Telegram alerts:**
   - Administration → Media Types → Create media type
   - Type: Script, Script name: `telegram.sh`
   - Parameters: `{SEND_TO}`, `{SUBJECT}`, `{MESSAGE}`
   - Users → Admin → Media → Add → Type: your Telegram script
   - Set "Send to" = your Telegram chat_id
5. **Configure SNMP monitoring:**
   - Add network device with SNMP interface
   - Attach template: "Cisco IOS" / "HP Procurve" / "Generic SNMP"

### LibreNMS (Port 8000)

1. Open `http://localhost:8000`
2. Create admin account on first launch
3. **Add devices:**
   - Devices → Add Device
   - Enter IP, SNMP community (default: `public`)
4. **Auto-discovery:**
   - Settings → Network Discovery → Enable
   - Set network ranges: `192.168.0.0/16`, `10.0.0.0/8`
5. **Alert rules:**
   - Alerts → Alert Rules → Add Rule
   - Example: "Device Down" — `%devices.status != 1`

### Kibana (Port 5601)

1. Open `http://localhost:5601`
2. Login: `elastic` / `<ELASTIC_PASSWORD from .env>`
3. **Create index patterns:**
   - Stack Management → Index Patterns → Create
   - Pattern: `noc-suricata-*` (time field: `@timestamp`)
   - Pattern: `noc-syslog-*`
   - Pattern: `noc-system-*`
4. **Discover logs:** Analytics → Discover → select index pattern

### Suricata

Suricata runs in IDS mode monitoring the `eth0` interface.

- Config: `suricata/etc/suricata.yaml`
- Custom rules: `suricata/etc/rules/local.rules`
- Logs (EVE JSON): `suricata/log/eve.json`
- **Update rules:**
  ```bash
  docker exec suricata suricata-update
  docker exec suricata suricatasc -c reload-rules
  ```

### ntopng (Port 3001)

1. Open `http://localhost:3001`
2. Login: `admin` / `admin` (change on first login)
3. Interface monitoring is pre-configured for `eth0`
4. Config: `ntopng/ntopng.conf`

### NetBox (Port 8080)

1. Open `http://localhost:8080`
2. Create admin: `docker exec -it netbox python manage.py createsuperuser`
3. Build your network topology: Organisation → Sites → Racks → Devices
4. Assign IPs: IPAM → IP Addresses

## Monitoring Test Cases

### Test 1: Host Down Alert
```bash
# Simulate a target going down
docker stop node_exporter
# Wait ~1 minute → expect Telegram message: "Host Down: node_exporter"
docker start node_exporter
# Alert resolves → expect "Resolved" notification
```

### Test 2: Traffic Spike Alert
```bash
# Generate traffic spike with iperf3 or large file transfer
iperf3 -c localhost -t 60 -b 200M
# Prometheus rule fires after 3 minutes above threshold
```

### Test 3: Suricata IDS Alert
```bash
# Trigger ICMP flood rule (from another host on the network):
ping -f -c 500 <NOC_HOST_IP>
# Check Kibana: noc-suricata-* index for alert event_type
```

### Test 4: Log Alert via ELK
```bash
# Generate SSH auth failures:
for i in $(seq 1 15); do ssh invalid_user@localhost; done
# Check Kibana discover for auth failure log entries
```

## Production Hardening

1. **Change all default passwords** in `.env`
2. **Generate a proper NetBox SECRET_KEY:**
   ```bash
   python3 -c "import secrets; print(secrets.token_urlsafe(50))"
   ```
3. **Enable Elasticsearch TLS** — set `xpack.security.http.ssl.enabled: 'true'` and provide certificates
4. **Add an Nginx reverse proxy** with TLS for all web UIs
5. **Restrict port binding** — bind ports to `127.0.0.1` or remove `ports:` and proxy through Nginx
6. **Set up log rotation** for `suricata/log/` using logrotate or Docker log options
7. **Backup volumes** — use `docker run --rm -v prometheus_data:/data busybox tar` pattern

## Troubleshooting

```bash
# View all container statuses
docker compose ps

# Follow logs for a specific service
docker compose logs -f elasticsearch
docker compose logs -f logstash
docker compose logs -f suricata

# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | python3 -m json.tool

# Reload Prometheus config without restart
curl -X POST http://localhost:9090/-/reload

# Check Elasticsearch health
curl -u elastic:<password> http://localhost:9200/_cluster/health?pretty

# List Elasticsearch indices
curl -u elastic:<password> http://localhost:9200/_cat/indices/noc-*?v

# Restart a specific service
docker compose restart logstash
```

## Optional: Predictive Alerting (AI/ML)

For predictive anomaly detection on metrics:

1. **Grafana ML** (Enterprise) — built-in anomaly detection
2. **Prophet + Python job** — schedule a Python container that:
   - Queries Prometheus API for metric history
   - Fits a Prophet/ARIMA model
   - Writes forecast + anomaly scores back to Prometheus Pushgateway
   - Alertmanager fires on forecast breach

Example scaffold: `scripts/ml_forecast.py` (placeholder — add your model logic)
