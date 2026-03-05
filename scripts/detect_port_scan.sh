#!/bin/bash

LOG_FILE="/var/log/cloud-scripts/test_flowlogs.log"

echo "Détection de port scanning..."

grep REJECT $LOG_FILE | awk '{print $5 ":" $7}' | sort | uniq | cut -d ":" -f1 | sort | uniq -c | sort -nr | head
