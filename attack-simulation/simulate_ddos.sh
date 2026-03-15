#!/bin/bash
# simulate_ddos.sh - Simule un flood HTTP sur l'EC2

TARGET_IP="54.219.221.103"
TARGET_URL="http://$TARGET_IP"
LOG_FILE="/var/log/cloud-scripts/attack_simulation.log"
REQUESTS=50
CONCURRENT=5

echo "=============================="
echo " SIMULATION FLOOD HTTP - $(date)"
echo "=============================="

echo "[$(date)] Début simulation flood HTTP vers $TARGET_URL" >> "$LOG_FILE"

# Installer curl si absent
if ! command -v curl &> /dev/null; then
  apt-get install -y curl > /dev/null 2>&1
fi

echo "[*] Envoi de $REQUESTS requêtes HTTP vers $TARGET_URL..."

SUCCESS=0
FAILED=0

for i in $(seq 1 $REQUESTS); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 3 \
    --max-time 5 \
    "$TARGET_URL" 2>/dev/null)

  if [ "$STATUS" -eq 200 ] 2>/dev/null; then
    SUCCESS=$((SUCCESS + 1))
    echo "[*] Requête $i → HTTP $STATUS ✓"
  else
    FAILED=$((FAILED + 1))
    echo "[*] Requête $i → HTTP $STATUS ✗"
  fi

  # Petite pause pour ne pas bloquer complètement
  if [ $((i % CONCURRENT)) -eq 0 ]; then
    sleep 0.2
  fi
done

echo ""
echo "[DONE] Flood HTTP terminé → $SUCCESS succès / $FAILED échecs"
echo "[$(date)] Flood HTTP: $SUCCESS succès $FAILED échecs" >> "$LOG_FILE"
