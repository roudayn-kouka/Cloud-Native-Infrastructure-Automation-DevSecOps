#!/bin/bash
# Installs everything the Jenkinsfile needs on an Amazon Linux 2023 build agent.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run as root (sudo)." >&2; exit 1; }

ARCH="$(uname -m)"; case "$ARCH" in x86_64) ARCH_ALT=amd64 ;; aarch64) ARCH_ALT=arm64 ;; *) echo "unsupported arch $ARCH"; exit 1 ;; esac

dnf install -y java-21-amazon-corretto-headless git zip unzip jq docker nodejs22 npm
systemctl enable --now docker
id jenkins &>/dev/null || useradd -m jenkins
usermod -aG docker jenkins

# kubectl (stable channel) - optional on the agent, handy for debugging
KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH_ALT}/kubectl"
chmod +x /usr/local/bin/kubectl

# Helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Trivy
cat > /etc/yum.repos.d/trivy.repo <<'REPO'
[trivy]
name=Trivy repository
baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/$basearch/
gpgcheck=0
enabled=1
REPO
dnf install -y trivy

# Terraform
dnf install -y dnf-plugins-core
dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
dnf install -y terraform

echo "Agent ready. Versions:"
node -v; docker --version; aws --version; trivy --version | head -1; terraform version | head -1; helm version --short
