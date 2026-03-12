#!/bin/bash
# detect_port_scan.sh - Identifie les tentatives de port scanning depuis les Flow Logs

LOG_GROUP="/aws/cloudtrail/cloud-sec-trail"
REGION="us-west-1"
LOG_FILE="/var/log/cloud-scripts/detect_port_scan.log"
PORT_SCAN_FILE="/var/log/cloud-scripts/port_scanners.txt"
PORT_THRESHOLD=15  # Nombre de ports distincts pour qualifier un port scan
TIME_WINDOW=300    # Fenêtre de temps en secondes (5 minutes)

echo "=============================="
echo " DÉTECTION PORT SCAN - $(date)"
echo "=============================="

echo "[$(date)] Début détection port scan" >> "$LOG_FILE"

> "$PORT_SCAN_FILE"

# Récupérer les Flow Logs des dernières 24h
START_TIME=$(date -d "24 hours ago" +%s%3N 2>/dev/null || date -v-24H +%s000)

STREAMS=$(aws logs describe-log-streams \
  --log-group-name "$LOG_GROUP" \
  --region "$REGION" \
  --order-by LastEventTime \
  --descending \
  --max-items 10 \
  --query 'logStreams[*].logStreamName' \
  --output text 2>/dev/null)

FLOW_TMP="/tmp/flow_portscan.txt"
> "$FLOW_TMP"

echo "[*] Récupération des Flow Logs..."
for STREAM in $STREAMS; do
  aws logs get-log-events \
    --log-group-name "$LOG_GROUP" \
    --log-stream-name "$STREAM" \
    --region "$REGION" \
    --start-time "$START_TIME" \
    --query 'events[*].message' \
    --output text 2>/dev/null >> "$FLOW_TMP"
done

if [ ! -s "$FLOW_TMP" ]; then
  echo "[WARN] Aucun Flow Log récupéré"
  exit 1
fi

echo "[*] Analyse des patterns de port scanning..."

# Analyser avec Python pour détecter les scans multi-ports par IP source
python3 << 'PYEOF'
import sys
from collections import defaultdict

flow_file = "/tmp/flow_portscan.txt"
port_scan_file = "/var/log/cloud-scripts/port_scanners.txt"
PORT_THRESHOLD = 15

ip_ports = defaultdict(set)
ip_rejected = defaultdict(int)

try:
    with open(flow_file, 'r') as f:
        for line in f:
            parts = line.strip().split()
            # Format Flow Log: version account-id interface-id srcaddr dstaddr srcport dstport protocol packets bytes start end action log-status
            if len(parts) >= 13:
                src_ip = parts[3]
                dst_port = parts[6]
                action = parts[12] if len(parts) > 12 else ""

                # Ignorer IPs privées
                if src_ip.startswith(('10.', '172.', '192.168.', '-')):
                    continue

                if dst_port.isdigit():
                    ip_ports[src_ip].add(dst_port)
                if action == "REJECT":
                    ip_rejected[src_ip] += 1

    scanners = []
    for ip, ports in ip_ports.items():
        if len(ports) >= PORT_THRESHOLD:
            scanners.append((ip, len(ports), ip_rejected.get(ip, 0)))

    scanners.sort(key=lambda x: x[1], reverse=True)

    with open(port_scan_file, 'w') as f:
        for ip, port_count, rejected in scanners:
            line = f"{ip} PORTS_SCANNED={port_count} REJECTED={rejected}\n"
            f.write(line)
            print(f"  [!] {line.strip()}")

    print(f"\n[OK] {len(scanners)} scanner(s) détecté(s)")

except FileNotFoundError:
    print("[ERREUR] Fichier Flow Log introuvable")
    sys.exit(1)
PYEOF

SCANNER_COUNT=$(wc -l < "$PORT_SCAN_FILE" 2>/dev/null || echo 0)
echo "[$(date)] $SCANNER_COUNT scanner(s) port détectés" >> "$LOG_FILE"

if [ "$SCANNER_COUNT" -eq 0 ]; then
  echo "[OK] Aucun port scan détecté"
fi

echo "[DONE] Détection port scan terminée"
