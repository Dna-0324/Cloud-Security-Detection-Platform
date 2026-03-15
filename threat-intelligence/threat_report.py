#!/usr/bin/env python3
# threat_report.py - Génère un rapport HTML des menaces détectées

import json
import os
from datetime import datetime

REPORT_JSON = "/var/log/cloud-scripts/threat_report.json"
HTML_OUTPUT = "/var/log/cloud-scripts/threat_report.html"

def get_color(level):
    colors = {
        "CRITIQUE": "#ff0000",
        "ÉLEVÉ":    "#ff6600",
        "MOYEN":    "#ffaa00",
        "FAIBLE":   "#00aa00"
    }
    return colors.get(level, "#888888")

def generate_report(ips):
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    total = len(ips)
    critiques = sum(1 for ip in ips if ip["threat_level"] == "CRITIQUE")
    eleves    = sum(1 for ip in ips if ip["threat_level"] == "ÉLEVÉ")
    moyens    = sum(1 for ip in ips if ip["threat_level"] == "MOYEN")
    faibles   = sum(1 for ip in ips if ip["threat_level"] == "FAIBLE")

    rows = ""
    for ip in sorted(ips, key=lambda x: x["abuse_score"], reverse=True):
        color = get_color(ip["threat_level"])
        rows += f"""
        <tr>
            <td>{ip['ip']}</td>
            <td>{ip['country']}</td>
            <td>{ip['abuse_score']}%</td>
            <td>{ip['abuse_reports']}</td>
            <td>{ip['vt_malicious']}</td>
            <td>{ip['vt_suspicious']}</td>
            <td style="color:{color}; font-weight:bold">{ip['threat_level']}</td>
            <td>{ip['timestamp']}</td>
        </tr>"""

    html = f"""<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Threat Intelligence Report</title>
    <style>
        body {{ font-family: Arial, sans-serif; background: #1a1a2e; color: #eee; padding: 20px; }}
        h1 {{ color: #00d4ff; text-align: center; }}
        .subtitle {{ text-align: center; color: #aaa; margin-bottom: 30px; }}
        .stats {{ display: flex; justify-content: center; gap: 20px; margin-bottom: 30px; }}
        .stat-box {{ background: #16213e; border-radius: 8px; padding: 15px 25px; text-align: center; }}
        .stat-box .number {{ font-size: 2em; font-weight: bold; }}
        .stat-box .label {{ font-size: 0.85em; color: #aaa; }}
        table {{ width: 100%; border-collapse: collapse; background: #16213e; border-radius: 8px; overflow: hidden; }}
        th {{ background: #0f3460; padding: 12px; text-align: left; color: #00d4ff; }}
        td {{ padding: 10px 12px; border-bottom: 1px solid #0f3460; }}
        tr:hover {{ background: #0f3460; }}
    </style>
</head>
<body>
    <h1>🛡️ Cloud Security Detection Platform</h1>
    <p class="subtitle">Threat Intelligence Report — Généré le {now}</p>

    <div class="stats">
        <div class="stat-box">
            <div class="number" style="color:#00d4ff">{total}</div>
            <div class="label">IPs analysées</div>
        </div>
        <div class="stat-box">
            <div class="number" style="color:#ff0000">{critiques}</div>
            <div class="label">Critiques</div>
        </div>
        <div class="stat-box">
            <div class="number" style="color:#ff6600">{eleves}</div>
            <div class="label">Élevées</div>
        </div>
        <div class="stat-box">
            <div class="number" style="color:#ffaa00">{moyens}</div>
            <div class="label">Moyennes</div>
        </div>
        <div class="stat-box">
            <div class="number" style="color:#00aa00">{faibles}</div>
            <div class="label">Faibles</div>
        </div>
    </div>

    <table>
        <thead>
            <tr>
                <th>IP</th>
                <th>Pays</th>
                <th>Score Abuse</th>
                <th>Rapports</th>
                <th>VT Malicious</th>
                <th>VT Suspicious</th>
                <th>Niveau</th>
                <th>Timestamp</th>
            </tr>
        </thead>
        <tbody>
            {rows}
        </tbody>
    </table>
</body>
</html>"""

    with open(HTML_OUTPUT, "w") as f:
        f.write(html)
    print(f"[OK] Rapport HTML généré → {HTML_OUTPUT}")

if __name__ == "__main__":
    if not os.path.exists(REPORT_JSON):
        print(f"[ERREUR] Fichier introuvable : {REPORT_JSON}")
        print("Lance d'abord enrich_ips.sh")
        exit(1)

    with open(REPORT_JSON) as f:
        ips = json.load(f)

    if not ips:
        print("[WARN] Aucune IP dans le rapport JSON")
        exit(0)

    generate_report(ips)
