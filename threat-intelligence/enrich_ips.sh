#!/bin/bash
# enrich_ips.sh - Enrichit les IPs suspectes avec AbuseIPDB et VirusTotal

ABUSEIPDB_KEY="9ea269f9137422e13f7d467e9cae9d12b2edb980dd8af1ce03f8e93e5411b250759076a23bca48a2"
VIRUSTOTAL_KEY="216dfc92ded996bce9a69ab364bf223f278ffbd72d7735fc0ef28c725354f28d"
DETECTED_IPS="/var/log/cloud-scripts/detected_ips.txt"
REPORT_FILE="/var/log/cloud-scripts/threat_report.json"
LOG_FILE="/var/log/cloud-scripts/enrich_ips.log"

echo "=============================="
echo " ENRICHISSEMENT THREAT INTEL - $(date)"
echo "=============================="

> "$REPORT_FILE"
echo "[" >> "$REPORT_FILE"
FIRST=true

if [ ! -f "$DETECTED_IPS" ] || [ ! -s "$DETECTED_IPS" ]; then
  echo "[WARN] Aucune IP détectée dans $DETECTED_IPS"
  exit 1
fi

while IFS= read -r IP; do
  [ -z "$IP" ] && continue
  echo "[*] Analyse de $IP..."

  # --- AbuseIPDB ---
  ABUSE=$(curl -s -G https://api.abuseipdb.com/api/v2/check \
    --data-urlencode "ipAddress=$IP" \
    -d maxAgeInDays=90 \
    -d verbose \
    -H "Key: $ABUSEIPDB_KEY" \
    -H "Accept: application/json")

  ABUSE_SCORE=$(echo "$ABUSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['abuseConfidenceScore'])" 2>/dev/null || echo "0")
  ABUSE_COUNTRY=$(echo "$ABUSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['countryCode'])" 2>/dev/null || echo "??")
  ABUSE_REPORTS=$(echo "$ABUSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['totalReports'])" 2>/dev/null || echo "0")

  # --- VirusTotal ---
  VT=$(curl -s "https://www.virustotal.com/api/v3/ip_addresses/$IP" \
    -H "x-apikey: $VIRUSTOTAL_KEY")

  VT_MALICIOUS=$(echo "$VT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['attributes']['last_analysis_stats']['malicious'])" 2>/dev/null || echo "0")
  VT_SUSPICIOUS=$(echo "$VT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['attributes']['last_analysis_stats']['suspicious'])" 2>/dev/null || echo "0")

  # --- Niveau de menace ---
  if [ "$ABUSE_SCORE" -ge 80 ] || [ "$VT_MALICIOUS" -ge 5 ]; then
    THREAT_LEVEL="CRITIQUE"
  elif [ "$ABUSE_SCORE" -ge 50 ] || [ "$VT_MALICIOUS" -ge 2 ]; then
    THREAT_LEVEL="ÉLEVÉ"
  elif [ "$ABUSE_SCORE" -ge 20 ] || [ "$VT_MALICIOUS" -ge 1 ]; then
    THREAT_LEVEL="MOYEN"
  else
    THREAT_LEVEL="FAIBLE"
  fi

  echo "[!] $IP → AbuseScore=$ABUSE_SCORE% | VT_Malicious=$VT_MALICIOUS | Niveau=$THREAT_LEVEL"
  echo "[$(date)] $IP ABUSE=$ABUSE_SCORE VT=$VT_MALICIOUS LEVEL=$THREAT_LEVEL" >> "$LOG_FILE"

  # --- Écriture JSON ---
  if [ "$FIRST" = true ]; then
    FIRST=false
  else
    echo "," >> "$REPORT_FILE"
  fi

  cat >> "$REPORT_FILE" << JSONEOF
  {
    "ip": "$IP",
    "country": "$ABUSE_COUNTRY",
    "abuse_score": $ABUSE_SCORE,
    "abuse_reports": $ABUSE_REPORTS,
    "vt_malicious": $VT_MALICIOUS,
    "vt_suspicious": $VT_SUSPICIOUS,
    "threat_level": "$THREAT_LEVEL",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
JSONEOF

done < "$DETECTED_IPS"

echo "]" >> "$REPORT_FILE"
echo "[DONE] Rapport sauvegardé → $REPORT_FILE"
