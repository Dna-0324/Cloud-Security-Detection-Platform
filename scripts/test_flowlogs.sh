#!/bin/bash
# test_flowlogs.sh - Lit et analyse les VPC Flow Logs depuis CloudWatch

LOG_GROUP="/aws/cloudtrail/cloud-sec-trail"
REGION="us-west-1"
LOG_FILE="/var/log/cloud-scripts/test_flowlogs.log"
DETECTED_IPS="/var/log/cloud-scripts/detected_ips.txt"
HOURS_BACK=1

echo "=============================="
echo " TEST VPC FLOW LOGS - $(date)"
echo "=============================="

echo "[$(date)] Début test Flow Logs" >> "$LOG_FILE"

# Calculer la plage de temps (dernière heure en ms)
START_TIME=$(date -d "$HOURS_BACK hours ago" +%s%3N 2>/dev/null || date -v-${HOURS_BACK}H +%s000)
END_TIME=$(date +%s%3N)

echo "[*] Récupération des Flow Logs (dernière $HOURS_BACK heure)..."

# Lister les log streams disponibles
STREAMS=$(aws logs describe-log-streams \
  --log-group-name "$LOG_GROUP" \
  --region "$REGION" \
  --order-by LastEventTime \
  --descending \
  --max-items 5 \
  --query 'logStreams[*].logStreamName' \
  --output text 2>/dev/null)

if [ -z "$STREAMS" ]; then
  echo "[WARN] Aucun log stream trouvé dans $LOG_GROUP"
  echo "[$(date)] WARN: Aucun stream trouvé" >> "$LOG_FILE"
  exit 1
fi

echo "[OK] Log streams trouvés"

# Récupérer les événements récents
for STREAM in $STREAMS; do
  echo "[*] Lecture du stream : $STREAM"
  aws logs get-log-events \
    --log-group-name "$LOG_GROUP" \
    --log-stream-name "$STREAM" \
    --region "$REGION" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --query 'events[*].message' \
    --output text 2>/dev/null >> "$LOG_FILE"
done

echo "[*] Extraction des IPs depuis les Flow Logs..."
grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$LOG_FILE" | \
  grep -v '^10\.' | \
  grep -v '^172\.' | \
  grep -v '^192\.168\.' | \
  sort | uniq > "$DETECTED_IPS"

IP_COUNT=$(wc -l < "$DETECTED_IPS")
echo "[OK] $IP_COUNT IPs externes extraites → $DETECTED_IPS"
echo "[$(date)] $IP_COUNT IPs extraites des Flow Logs" >> "$LOG_FILE"

echo ""
echo "[*] Aperçu des IPs détectées :"
head -20 "$DETECTED_IPS"

echo "[DONE] Test Flow Logs terminé"
