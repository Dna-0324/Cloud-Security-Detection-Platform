#!/bin/bash

# Fichier de log
LOG_FILE=/var/log/cloud-scripts/test_flowlogs.log

# Ajouter un en-tête dans le log
echo "Test de lecture VPC Flow Logs - $(date)" >> $LOG_FILE

# Nom du log group VPC Flow Logs (à adapter si nécessaire)
LOG_GROUP="/aws/cloudtrail/cloud-sec-trail"

# Lister les log streams
echo "Liste des log streams dans $LOG_GROUP:" >> $LOG_FILE
aws logs describe-log-streams --log-group-name "$LOG_GROUP" --region us-west-1 >> $LOG_FILE 2>&1

# Récupérer les 5 derniers événements d’un log stream
# Ici on prend le premier log stream pour exemple
STREAM_NAME=$(aws logs describe-log-streams --log-group-name "$LOG_GROUP" \
    --query 'logStreams[0].logStreamName' --output text --region us-west-1)

if [ "$STREAM_NAME" != "None" ]; then
    echo "Derniers événements du log stream $STREAM_NAME:" >> $LOG_FILE
    aws logs get-log-events --log-group-name "$LOG_GROUP" \
        --log-stream-name "$STREAM_NAME" --limit 5 --region us-west-1 >> $LOG_FILE 2>&1
else
    echo "Aucun log stream trouvé dans $LOG_GROUP" >> $LOG_FILE
fi
