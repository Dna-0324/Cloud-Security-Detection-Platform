# 🛡️ Cloud Security Detection Platform

## Sommaire

1. [Description du projet](#description-du-projet)
2. [Architecture](#architecture)
3. [Pourquoi Docker ?](#pourquoi-docker)
4. [Phase 1 – Infrastructure Setup](#phase-1--infrastructure-setup)
5. [Phase 2 – Configuration et automatisation](#phase-2--configuration-et-automatisation)
6. [Phase 3 – Threat Intelligence](#phase-3--threat-intelligence)
7. [Phase 4 – Attack Simulation](#phase-4--attack-simulation)
8. [Phase 5 – Grafana Dashboard](#phase-5--grafana-dashboard)
9. [Phase 6 – Auto-Remediation SOAR](#phase-6--auto-remediation-soar)
10. [Objectifs pédagogiques](#objectifs-pédagogiques)
11. [Instructions pour lancer le lab](#instructions-pour-lancer-le-lab)

---

## Description du projet

Le projet **Cloud Security Detection Platform** est un laboratoire pratique de sécurité cloud sur AWS. Il simule un environnement SOC (Security Operations Center) réel permettant de :

* Déployer une infrastructure sécurisée sur AWS (VPC, Subnets, EC2, Security Groups) via Terraform.
* Collecter et centraliser les logs cloud via CloudTrail, VPC Flow Logs et CloudWatch.
* Détecter les menaces et enrichir les données avec de la Threat Intelligence (AbuseIPDB, VirusTotal).
* Simuler des attaques réelles (brute force SSH, port scanning, flood HTTP).
* Automatiser l'infrastructure avec Terraform et la configuration avec Ansible.
* Visualiser les métriques de sécurité en temps réel avec Grafana.
* Envoyer des alertes vers AWS SNS pour les IPs suspectes.

---

## Architecture
```
┌─────────────────────────────────────────────────────┐
│                   Docker Container                   │
│         Terraform │ Ansible │ AWS CLI │ Bash         │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│                      AWS Cloud                       │
│                                                      │
│  VPC (10.0.0.0/16)                                   │
│  ├── Subnet Public (10.0.1.0/24)                     │
│  │   └── EC2 (Amazon Linux 2023) ← Ansible           │
│  ├── Security Group (SSH restreint) ←── SOAR AUTO    │
│  ├── Internet Gateway + Route Table                  │
│  └── Elastic IP                                      │
│                                                      │
│  Logging & Monitoring                                │
│  ├── CloudTrail (multi-région) → S3                  │
│  ├── VPC Flow Logs → CloudWatch                      │
│  └── CloudWatch Alarms → SNS → Email                 │
└─────────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│              Security Detection Pipeline             │
│                                                      │
│  attack-simulation/ → génère du trafic suspect       │
│       ↓                                              │
│  scripts/ → détecte les menaces                      │
│       ↓                                              │
│  threat-intelligence/ → enrichit les IPs             │
│       ↓                                              │
│  Grafana → visualise en temps réel                   │
│       ↓                                              │
│  SNS → envoie les alertes email                      │
└─────────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│          Phase 6 — Auto-Remediation (SOAR)           │
│                                                      │
│  soar/auto_block.sh → vérifie le score Threat Intel  │
│       ↓                                              │
│  Score CRITIQUE ou AbuseScore ≥ 50%                  │
│       ↓                                              │
│  Blocage automatique → Security Group AWS            │
│       ↓                                              │
│  Email récapitulatif → SNS (1 seul mail)             │
└─────────────────────────────────────────────────────┘
```

---

## Pourquoi Docker ?

Tout le travail se fait dans un conteneur Docker, pour :

* Fournir un environnement isolé et reproductible.
* Éviter les conflits de dépendances avec le système hôte.
* Faciliter l'installation de Terraform, Ansible et AWS CLI.
* Permettre de déployer rapidement un environnement complet.

Le conteneur contient :
* Terraform (Infrastructure as Code)
* Ansible (configuration et déploiement)
* AWS CLI (interagir avec AWS)
* Bash et Python3

---

## Phase 1 – Infrastructure Setup

**Région :** us-west-1 (California North)

| Ressource | Détail |
|---|---|
| VPC | 10.0.0.0/16 |
| Subnet public | 10.0.1.0/24 |
| Internet Gateway | Attachée au VPC |
| EC2 | Amazon Linux 2023, t2.micro |
| Security Group | SSH restreint à l'IP personnelle |
| Elastic IP | Associée à l'EC2 |
| S3 Bucket | CloudTrail logs (versioning + chiffrement AES256) |
| CloudTrail | Activé multi-région |
| CloudWatch | Log Group + Alarmes |
| IAM Role | CloudTrail → CloudWatch |
| VPC Flow Logs | Trafic ALL → CloudWatch |

---

## Phase 2 – Configuration et automatisation

Configuration de l'EC2 via Ansible :

* Installation d'Apache
* Configuration de la rotation des logs Apache
* Création des répertoires `/opt/cloud-scripts/` et `/var/log/cloud-scripts/`
* Déploiement des scripts de détection

### Scripts de détection

| Script | Fonction |
|---|---|
| `test_cloudtrail.sh` | Vérifie la lecture des logs CloudTrail |
| `test_flowlogs.sh` | Lit et analyse les VPC Flow Logs |
| `detect_attackers.sh` | Détecte les IPs suspectes |
| `detect_port_scan.sh` | Identifie les tentatives de port scanning |
| `alerts_sns.sh` | Envoie des alertes SNS pour les IPs suspectes |

---

## Phase 3 – Threat Intelligence

Enrichissement des IPs suspectes avec :

* **AbuseIPDB** — score de confiance d'abus, nombre de rapports, pays
* **VirusTotal** — détections malveillantes et suspectes

### Niveaux de menace

| Niveau | Critère |
|---|---|
| 🔴 CRITIQUE | AbuseScore ≥ 80% ou VT Malicious ≥ 5 |
| 🟠 ÉLEVÉ | AbuseScore ≥ 50% ou VT Malicious ≥ 2 |
| 🟡 MOYEN | AbuseScore ≥ 20% ou VT Malicious ≥ 1 |
| 🟢 FAIBLE | En dessous des seuils |

Scripts :
* `enrich_ips.sh` — interroge les APIs et génère un rapport JSON
* `threat_report.py` — génère un rapport HTML visuel

---

## Phase 4 – Attack Simulation

Scripts pour simuler des attaques sur le lab :

| Script | Type d'attaque |
|---|---|
| `simulate_bruteforce.sh` | Brute force SSH (20 tentatives) |
| `simulate_port_scan.sh` | Scan des 100 ports principaux via nmap |
| `simulate_ddos.sh` | Flood HTTP (50 requêtes concurrentes) |

⚠️ Ces scripts sont uniquement destinés à un usage dans ce lab personnel.

---

## Phase 5 – Grafana Dashboard

Visualisation en temps réel des métriques de sécurité :

* Nombre d'IPs suspectes détectées
* Score de menace moyen
* Carte géographique des attaquants
* Historique des alertes SNS
* Trafic VPC Flow Logs

---
## Phase 6 – Auto-Remediation (SOAR)

Blocage automatique des IPs critiques détectées :

| Script | Fonction |
|---|---|
| `get_threat_info.py` | Récupère le score et niveau de menace depuis le rapport JSON |
| `auto_block.sh` | Bloque automatiquement les IPs critiques dans le Security Group AWS |

### Workflow SOAR

1. `detect_attackers.sh` détecte les IPs suspectes
2. `enrich_ips.sh` enrichit avec AbuseIPDB + VirusTotal
3. `auto_block.sh` vérifie le score — si CRITIQUE ou score ≥ 50% → blocage automatique
4. La règle est ajoutée dans le Security Group AWS (`IpProtocol: -1` = tout le trafic bloqué)
5. Un email récapitulatif est envoyé via SNS avec toutes les IPs bloquées

### Critères de blocage

| Condition | Action |
|---|---|
| Niveau CRITIQUE | Blocage automatique |
| AbuseScore ≥ 50% | Blocage automatique |
| IP déjà bloquée | Ignorée (pas de doublon) |
| Score insuffisant | Ignorée, alerte uniquement |

---
## Objectifs pédagogiques

* **Blue Team** detection engineering
* **Threat Intelligence** enrichment
* **Cloud-native logging** (CloudTrail, VPC Flow Logs, CloudWatch)
* **Terraform** Infrastructure as Code
* **Ansible** configuration management
* **Docker** environnement reproductible
* **Grafana** visualisation et monitoring

---

## Instructions pour lancer le lab

### 1. Prérequis
* Docker Desktop installé
* Compte AWS avec clés d'accès configurées
* Clé SSH `cloud-sec-key.pem`

### 2. Lancer le conteneur Docker
```bash
docker run -it --name cloud-security-lab \
  -v ~/.aws:/root/.aws:ro \
  -v ./terraform:/cloudlab/terraform \
  -v ./ansible:/cloudlab/ansible \
  -v ./scripts:/cloudlab/scripts \
  cloud-security-lab
```

### 3. Déployer l'infrastructure
```bash
cd /cloudlab/terraform
terraform init
terraform apply
```

### 4. Configurer l'EC2
```bash
ansible-playbook -i /cloudlab/ansible/inventory.ini /cloudlab/ansible/test.yml
```

### 5. Simuler des attaques
```bash
/cloudlab/attack-simulation/simulate_port_scan.sh
/cloudlab/attack-simulation/simulate_bruteforce.sh
/cloudlab/attack-simulation/simulate_ddos.sh
```

### 6. Détecter les menaces
```bash
/opt/cloud-scripts/test_cloudtrail.sh
/opt/cloud-scripts/test_flowlogs.sh
/opt/cloud-scripts/detect_attackers.sh
/opt/cloud-scripts/detect_port_scan.sh
```

### 7. Enrichir avec Threat Intelligence
```bash
/cloudlab/threat-intelligence/enrich_ips.sh
python3 /cloudlab/threat-intelligence/threat_report.py
```

### 8. Envoyer les alertes
```bash
/opt/cloud-scripts/alerts_sns.sh
```