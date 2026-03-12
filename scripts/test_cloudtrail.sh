#!/bin/bash
# test_cloudtrail.sh - Vérifie la lecture des logs CloudTrail depuis S3

BUCKET="cloudtrail-logs-798329741052"
REGION="us-west-1"
LOG_FILE="/var/log/cloud-scripts/test_cloudtrail.log"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
DATE=$(date +%Y/%m/%d)

echo "=============================="
echo " TEST CLOUDTRAIL - $(date)"
echo "=============================="

echo "[$(date)] Début test CloudTrail" >> "$LOG_FILE"

# Vérifier que le bucket existe
echo "[*] Vérification du bucket S3 : $BUCKET"
aws s3 ls "s3://$BUCKET" --region "$REGION" > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "[ERREUR] Bucket S3 inaccessible : $BUCKET"
  echo "[$(date)] ERREUR: Bucket S3 inaccessible" >> "$LOG_FILE"
  exit 1
fi
echo "[OK] Bucket S3 accessible"

# Lister les derniers logs CloudTrail
echo "[*] Listing des derniers logs CloudTrail..."
PREFIX="AWSLogs/$ACCOUNT_ID/CloudTrail/$REGION/$DATE/"
aws s3 ls "s3://$BUCKET/$PREFIX" --region "$REGION" 2>/dev/null

if [ $? -ne 0 ]; then
  echo "[WARN] Aucun log trouvé pour aujourd'hui ($DATE)"
  echo "[$(date)] WARN: Aucun log CloudTrail pour $DATE" >> "$LOG_FILE"
else
  echo "[OK] Logs CloudTrail trouvés pour $DATE"

  # Télécharger et lire le dernier fichier de log
  LATEST=$(aws s3 ls "s3://$BUCKET/$PREFIX" --region "$REGION" | sort | tail -1 | awk '{print $4}')
  if [ -n "$LATEST" ]; then
    echo "[*] Lecture du dernier log : $LATEST"
    aws s3 cp "s3://$BUCKET/$PREFIX$LATEST" /tmp/cloudtrail_latest.json.gz --region "$REGION" > /dev/null 2>&1
    gunzip -f /tmp/cloudtrail_latest.json.gz
    echo "[*] Aperçu des 5 premiers événements :"
    cat /tmp/cloudtrail_latest.json | python3 -c "
import json,sys
data=json.load(sys.stdin)
for event in data.get('Records', [])[:5]:
    print(f\"  - {event.get('eventTime')} | {event.get('eventName')} | {event.get('userIdentity',{}).get('type','?')}\")
"
  fi
fi

echo "[$(date)] Test CloudTrail terminé" >> "$LOG_FILE"
echo "[DONE] Test CloudTrail terminé"
