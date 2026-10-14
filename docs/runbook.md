# Runbook

## Access
| What | How |
|------|-----|
| Bastion shell | `aws ssm start-session --target $(terraform -chdir=terraform/20-bastion output -raw bastion_instance_id)` |
| kubectl | `aws eks update-kubeconfig --region us-east-1 --name expense-dev` (on the bastion) |
| ArgoCD UI | `kubectl -n argocd port-forward svc/argocd-server 8081:443` → https://localhost:8081, user `admin`, password from `argocd-initial-admin-secret` |
| Grafana | `kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80` (secret `grafana-admin`) |
| Prometheus | `kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090` |
| Database shell | on the bastion: `eval "$(aws secretsmanager get-secret-value --secret-id expense/dev/db --query SecretString --output text | jq -r '"MYSQL_PWD=\(.admin_password) HOST=\(.host)"')"; mysql -h $HOST -u admin transactions` |

## Everyday operations
* **Deploy**: merge to `main`; watch the Jenkins build, then the `expense` application in ArgoCD.
* **Roll back**: `git revert <promotion commit>` on `gitops/environments/dev/values.yaml` and push. ArgoCD redeploys the previous tag.
* **Scale manually**: change `backend.hpa.*` in values (HPA owns the replica count; do not use `kubectl scale`).
* **Rotate DB passwords**: `terraform apply -replace=random_password.app -replace=random_password.admin` in `30-db`, then `scripts/init-db.sh` and `scripts/create-db-secret.sh` on the bastion, then `kubectl -n expense rollout restart deploy/backend`.

## Troubleshooting
| Symptom | Check |
|---------|-------|
| Backend pods `0/1 Running` | `kubectl -n expense logs deploy/backend` — "database not ready yet" means credentials/host/security group; confirm `backend-db` secret and `config.dbHost` |
| ALB returns 503 / 404 | `kubectl -n expense get targetgroupbinding`, target health in the EC2 console, host header must be `expense-dev.<zone>` |
| TargetGroupBinding not created | Is the AWS Load Balancer Controller running (`kubectl -n kube-system get deploy aws-load-balancer-controller`)? Correct `targetGroupARN`? |
| HPA shows `<unknown>` | metrics-server not installed/ready |
| ArgoCD `OutOfSync` on CRDs | Application uses `ServerSideApply=true`; make sure the option is present |
| Prometheus has no app metrics | `kubectl -n expense get servicemonitor`; Prometheus must select all namespaces (see `monitoring/kube-prometheus-stack-values.yaml`) |
| Jenkins `waitForQualityGate` hangs | SonarQube webhook to `/sonarqube-webhook/` missing |
| ECR push fails "tag invalid: immutable" | Same tag pushed twice — tags include the build number, so check for a re-run of the same build |

## Disaster recovery
* RDS: automated backups (7 days). Restore to a new instance, update `config.dbHost`.
* Cluster is fully reproducible from Terraform + Git; the only manual secrets are the Jenkins credentials.
