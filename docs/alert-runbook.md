# Alert Runbook — Ariba NOC Center

## HostDown

**Source:** Prometheus (`up == 0`)  
**Severity:** Critical  
**Channel:** Telegram + Email  

**Meaning:** A Prometheus scrape target has been unreachable for > 1 minute.

**Steps:**
1. Check container status: `docker compose ps`
2. Check container logs: `docker compose logs -f <service>`
3. Restart if crashed: `docker compose restart <service>`
4. If a physical/VM host: check SSH connectivity, ping, IPMI/iDRAC console
5. Check upstream network path (firewall, routing)

---

## HighCPUUsage / CriticalCPUUsage

**Source:** Prometheus node_exporter  
**Threshold:** Warning >85%, Critical >95%  

**Steps:**
1. SSH to the affected host
2. Run `top` or `htop` to identify top processes
3. Check for runaway processes: `ps aux --sort=-%cpu | head -20`
4. Check for known scheduled jobs (cron, backup, antivirus scan)
5. If legitimate spike: acknowledge in Alertmanager
6. If unexpected: escalate to sysadmin / incident response

---

## HighMemoryUsage / CriticalMemoryUsage

**Steps:**
1. `free -h` on the host
2. Identify top memory consumers: `ps aux --sort=-%mem | head -20`
3. Check for memory leaks in long-running services
4. If OOM kill occurred: `dmesg | grep -i "oom"`
5. Consider adding swap or scaling the host

---

## DiskSpaceLow / DiskSpaceCritical

**Steps:**
1. `df -h` on the host
2. Find large files/dirs: `du -sh /* 2>/dev/null | sort -rh | head -20`
3. Check log rotation: `ls -lh /var/log/`
4. Rotate/truncate logs: `logrotate -f /etc/logrotate.conf`
5. Clean Docker: `docker system prune -af --volumes` (non-prod only)
6. Expand disk or add mount point

---

## TrafficSpike

**Source:** Prometheus node_exporter  
**Meaning:** Inbound traffic is 5× the 1-hour baseline.  

**Steps:**
1. Check ntopng dashboard (`http://localhost:3001`) for top talkers
2. Check Suricata alerts in Kibana for related IDS events
3. Check if spike is from a known source (backup, update, CDN)
4. If external attack suspected: check `src_ip` in Kibana, consider blocking at firewall
5. Capture traffic for analysis: `docker exec suricata tcpdump -i eth0 -w /var/log/suricata/capture.pcap`

---

## NetworkInterfaceDown

**Steps:**
1. `ip link show` on host
2. Check physical cable / SFP
3. Check switch port status via LibreNMS or Zabbix
4. `ip link set <iface> up` if accidentally down
5. Check NIC driver: `dmesg | grep -i eth`

---

## Suricata IDS Alerts (Kibana)

**Check in Kibana → Discover → noc-suricata-* index:**

| `suricata.event_type` | Meaning |
|----------------------|---------|
| `alert` | IDS signature matched |
| `anomaly` | Protocol anomaly |
| `dns` | DNS query/response |
| `http` | HTTP transaction |
| `tls` | TLS handshake |

**Common signatures and responses:**

| Signature contains | Action |
|-------------------|--------|
| `Port Scan` | Check source IP, block if not authorized scanner |
| `SSH Brute Force` | Block IP in firewall, check auth logs |
| `C2 Communication` | **CRITICAL** — isolate host, escalate to IR |
| `ICMP Flood` | Block source IP, notify upstream ISP if external |
| `DNS Exfiltration` | Block domain, investigate host for malware |

---

## ELK Issues

### Elasticsearch yellow/red cluster health
```bash
curl -u elastic:<password> http://localhost:9200/_cluster/health?pretty
```
- Yellow = replica shards unassigned (normal for single-node)
- Red = primary shards missing → check disk space, heap

### Logstash not parsing logs
```bash
docker compose logs -f logstash | grep -i error
```
- Check `elk/logstash/pipeline/logstash.conf` syntax
- Test pipeline: add `stdout { codec => rubydebug }` temporarily

### Filebeat not shipping logs
```bash
docker compose logs -f filebeat | grep -E "error|warn"
```
- Check file paths in `elk/filebeat/filebeat.yml`
- Ensure `suricata/log/eve.json` exists and is being written

---

## Escalation Matrix

| Severity | Response Time | Escalate To |
|----------|--------------|-------------|
| Warning | 30 minutes | On-call NOC |
| Critical | 5 minutes | On-call NOC + Manager |
| Major outage | Immediate | Full incident response team |
