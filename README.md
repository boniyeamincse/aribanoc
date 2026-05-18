# Ariba NOC Center

Ariba NOC Center is a Docker-based Network Operations Center stack for infrastructure monitoring, traffic visibility, centralized logging, alerting, and asset inventory.

It combines Prometheus, Grafana, Zabbix, ELK, Suricata, ntopng, LibreNMS, and NetBox into a single deployment so you can monitor hosts and devices, collect and search security logs, and route alerts to Telegram or email.

## Stack Overview

- Prometheus + Alertmanager for metrics, alert rules, and notifications
- Grafana for dashboards and alert visualization
- Zabbix for agent-based and SNMP monitoring
- LibreNMS for SNMP auto-discovery and device polling
- Suricata + Filebeat + ELK for IDS and log analytics
- ntopng for traffic and flow visibility
- NetBox for IPAM and infrastructure inventory
- Watchdog for container self-healing

## Services

| Service | Port | Purpose |
|---|---:|---|
| Grafana | 3000 | Dashboards and alerting UI |
| ntopng | 3001 | Traffic and flow monitoring |
| Kibana | 5601 | Log search and visualization |
| LibreNMS | 8000 | Device discovery and SNMP monitoring |
| NetBox | 8080 | IPAM/DCIM and inventory |
| Zabbix Web | 8090 | Zabbix monitoring UI |
| Prometheus | 9090 | Metrics and alert rules |
| Alertmanager | 9093 | Alert routing |
| Node Exporter | 9100 | Host metrics |
| Zabbix Agent | 10050 | Local Zabbix agent |
| Zabbix Server | 10051 | Zabbix backend |
| Elasticsearch | 9200 | Log storage |
| Logstash | 5044 / 9600 | Log pipeline |

## Repository Layout

| Path | Purpose |
|---|---|
| `docker-compose.yml` | Main orchestration file |
| `prometheus/` | Prometheus config and alert rules |
| `grafana/` | Provisioned datasources, alerts, dashboards |
| `elk/` | Filebeat and Logstash pipeline configuration |
| `suricata/` | IDS configuration and local rules |
| `zabbix/` | Alert scripts and Zabbix-related assets |
| `librenms/` | LibreNMS persistent data mounts |
| `netbox/` | NetBox configuration |
| `ntopng/` | ntopng configuration |
| `scripts/` | Setup and watchdog automation |
| `docs/` | Architecture, setup guide, and runbook |

## Quick Start

```bash
# One-command installer (installs Docker/Compose/tools + stack)
bash install.sh

# Or manual setup if dependencies already exist
cp .env.example .env
nano .env
bash scripts/setup.sh
```

If you prefer to start manually:

```bash
sudo sysctl -w vm.max_map_count=262144
chmod +x zabbix/alertscripts/*.sh scripts/*.sh
docker compose up -d
```

## Default URLs

- Grafana: http://localhost:3000
- ntopng: http://localhost:3001
- Kibana: http://localhost:5601
- LibreNMS: http://localhost:8000
- NetBox: http://localhost:8080
- Zabbix: http://localhost:8090
- Prometheus: http://localhost:9090
- Alertmanager: http://localhost:9093

## Documentation

- [Documentation Index](docs/README.md)
- [Technical Documentation](docs/documentation/index.html)
- [Setup Guide](docs/setup.md)
- [Architecture](docs/architecture.md)
- [Alert Runbook](docs/alert-runbook.md)
- [Contributing Guide](CONTRIBUTING.md)

## Alerting

The stack is prewired for these alert paths:

- Prometheus rules in `prometheus/alerts/`
- Alertmanager routing in `alertmanager/alertmanager.yml`
- Grafana contact points in `grafana/provisioning/alerting/alerts.yml`
- Zabbix media scripts in `zabbix/alertscripts/`

Configure the Telegram and SMTP variables in `.env` before deployment.

## Validation and Operations

Useful commands:

```bash
docker compose config --quiet
docker compose ps
docker compose logs -f prometheus
docker compose logs -f logstash
curl -X POST http://localhost:9090/-/reload
```

## Container Management CLI

Use the project CLI for troubleshooting and Docker container management:

```bash
./scripts/nocctl.sh help
./scripts/nocctl.sh status
./scripts/nocctl.sh health
./scripts/nocctl.sh doctor
./scripts/nocctl.sh logs logstash 300
./scripts/nocctl.sh restart prometheus
```

## Production Notes

- Change all default credentials in `.env`
- Put a reverse proxy with TLS in front of web UIs
- Restrict exposed ports where possible
- Back up Docker volumes regularly
- Tune retention and storage for Prometheus and Elasticsearch

## License

Internal project repository. Add an explicit license if this will be distributed externally.