#!/bin/bash

LOG_FILE="/var/log/cloud-scripts/test_flowlogs.log"
DETECTED_IPS="/var/log/cloud-scripts/detected_ips.txt"

echo "Détection des IP attaquantes - $(date)"

# Récupération des IP depuis le log Flow Logs
grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$LOG_FILE" | sort | uniq > "$DETECTED_IPS"

# Affichage des IP détectées
echo "IP attaquantes détectées :"
cat "$DETECTED_IPS"

# Envoyer une alerte SNS si des IP attaquantes sont détectées
SNS_TOPIC_ARN="arn:aws:sns:us-west-1:798329741052:cloud-sec-alerts"
DETECTED_IPS_FILE="/var/log/cloud-scripts/detected_ips.txt"

if [ -s "$DETECTED_IPS_FILE" ]; then
    MESSAGE="Alert: IP attaquantes détectées sur le serveur `hostname`:\n$(cat $DETECTED_IPS_FILE)"
    aws sns publish \
        --topic-arn "$SNS_TOPIC_ARN" \
        --message "$MESSAGE" \
        --region us-west-1
fi
