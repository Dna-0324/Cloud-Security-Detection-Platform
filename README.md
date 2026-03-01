# Cloud Security Detection Platform

## Description du projet

Le projet **Cloud Security Detection Platform** a pour objectif de créer un laboratoire pratique de sécurité cloud sur AWS. Il permet de :

- Déployer une infrastructure sécurisée dans AWS (VPC, Subnets, EC2, Security Groups).
- Collecter et centraliser les logs cloud via **CloudTrail**, **VPC Flow Logs** et **CloudWatch**.
- Expérimenter la détection des menaces et l’ingénierie des règles de sécurité (Blue Team).
- Automatiser l’infrastructure avec **Terraform** et la configuration avec **Ansible**.
- Déployer des scripts pour la détection et la gestion des alertes.
- Enrichir les données avec de l’intelligence sur les menaces pour la surveillance et les rapports.

Ce projet est conçu pour apprendre la sécurité cloud, l’automatisation et la mise en place de bonnes pratiques de monitoring sur AWS.

## Pourquoi Docker ?

Tout le travail se fait dans un conteneur **Docker**, pour :

- Fournir un environnement isolé et reproductible, identique pour tous les développeurs.
- Éviter les conflits de dépendances avec le système hôte.
- Faciliter l’installation et l’usage d’outils comme Terraform, Ansible et AWS CLI sans polluer votre machine locale.
- Permettre de déployer rapidement un environnement complet de laboratoire cloud pour les tests et la pratique.

Le conteneur contient :

- Terraform (pour l’infrastructure as code)
- Ansible (pour la configuration et le déploiement)
- AWS CLI (pour tester et interagir avec AWS)
- Bash et utilitaires de base pour les scripts de détection

## Phase 1 - Infrastructure Setup

- VPC créé
- Subnet public configuré
- Internet Gateway attachée
- EC2 déployée (Amazon Linux 2023)
- Security Group renforcé (SSH restreint à l’IP personnelle)
- Adresse IP élastique associée
- Bucket S3 pour CloudTrail configuré (avec versioning et chiffrement)
- CloudTrail activé et multi-région
- CloudWatch Log Group configuré pour les logs CloudTrail
- Rôle IAM CloudTrail → CloudWatch attaché
- VPC Flow Logs configurés

Région : us-west-1 (California North)

## Phase 2 - Configuration et automatisation

- Installation d’Apache sur l’EC2 via Ansible
- Configuration de la rotation des logs Apache
- Déploiement des scripts de détection
- Création de répertoires pour logs et scripts
- Configuration d’alarmes CloudWatch pour la surveillance des erreurs Apache

## Objectif

Hands-on AWS Cloud Security Detection Lab focused on:

- Blue Team detection engineering
- Threat Intelligence enrichment
- Cloud-native logging (CloudTrail, VPC Flow Logs, CloudWatch)
- Terraform Infrastructure as Code
- Ansible configuration management
- Expérimentation dans un environnement Docker pour plus de sécurité et de reproductibilité
