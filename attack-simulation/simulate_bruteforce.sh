#!/bin/bash
# simulate_bruteforce.sh - Simule une attaque SSH brute force sur l'EC2

TARGET_IP="54.219.221.103"
TARGET_PORT="22"
LOG_FILE="/var/log/cloud-scripts/attack_simulation.log"
ATTEMPTS=20

echo "=============================="
echo " SIMULATION BRUTE FORCE SSH - $(date)"
echo "=============================="

echo "[$(date)] Début simulation brute force SSH vers $TARGET_IP" >> "$LOG_FILE"

PASSWORDS=("admin" "password" "123456" "root" "test" "ubuntu" "ec2-user" "hadoop" "oracle" "postgres")
USERS=("root" "admin" "user" "test" "ubuntu" "ec2-user" "deploy" "git" "mysql" "postgres")

for i in $(seq 1 $ATTEMPTS); do
  USER=${USERS[$((RANDOM % ${#USERS[@]}))]}
  PASS=${PASSWORDS[$((RANDOM % ${#PASSWORDS[@]}))]}
  echo "[*] Tentative $i/$ATTEMPTS → user=$USER pass=$PASS"
  ssh -o StrictHostKeyChecking=no \
      -o ConnectTimeout=3 \
      -o PasswordAuthentication=yes \
      -o BatchMode=no \
      "$USER@$TARGET_IP" exit 2>/dev/null
  echo "[$(date)] Tentative SSH $i: $USER@$TARGET_IP" >> "$LOG_FILE"
  sleep 0.5
done

echo "[DONE] Simulation brute force terminée — $ATTEMPTS tentatives"
echo "[$(date)] Fin simulation brute force" >> "$LOG_FILE"
