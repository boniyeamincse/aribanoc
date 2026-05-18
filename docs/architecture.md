# Ariba NOC Center — Architecture

## Overview

Ariba NOC Center is a fully containerised Network Operations Center platform built with Docker Compose. It provides end-to-end network monitoring, intrusion detection, log aggregation, alerting, and infrastructure inventory.

## Architecture Diagram

```
                         ┌─────────────────────────────────────────────┐
                         │              Ariba NOC Center                │
                         │                                              │
  ┌──────────────┐       │  ┌──────────────┐   ┌───────────────────┐  │
  │ Network Devs │──SNMP─┼─▶│  LibreNMS    │   │   Zabbix Server   │  │
  │ (routers,    │       │  │  (discovery, │   │   + Agent + Web   │  │
  │  switches)   │──SNMP─┼─▶│   SNMP mon) │   │   (active checks, │  │
  └──────────────┘       │  └──────┬───────┘   │    traps, IPMI)   │  │
                         │         │           └────────┬──────────┘  │
  ┌──────────────┐       │         │                    │              │
  │ Linux Hosts  │──── node_exporter ──────────────────▼──────────┐  │
  │ (servers)    │       │  ┌──────────────────────────────────┐  │  │
  └──────────────┘       │  │       Prometheus                 │  │  │
                         │  │  scrapes: node_exporter,         │  │  │
  ┌──────────────┐       │  │  alertmanager, prometheus self   │  │  │
  │  Network     │       │  └──────────┬───────────────────────┘  │  │
  │  Traffic     │──pcap─┼─▶ Suricata  │                           │  │
  │              │       │  │ (IDS)     │  ┌─────────────────────┐ │  │
  └──────────────┘       │  │ eve.json  │  │   Alertmanager      │ │  │
                         │  └────┬──────┘  │  routes → Telegram  │ │  │
                         │       │         │          → Email     │ │  │
                         │  ┌────▼──────┐  └──────────────────────┘ │  │
                         │  │ Filebeat  │◀──── alert rules /         │  │
                         │  │ (log ship)│      prometheus/alerts/    │  │
                         │  └────┬──────┘                            │  │
                         │       │                                   │  │
                         │  ┌────▼──────────────────────────────┐   │  │
                         │  │             ELK Stack              │   │  │
                         │  │  Logstash (parse/enrich)          │   │  │
                         │  │  Elasticsearch (store/index)       │   │  │
                         │  │  Kibana (explore/visualize)        │   │  │
                         │  └────────────────────────────────────┘   │  │
                         │                                            │  │
                         │  ┌──────────────┐  ┌──────────────────┐   │  │
                         │  │   ntopng     │  │    Grafana       │◀──┘  │
                         │  │ (flow/traffic│  │  dashboards:     │      │
                         │  │  analysis)   │  │  NOC Overview,   │      │
                         │  └──────────────┘  │  Suricata IDS,   │      │
                         │                    │  Node Exporter   │      │
                         │  ┌──────────────┐  └──────────────────┘      │
                         │  │   NetBox     │                            │
                         │  │ (IPAM/DCIM)  │                            │
                         │  └──────────────┘                            │
                         │                                              │
                         │  ┌────────────────────────────────────────┐ │
                         │  │  Shared Infrastructure                  │ │
                         │  │  Redis (cache/queue), MariaDB (Zabbix,  │ │
                         │  │  LibreNMS), PostgreSQL (NetBox)         │ │
                         │  │  Watchdog (self-healing)                │ │
                         │  └────────────────────────────────────────┘ │
                         └─────────────────────────────────────────────┘
```

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| **prometheus** | prom/prometheus:v2.54.1 | 9090 | Metrics collection & alerting rules |
| **alertmanager** | prom/alertmanager:v0.27.0 | 9093 | Route alerts → Telegram / Email |
| **node_exporter** | prom/node-exporter:v1.8.2 | 9100 | Host metrics (CPU, RAM, Disk, Net) |
| **grafana** | grafana/grafana:11.2.0 | 3000 | Dashboards & Grafana alerting |
| **zabbix-server** | zabbix/zabbix-server-mysql:alpine-7.0 | 10051 | Active/passive checks, SNMP traps |
| **zabbix-web** | zabbix/zabbix-web-nginx-mysql:alpine-7.0 | 8090 | Zabbix web UI |
| **zabbix-agent** | zabbix/zabbix-agent:alpine-7.0 | 10050 | Local agent on NOC host |
| **zabbix-db** | mariadb:11.4 | — | Zabbix database |
| **elasticsearch** | elasticsearch:8.16.1 | 9200 | Log storage & full-text search |
| **logstash** | logstash:8.16.1 | 5044, 9600 | Log parsing/enrichment pipeline |
| **kibana** | kibana:8.16.1 | 5601 | Log exploration & visualisation |
| **filebeat** | filebeat:8.16.1 | — | Ship Suricata/system logs → Logstash |
| **suricata** | oisf/suricata:7.0.6 | — | Network IDS (EVE JSON output) |
| **ntopng** | ntop/ntopng:stable | 3001 | Traffic flow analysis (NetFlow/PCAP) |
| **librenms** | librenms/librenms:latest | 8000 | SNMP auto-discovery & polling |
| **librenms-db** | mariadb:11.4 | — | LibreNMS database |
| **netbox** | netboxcommunity/netbox:v3.7.1 | 8080 | IP address & device inventory |
| **netbox-db** | postgres:16 | — | NetBox database |
| **redis** | redis:7-alpine | 6379 | Shared cache (ntopng, NetBox, LibreNMS) |
| **watchdog** | alpine:3.20 | — | Self-healing: auto-restart failed containers |

