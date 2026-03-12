#!/bin/bash
# detect_attackers.sh - Détecte les IP suspectes depuis les Flow Logs et CloudTrail

DETECTED_IPS="/var/log/cloud-scripts/detected_ips.txt"
ATTACKERS_FILE="/var/log/cloud-scripts/attackers.txt"
LOG_FILE="/var/log/cloud-scripts/detect_attackers.log"
LOG_GROUP="/aws/cloudtrail/cloud-sec-trail"
REGION="us-west-1"
THRESHOLD=10  # Nombre de connexions refusées pour considérer une IP suspecte

echo "=============================="
echo " DÉTECTION ATTAQUANTS - $(date)"
echo "=============================="

echo "[$(date)] Début détection attaquants" >> "$LOG_FILE"

> "$ATTACKERS_FILE"

# --- Analyse des Flow Logs : IPs avec connexions REJECT ---
echo "[*] Analyse des connexions REJECT dans les Flow Logs..."

START_TIME=$(date -d "24 hours ago" +%s%3N 2>/dev/null || date -v-24H +%s000)
END_TIME=$(date +%s%3N)

STREAMS=$(aws logs describe-log-streams \
  --log-group-name "$LOG_GROUP" \
  --region "$REGION" \
  --order-by LastEventTime \
  --descending \
  --max-items 10 \
  --query 'logStreams[*].logStreamName' \
  --output text 2>/dev/null)

FLOW_TMP="/tmp/flow_raw.txt"
> "$FLOW_TMP"

for STREAM in $STREAMS; do
  aws logs get-log-events \
    --log-group-name "$LOG_GROUP" \
    --log-stream-name "$STREAM" \
    --region "$REGION" \
    --start-time "$START_TIME" \
    --query 'events[*].message' \
    --output text 2>/dev/null >> "$FLOW_TMP"
done

# Extraire les IPs sources avec statut REJECT
echo "[*] Extraction des IPs avec connexions REJECT..."
grep "REJECT" "$FLOW_TMP" | \
  awk '{print $4}' | \
  grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | \
  grep -v '^10\.' | \
  grep -v '^172\.' | \
  grep -v '^192\.168\.' | \
  sort | uniq -c | sort -rn | \
  awk -v threshold="$THRESHOLD" '$1 >= threshold {print $2, "REJECT_COUNT="$1}' >> "$ATTACKERS_FILE"

# --- Analyse CloudTrail : tentatives d'accès non autorisées ---
echo "[*] Analyse des erreurs d'autorisation dans CloudTrail..."
grep -i "UnauthorizedOperation\|AccessDenied\|InvalidClientTokenId" "$FLOW_TMP" | \
  grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | \
  grep -v '^10\.' | \
  sort | uniq -c | sort -rn | \
  awk '$1 >= 3 {print $2, "AUTH_FAIL="$1}' >> "$ATTACKERS_FILE"

# --- Analyse Apache logs ---
APACHE_LOG="/var/log/httpd/access_log"
if [ -f "$APACHE_LOG" ]; then
  echo "[*] Analyse des logs Apache (codes 4xx/5xx)..."
  grep -E '" (4[0-9]{2}|5[0-9]{2}) ' "$APACHE_LOG" | \
    awk '{print $1}' | \
    sort | uniq -c | sort -rn | \
    awk -v threshold="$THRESHOLD" '$1 >= threshold {print $2, "HTTP_ERROR="$1}' >> "$ATTACKERS_FILE"
fi

# Dédupliquer et trier le fichier final
sort -u "$ATTACKERS_FILE" -o "$ATTACKERS_FILE"

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
