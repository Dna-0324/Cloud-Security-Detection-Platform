#!/bin/bash
# test_cloudtrail.sh
LOG_FILE="/var/log/cloud-scripts/test_cloudtrail.log"

echo "Test de lecture CloudTrail - $(date)" >> "$LOG_FILE"

aws cloudtrail lookup-events --max-results 5 --region us-west-1 >> "$LOG_FILE" 2>&1
