FROM ubuntu:22.04

LABEL maintainer="Cloud Security Detection Platform"
LABEL description="Lab environment with Terraform, Ansible, AWS CLI"

ENV DEBIAN_FRONTEND=noninteractive
ENV TERRAFORM_VERSION=1.7.5
ENV AWS_DEFAULT_REGION=us-west-1

# --- Dépendances système ---
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    git \
    python3 \
    python3-pip \
    openssh-client \
    jq \
    gnupg \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# --- Installation Terraform ---
RUN wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && mv terraform /usr/local/bin/ \
    && rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# --- Installation AWS CLI v2 ---
RUN curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip -q awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws/

# --- Installation Ansible ---
RUN pip3 install --no-cache-dir \
    ansible \
    boto3 \
    botocore \
    amazon.aws

RUN ansible-galaxy collection install amazon.aws community.aws

# --- Répertoires du projet ---
RUN mkdir -p /cloudlab/terraform \
             /cloudlab/ansible/templates \
             /cloudlab/scripts \
             /root/.aws

WORKDIR /cloudlab

# --- Copie des fichiers du projet ---
COPY terraform/main.tf         /cloudlab/terraform/
COPY ansible/test.yml          /cloudlab/ansible/
COPY ansible/inventory.ini     /cloudlab/ansible/
COPY ansible/templates/        /cloudlab/ansible/templates/
COPY scripts/                  /cloudlab/scripts/

# --- Rendre les scripts exécutables ---
RUN chmod +x /cloudlab/scripts/*.sh

# --- Vérifications à l'image build ---
RUN terraform version && \
    aws --version && \
    ansible --version | head -1

CMD ["/bin/bash"]
