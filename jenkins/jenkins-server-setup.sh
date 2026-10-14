#!/bin/bash
# Installs Jenkins LTS on Amazon Linux 2023 / RHEL-compatible hosts.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run as root (sudo)." >&2; exit 1; }

dnf install -y java-21-amazon-corretto-headless git fontconfig
curl -fsSL https://pkg.jenkins.io/redhat-stable/jenkins.repo -o /etc/yum.repos.d/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
dnf install -y jenkins
systemctl enable --now jenkins

echo "Jenkins is starting on port 8080."
echo "Initial admin password:"
cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "(not generated yet - retry in a minute)"
