#!/bin/bash
# alerts_sns.sh - Envoie des alertes SNS pour les IPs suspectes détectées

SNS_TOPIC_ARN="arn:aws:sns:us-west-1:798329741052:cloud-sec-alerts"
REGION="us-west-1"
ATTACKERS_FILE="/var/log/cloud-scripts/attackers.txt"
PORT_SCAN_FILE="/var/log/cloud-scripts/port_scanners.txt"
DETECTED_IPS="/var/log/cloud-scripts/detected_ips.txt"
LOG_FILE="/var/log/cloud-scripts/alerts_sns.log"
HOSTNAME=$(hostname)
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "=============================="
echo " ALERTES SNS - $(date)"
echo "=============================="

echo "[$(date)] Début envoi alertes SNS" >> "$LOG_FILE"

send_alert() {
  local subject="$1"
  local message="$2"

  echo "[*] Envoi alerte : $subject"
  aws sns publish \
    --topic-arn "$SNS_TOPIC_ARN" \
    --subject "$subject" \
    --message "$message" \
    --region "$REGION" > /dev/null 2>&1

  if [ $? -eq 0 ]; then
    echo "[OK] Alerte envoyée"
    echo "[$(date)] Alerte envoyée: $subject" >> "$LOG_FILE"
  else
    echo "[ERREUR] Échec envoi alerte"
    echo "[$(date)] ERREUR envoi: $subject" >> "$LOG_FILE"
  fi
}

ALERT_SENT=0

# --- Alertes pour les attaquants détectés ---
if [ -f "$ATTACKERS_FILE" ] && [ -s "$ATTACKERS_FILE" ]; then
  ATTACKER_COUNT=$(wc -l < "$ATTACKERS_FILE")
  ATTACKER_LIST=$(cat "$ATTACKERS_FILE")

  MESSAGE="🚨 ALERTE SÉCURITÉ - Cloud Security Detection Platform
Hôte     : $HOSTNAME
Date     : $DATE
Région   : $REGION

$ATTACKER_COUNT IP(s) suspecte(s) détectée(s) :
$ATTACKER_LIST

Action recommandée : Vérifier et bloquer ces IPs dans le Security Group AWS.
Console AWS : https://console.aws.amazon.com/vpc/home?region=$REGION#SecurityGroups:"

  send_alert "🚨 [$HOSTNAME] $ATTACKER_COUNT IP(s) suspecte(s) détectée(s)" "$MESSAGE"
  ALERT_SENT=$((ALERT_SENT + 1))
fi

# --- Alertes pour les port scanners ---
if [ -f "$PORT_SCAN_FILE" ] && [ -s "$PORT_SCAN_FILE" ]; then
  SCANNER_COUNT=$(wc -l < "$PORT_SCAN_FILE")
  SCANNER_LIST=$(cat "$PORT_SCAN_FILE")

  MESSAGE="⚠️ ALERTE PORT SCAN - Cloud Security Detection Platform
Hôte     : $HOSTNAME
Date     : $DATE
Région   : $REGION

$SCANNER_COUNT scanner(s) de ports détecté(s) :
$SCANNER_LIST

Action recommandée : Ajouter ces IPs en blacklist dans le Security Group.
Console AWS : https://console.aws.amazon.com/vpc/home?region=$REGION#SecurityGroups:"

  send_alert "⚠️ [$HOSTNAME] $SCANNER_COUNT port scanner(s) détecté(s)" "$MESSAGE"
  ALERT_SENT=$((ALERT_SENT + 1))
fi

# --- Résumé si aucune alerte ---
if [ "$ALERT_SENT" -eq 0 ]; then
  echo "[OK] Aucune menace détectée, pas d'alerte envoyée"

  # Envoyer un rapport de statut quotidien si c'est l'heure (8h)
  HOUR=$(date +%H)
  if [ "$HOUR" -eq 8 ]; then
    IP_COUNT=$(wc -l < "$DETECTED_IPS" 2>/dev/null || echo 0)
    MESSAGE="✅ Rapport quotidien - Cloud Security Detection Platform
Hôte   : $HOSTNAME
Date   : $DATE
Statut : Aucune menace détectée
IPs surveillées : $IP_COUNT
Tous les systèmes fonctionnent normalement."

    send_alert "✅ [$HOSTNAME] Rapport quotidien - Aucune menace" "$MESSAGE"
  fi
fi

echo "[$(date)] Fin envoi alertes SNS ($ALERT_SENT alerte(s) envoyée(s))" >> "$LOG_FILE"
echo "[DONE] $ALERT_SENT alerte(s) envoyée(s)"
