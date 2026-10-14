# Jenkins setup

Two EC2 instances are enough for a lab:

| Role | Size | Script |
|------|------|--------|
| Jenkins controller | t3.large, 30 GB | `jenkins-server-setup.sh` |
| Build agent (label `AGENT-1`) | t3.medium, 50 GB | `jenkins-agent-setup.sh` |

SonarQube (port 9000) and, optionally, Nexus (port 8081) can run on their own small instances or as
containers (`docker run -d -p 9000:9000 sonarqube:lts-community`).

## Controller
1. Run `sudo bash jenkins-server-setup.sh`, open `http://<ip>:8080` and unlock with
   `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`.
2. Install the plugins listed in `plugins.txt` (Manage Jenkins -> Plugins).
3. *Manage Jenkins -> Tools*: add a **SonarQube Scanner** installation named `sonar-scanner`.
4. *Manage Jenkins -> System*: add a **SonarQube server** named `sonarqube` (URL + token credential),
   and in SonarQube create a webhook to `http://<jenkins>:8080/sonarqube-webhook/` so `waitForQualityGate` returns.
5. *Credentials*: `github-pat` (Username + token with `repo` scope). Add `nexus-auth` only if you use Nexus.
6. Create a **Multibranch Pipeline** pointing at the GitHub repo (script path `Jenkinsfile`) and enable the
   GitHub webhook `http://<jenkins>:8080/github-webhook/`.

## Agent
1. Run `sudo bash jenkins-agent-setup.sh` (installs Docker, Node 22, AWS CLI, kubectl, Helm, Trivy, Terraform).
2. Add it as a node with label `AGENT-1` (SSH or inbound agent).
3. Attach an **instance profile** using `agent-iam-policy.json` (ECR push + read-only EKS/STS). No AWS keys are stored in Jenkins.

## How the pipeline deploys
Jenkins never talks to the cluster. On `main` it pushes images to ECR and commits the new tag to
`gitops/environments/dev/values.yaml` (`[skip ci]`); ArgoCD detects the commit and syncs the cluster.
