#!/bin/bash
LOG_GROUP="/aws/cloudtrail/cloud-sec-trail"
REGION="us-west-1"
LOG_FILE="/var/log/cloud-scripts/test_flowlogs.log"
DETECTED_IPS="/var/log/cloud-scripts/detected_ips.txt"

echo "=============================="
echo " TEST VPC FLOW LOGS - $(date)"
echo "=============================="

echo "[$(date)] Début test Flow Logs" >> "$LOG_FILE"

STREAMS=$(aws logs describe-log-streams \
  --log-group-name "$LOG_GROUP" \
  --region "$REGION" \
  --order-by LastEventTime \
  --descending \
  --max-items 5 \
  --query 'logStreams[*].logStreamName' \
  --output text 2>/dev/null)

if [ -z "$STREAMS" ]; then
  echo "[WARN] Aucun log stream trouvé"
  exit 1
fi

echo "[OK] Log streams trouvés"
> /tmp/flow_raw.txt

for STREAM in $STREAMS; do
  echo "[*] Lecture du stream : $STREAM"
  aws logs get-log-events \
    --log-group-name "$LOG_GROUP" \
    --log-stream-name "$STREAM" \
    --region "$REGION" \
    --limit 500 \
    --query 'events[*].message' \
    --output text 2>/dev/null | tr '\t' '\n' >> /tmp/flow_raw.txt
done

grep "REJECT" /tmp/flow_raw.txt | \
  awk '{print $4}' | \
  grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | \
  grep -v '^10\.' | \
  grep -v '^172\.' | \
  grep -v '^192\.168\.' | \
  sort | uniq > "$DETECTED_IPS"

IP_COUNT=$(wc -l < "$DETECTED_IPS")
echo "[OK] $IP_COUNT IPs externes extraites → $DETECTED_IPS"
echo "[$(date)] $IP_COUNT IPs extraites" >> "$LOG_FILE"

echo ""
echo "[*] Aperçu des IPs détectées :"
cat "$DETECTED_IPS"
echo "[DONE] Test Flow Logs terminé"
