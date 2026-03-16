#!/usr/bin/env python3
import json, sys

ip = sys.argv[1]
report_file = sys.argv[2]
result = "0|INCONNU"

try:
    data = json.load(open(report_file))
    for entry in data:
        if entry.get('ip') == ip:
            score = str(entry.get('abuse_score', 0)).strip()
            level = str(entry.get('threat_level', 'INCONNU')).strip()
            result = f"{score}|{level}"
            break
except:
    pass

print(result)
