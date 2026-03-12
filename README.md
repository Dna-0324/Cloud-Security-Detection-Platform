# Cloud Security Detection Platform

## Sommaire

1. [Description du projet](#description-du-projet)
2. [Pourquoi Docker ?](#pourquoi-docker)
3. [Phase 1 – Infrastructure Setup](#phase-1--infrastructure-setup)
4. [Phase 2 – Configuration et automatisation](#phase-2--configuration-et-automatisation)
5. [Scripts de détection et alertes](#scripts-de-détection-et-alertes)
6. [Objectifs pédagogiques](#objectifs-pédagogiques)
7. [Instructions pour lancer les scripts](#instructions-pour-lancer-les-scripts)

---

## Description du projet

Le projet **Cloud Security Detection Platform** a pour objectif de créer un laboratoire pratique de sécurité cloud sur AWS. Il permet de :

* Déployer une infrastructure sécurisée dans AWS (VPC, Subnets, EC2, Security Groups).
* Collecter et centraliser les logs cloud via CloudTrail, VPC Flow Logs et CloudWatch.
* Expérimenter la détection des menaces et l’ingénierie des règles de sécurité (Blue Team).
* Automatiser l’infrastructure avec Terraform et la configuration avec Ansible.
* Déployer des scripts pour la détection et la gestion des alertes.
* Envoyer des alertes vers AWS SNS pour les IPs suspectes.
* Enrichir les données avec de l’intelligence sur les menaces pour la surveillance et les rapports.

Ce projet est conçu pour apprendre la sécurité cloud, l’automatisation et la mise en place de bonnes pratiques de monitoring sur AWS.

---

## Pourquoi Docker ?

Tout le travail se fait dans un conteneur Docker, pour :

* Fournir un environnement isolé et reproductible, identique pour tous les développeurs.
* Éviter les conflits de dépendances avec le système hôte.
* Faciliter l’installation et l’usage d’outils comme Terraform, Ansible et AWS CLI sans polluer votre machine locale.
* Permettre de déployer rapidement un environnement complet de laboratoire cloud pour les tests et la pratique.

Le conteneur contient :

* Terraform (Infrastructure as Code)
* Ansible (configuration et déploiement)
* AWS CLI (interagir avec AWS)
* Bash et utilitaires de base pour les scripts de détection

---

## Phase 1 – Infrastructure Setup

* VPC créé
* Subnet public configuré
* Internet Gateway attachée
* EC2 déployée (Amazon Linux 2023)
* Security Group renforcé (SSH restreint à l’IP personnelle)
* Adresse IP élastique associée
* Bucket S3 pour CloudTrail configuré (versioning et chiffrement)
* CloudTrail activé et multi-région
* CloudWatch Log Group configuré pour les logs CloudTrail
* Rôle IAM CloudTrail → CloudWatch attaché
* VPC Flow Logs configurés

**Région :** us-west-1 (California North)

---

## Phase 2 – Configuration et automatisation

* Installation d’Apache sur l’EC2 via Ansible
* Configuration de la rotation des logs Apache
* Création de répertoires pour logs et scripts (`/opt/cloud-scripts/`, `/var/log/cloud-scripts/`)
* Déploiement des scripts de détection et d’analyse de logs

### Scripts déployés

| Script                | Fonction                                     |
| --------------------- | -------------------------------------------- |
| `test_cloudtrail.sh`  | Vérifie la lecture des logs CloudTrail       |
| `test_flowlogs.sh`    | Lit et analyse les VPC Flow Logs             |
| `detect_attackers.sh` | Détecte les IP suspectes et les enregistre   |
| `detect_port_scan.sh` | Identifie les tentatives de port scanning    |
| `alerts_sns.sh`       | Envoie des alertes SNS pour les IP suspectes |

* Extraction et centralisation des IP suspectes dans `/var/log/cloud-scripts/detected_ips.txt`
* Envoi d’alertes par email via SNS (`cloud-sec-alerts`) pour les IP suspectes
* Configuration d’alarmes CloudWatch pour la surveillance des erreurs Apache

---

## Objectifs pédagogiques

* Hands-on **AWS Cloud Security Detection Lab** focused on:

  * Blue Team detection engineering
  * Threat Intelligence enrichment
  * Cloud-native logging (CloudTrail, VPC Flow Logs, CloudWatch)
  * Terraform Infrastructure as Code
  * Ansible configuration management
  * Expérimentation dans un environnement Docker pour plus de sécurité et de reproductibilité

---

## Instructions pour lancer les scripts

1. Vérifier que les logs CloudTrail et VPC Flow Logs sont présents :

```bash
/opt/cloud-scripts/test_cloudtrail.sh
/opt/cloud-scripts/test_flowlogs.sh
```

2. Extraire les IP suspectes :

```bash
grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' /var/log/cloud-scripts/test_flowlogs.log | sort | uniq > /var/log/cloud-scripts/detected_ips.txt
```

3. Lancer la détection des attaquants et port scanning :

```bash
/opt/cloud-scripts/detect_attackers.sh
/opt/cloud-scripts/detect_port_scan.sh
```

4. Envoyer les alertes SNS aux adresses configurées :

```bash
/opt/cloud-scripts/alerts_sns.sh
```

5. Vérifier les IP détectées :

```bash
cat /var/log/cloud-scripts/detected_ips.txt
```

---

