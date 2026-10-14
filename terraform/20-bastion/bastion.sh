#!/bin/bash
# Bootstraps the bastion (Amazon Linux 2023): kubectl, helm, eksctl, MySQL client, jq, git.
# Runs once through EC2 user data, as root.
set -euxo pipefail
exec > >(tee /var/log/bastion-bootstrap.log) 2>&1

dnf install -y jq git mariadb1011-client-utils || dnf install -y jq git mariadb105

# kubectl - latest stable
KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x /usr/local/bin/kubectl

# Helm 3
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# eksctl (handy for debugging IAM / OIDC)
curl -fsSL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" | tar xz -C /usr/local/bin eksctl

# kubectx / kubens
git clone --depth 1 https://github.com/ahmetb/kubectx /opt/kubectx
ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx
ln -sf /opt/kubectx/kubens /usr/local/bin/kubens

echo "Bastion bootstrap complete"
