#!/bin/bash
# auto_block.sh - Bloque automatiquement les IPs critiques via AWS Security Group

SECURITY_GROUP_ID="sg-030cbceb399c6bfda"
REGION="us-west-1"
ATTACKERS_FILE="/var/log/cloud-scripts/attackers.txt"
BLOCKED_FILE="/var/log/cloud-scripts/blocked_ips.txt"
REPORT_JSON="/var/log/cloud-scripts/threat_report.json"
LOG_FILE="/var/log/cloud-scripts/auto_block.log"
SNS_TOPIC_ARN="arn:aws:sns:us-west-1:798329741052:cloud-sec-alerts"
BLOCK_THRESHOLD=50

echo "=============================="
echo " AUTO-REMEDIATION SOAR - $(date)"
echo "=============================="

echo "[$(date)] Début auto-remediation" >> "$LOG_FILE"
touch "$BLOCKED_FILE"

if [ ! -f "$ATTACKERS_FILE" ] || [ ! -s "$ATTACKERS_FILE" ]; then
  echo "[WARN] Aucun attaquant détecté"
  exit 1
fi

BLOCKED_COUNT=0
ALREADY_BLOCKED=0
SKIPPED=0
BLOCKED_LIST=""

while IFS= read -r LINE; do
  IP=$(echo "$LINE" | awk '{print $1}')
  [ -z "$IP" ] && continue

  if grep -q "^$IP " "$BLOCKED_FILE" 2>/dev/null; then
    echo "[~] $IP déjà bloquée"
    ALREADY_BLOCKED=$((ALREADY_BLOCKED + 1))
    continue
  fi

  INFO=$(python3 /cloudlab/soar/get_threat_info.py "$IP" "$REPORT_JSON")
  ABUSE_SCORE=$(echo "$INFO" | cut -d'|' -f1)
  THREAT_LEVEL=$(echo "$INFO" | cut -d'|' -f2)

  echo "[*] $IP → AbuseScore=${ABUSE_SCORE}% | Niveau=$THREAT_LEVEL"

  if [ "$THREAT_LEVEL" = "CRITIQUE" ] || [ "$ABUSE_SCORE" -ge "$BLOCK_THRESHOLD" ] 2>/dev/null; then
    echo "[!] Blocage de $IP..."

    EXISTING=$(aws ec2 describe-security-groups \
      --group-ids "$SECURITY_GROUP_ID" \
      --region "$REGION" \
      --query "SecurityGroups[0].IpPermissions[?IpRanges[?CidrIp=='${IP}/32']]" \
      --output text 2>/dev/null)

    if [ -n "$EXISTING" ]; then
      echo "[~] Règle déjà présente dans le Security Group"
      ALREADY_BLOCKED=$((ALREADY_BLOCKED + 1))
      continue
    fi

    aws ec2 authorize-security-group-ingress \
      --group-id "$SECURITY_GROUP_ID" \
      --region "$REGION" \
      --ip-permissions "[{\"IpProtocol\":\"-1\",\"IpRanges\":[{\"CidrIp\":\"${IP}/32\",\"Description\":\"SOAR-AUTO-BLOCK-$(date +%Y%m%d)\"}]}]" \
      > /dev/null 2>&1

    if [ $? -eq 0 ]; then
      echo "[OK] $IP bloquée avec succès"
      echo "$IP BLOCKED=$(date) SCORE=$ABUSE_SCORE LEVEL=$THREAT_LEVEL" >> "$BLOCKED_FILE"
      BLOCKED_COUNT=$((BLOCKED_COUNT + 1))
      BLOCKED_LIST="$BLOCKED_LIST\n  - $IP (Score: ${ABUSE_SCORE}% | Niveau: $THREAT_LEVEL)"
      echo "[$(date)] BLOQUEE: $IP score=$ABUSE_SCORE" >> "$LOG_FILE"
    else
      echo "[ERREUR] Échec du blocage de $IP"
      echo "[$(date)] ERREUR blocage: $IP" >> "$LOG_FILE"
    fi
  else
    echo "[~] $IP score insuffisant (${ABUSE_SCORE}%) — non bloquée"
    SKIPPED=$((SKIPPED + 1))
  fi

done < "$ATTACKERS_FILE"

echo ""
echo "=============================="
echo " RÉSUMÉ AUTO-REMEDIATION"
echo "=============================="
echo "Bloquées      : $BLOCKED_COUNT"
echo "Déjà bloquées : $ALREADY_BLOCKED"
echo "Ignorées      : $SKIPPED"
echo "[$(date)] Fin SOAR: $BLOCKED_COUNT bloquées" >> "$LOG_FILE"

if [ "$BLOCKED_COUNT" -gt 0 ]; then
  aws sns publish \
    --topic-arn "$SNS_TOPIC_ARN" \
    --subject "SOAR - $BLOCKED_COUNT IP(s) bloquee(s) automatiquement" \
    --message "Rapport Auto-Remediation SOAR
Date    : $(date)
Region  : $REGION
SG      : $SECURITY_GROUP_ID

IPs bloquees :
$BLOCKED_LIST

Bloquees      : $BLOCKED_COUNT
Deja bloquees : $ALREADY_BLOCKED
Ignorees      : $SKIPPED" \
    --region "$REGION" > /dev/null 2>&1
  echo "[OK] Email récapitulatif envoyé"
fi

echo "[DONE] Auto-remediation terminée"