## Data Flows

### Metrics Flow
```
Linux Host → node_exporter:9100 → Prometheus scrape → Alert rules
                                                    → Grafana query
                                                    → Alertmanager → Telegram/Email
```

### Log Flow
```
Suricata → eve.json → Filebeat → Logstash:5044 → Elasticsearch → Kibana
System logs  ──────────────────────────────────────────────────┘
Syslog UDP:5140 ──→ Logstash direct → Elasticsearch
```

### Network Discovery
```
Network Devices (SNMP) → LibreNMS polling → alerts/graphs
                       → Zabbix SNMP template → triggers → alertscripts → Telegram
```

## Alerting Channels

### Prometheus Alertmanager
- Rules in `prometheus/alerts/node.yml` and `prometheus/alerts/network.yml`
- Routes to Telegram (all alerts) and Email (critical only)
- Config: `alertmanager/alertmanager.yml`

### Grafana Alerting
- Contact points provisioned in `grafana/provisioning/alerting/alerts.yml`
- Telegram + Email
- Can alert on any Prometheus or Elasticsearch query

### Zabbix Media Scripts
- `zabbix/alertscripts/telegram.sh` — Telegram via Bot API
- `zabbix/alertscripts/email.sh` — Email via SMTP/curl
- Configure in Zabbix UI: Administration → Media Types → Script

## Volumes (Persistent Data)

| Volume | Contents |
|--------|----------|
| `prometheus_data` | Prometheus TSDB (metrics history) |
| `grafana_data` | Grafana state, plugins |
| `zabbix_db` | Zabbix MariaDB data |
| `es_data` | Elasticsearch indices |
| `librenms_data` | LibreNMS config |
| `librenms_db` | LibreNMS MariaDB data |
| `netbox_db` | NetBox PostgreSQL data |
| `netbox_data` | NetBox media uploads |
| `ntopng_data` | ntopng flow data |
| `redis_data` | Redis AOF/RDB |
| `alertmanager_data` | Alertmanager silence/inhibition state |
| `./suricata/log` | Suricata EVE JSON (bind mount) |
| `./librenms/rrd` | LibreNMS RRD files (bind mount) |

## Network

All services communicate on the `noc` bridge network. No service is exposed to the internet by default — ports are bound to `127.0.0.1` or the Docker host only. For production, place an Nginx or Traefik reverse proxy in front with TLS.
