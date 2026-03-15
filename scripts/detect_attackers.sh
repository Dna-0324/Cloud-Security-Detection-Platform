#!/bin/bash
# detect_attackers.sh - Détecte les IPs suspectes depuis detected_ips.txt

DETECTED_IPS="/var/log/cloud-scripts/detected_ips.txt"
ATTACKERS_FILE="/var/log/cloud-scripts/attackers.txt"
LOG_FILE="/var/log/cloud-scripts/detect_attackers.log"
LOG_GROUP="/aws/cloudtrail/cloud-sec-trail"
REGION="us-west-1"
THRESHOLD=1

echo "=============================="
echo " DÉTECTION ATTAQUANTS - $(date)"
echo "=============================="

echo "[$(date)] Début détection attaquants" >> "$LOG_FILE"
> "$ATTACKERS_FILE"

if [ ! -f "$DETECTED_IPS" ] || [ ! -s "$DETECTED_IPS" ]; then
  echo "[WARN] Aucune IP dans $DETECTED_IPS — lance d'abord test_flowlogs.sh"
  exit 1
fi

# Compter les occurrences de chaque IP dans les Flow Logs bruts
echo "[*] Analyse des IPs suspectes..."

while IFS= read -r IP; do
  COUNT=$(grep -c "$IP" /tmp/flow_raw.txt 2>/dev/null || echo 0)
  if [ "$COUNT" -ge "$THRESHOLD" ]; then
    echo "$IP REJECT_COUNT=$COUNT" >> "$ATTACKERS_FILE"
  fi
done < "$DETECTED_IPS"

ATTACKER_COUNT=$(wc -l < "$ATTACKERS_FILE")
echo "[OK] $ATTACKER_COUNT IP(s) suspecte(s) détectée(s)"
echo "[$(date)] $ATTACKER_COUNT attaquants détectés" >> "$LOG_FILE"

if [ "$ATTACKER_COUNT" -gt 0 ]; then
  echo ""
  echo "[!] IPs suspectes :"
  cat "$ATTACKERS_FILE"
else
  echo "[OK] Aucune IP suspecte détectée"
fi

echo "[DONE] Détection attaquants terminée"
