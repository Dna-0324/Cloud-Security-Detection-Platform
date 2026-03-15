#!/bin/bash
# simulate_port_scan.sh - Simule un scan de ports sur l'EC2

TARGET_IP="54.219.221.103"
LOG_FILE="/var/log/cloud-scripts/attack_simulation.log"

echo "=============================="
echo " SIMULATION PORT SCAN - $(date)"
echo "=============================="

echo "[$(date)] Début simulation port scan vers $TARGET_IP" >> "$LOG_FILE"

# Installer nmap si absent
if ! command -v nmap &> /dev/null; then
  echo "[*] Installation de nmap..."
  apt-get install -y nmap > /dev/null 2>&1
fi

echo "[*] Scan des ports communs..."
nmap -sS -T4 --top-ports 100 "$TARGET_IP" 2>/dev/null

echo "[*] Scan de ports spécifiques (SSH, HTTP, HTTPS, RDP)..."
nmap -sV -p 22,80,443,3389,8080,3306,5432 "$TARGET_IP" 2>/dev/null

echo "[$(date)] Port scan terminé vers $TARGET_IP" >> "$LOG_FILE"
echo "[DONE] Simulation port scan terminée"
