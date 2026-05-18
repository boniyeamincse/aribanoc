# Ariba NOC Center - Implementation TODO

## Plan
1. Create base repository structure under `/home/boni/Desktop/SOC_Akij/noc`.
2. Add root `docker-compose.yml` orchestrating all services with persistent volumes and healthchecks.
3. Create container directories and minimal runnable configs:
   - Zabbix (server + agent)
   - Prometheus + node-exporter
   - Grafana (dashboards provisioning)
   - ntopng
   - Suricata
   - ELK (Elasticsearch + Logstash + Kibana)
   - LibreNMS
   - NetBox
   - Cabot (email/Telegram alerting) (or placeholders if external integration required)
   - Optional: TheHive + Cortex (placeholders)
   - Optional: Fail2ban/Wazuh (placeholders)
4. Add centralized logging wiring (Logstash inputs/filters, filebeat optional).
5. Add sample dashboards/alerts (Grafana provisioning + example JSON).
6. Add web dashboard authentication/roles (if using Grafana/LibreNMS auth, otherwise placeholder for custom UI).
7. Add self-healing scripts for restart and monitoring.
8. Add docs: setup guide, architecture diagram, deployment instructions.
9. Add environment variable template `.env.example`.

## Progress
- [x] Step 1: Create base repository structure
- [x] Step 2: Add root docker-compose.yml
- [x] Step 3: Create service directory configs (Zabbix/Prometheus/Grafana/ntopng/Suricata/ELK/LibreNMS/NetBox)
- [x] Step 4: Centralized logging wiring (Logstash full pipeline, Filebeat for Suricata+system logs)
- [x] Step 5: Sample dashboards & alerts (NOC Overview, Suricata IDS dashboards; Prometheus alert rules; Grafana alerting provisioning)
- [x] Step 6: Auth & roles (Grafana admin auth, Elasticsearch xpack.security, all passwords via .env)
- [x] Step 7: Self-healing scripts (watchdog.sh with Telegram notifications on container down/restart)
- [x] Step 8: Docs + architecture diagram (docs/architecture.md, docs/setup.md, docs/alert-runbook.md)
- [x] Step 9: .env.example (updated with all alert credential vars)

