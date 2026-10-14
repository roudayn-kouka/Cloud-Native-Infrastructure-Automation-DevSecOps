# Architecture

## Network layout

| Tier | Subnets | Contents |
|------|---------|----------|
| Public | 10.0.1.0/24, 10.0.2.0/24 | ALB, NAT gateway, bastion |
| Private | 10.0.11.0/24, 10.0.12.0/24 | EKS worker nodes and pods |
| Database | 10.0.21.0/24, 10.0.22.0/24 | RDS MySQL (no route to the internet) |

Security groups only reference each other (no wide CIDR rules except the public ALB and, optionally, SSH from approved IPs):
`internet → ALB(80/443) → nodes(8080) → RDS(3306)`, `bastion → cluster API(443)`, `bastion/nodes → RDS(3306)`.

## Terraform stacks and state

Each folder is an independent stack with its own state (`<project>/<env>/<stack>.tfstate`) in one S3 bucket.
Stacks exchange values through SSM Parameter Store under `/<project>/<env>/...`, so they can be applied and destroyed one by one.

```
00-bootstrap (local state, once) → S3 state bucket
00-vpc → 10-sg → 20-bastion → 30-db → 40-eks → 50-acm → 60-ingress-alb → 70-ecr
```

## Delivery pipeline

1. **Continuous integration (Jenkins)** — unit tests, SonarQube analysis and quality gate, Trivy filesystem scan (fixable HIGH/CRITICAL vulnerabilities and secrets block the build), image build, Trivy image scan, push to ECR.
2. **GitOps promotion** — Jenkins edits only `gitops/environments/dev/values.yaml` (`global.imageTag`) and pushes with `[skip ci]` so it does not retrigger itself.
3. **Continuous delivery (ArgoCD)** — the `root` application manages `expense` (Helm chart + env values) and `monitoring` (kube-prometheus-stack). Automated sync with prune and self-heal; manual changes in the cluster are reverted.

## Key design decisions

* **GitOps pull model** instead of `helm upgrade` from Jenkins: the CI system holds no cluster credentials, every deployment is a Git commit, rollback is `git revert`.
* **TargetGroupBinding + target-type `ip`**: Terraform owns the ALB, listeners and certificate; Kubernetes only registers pod IPs. This keeps the entry point (DNS, TLS, WAF later) in IaC.
* **nginx in front of the API**: single origin for the browser (no CORS, no API URL baked into the JS bundle), and the backend stays internal (`ClusterIP`, NetworkPolicy allows only the frontend and Prometheus).
* **Secrets Manager as the source of truth** for DB credentials; Kubernetes Secret is derived from it by `create-db-secret.sh` (External Secrets Operator is the planned next step).
* **Immutable image tags** with `<version>-<build>-<sha>` for traceability.
* **Spot nodes + single NAT gateway** by default to keep a lab affordable; both are variables (`node_capacity_type`, `single_nat_gateway`) to flip for production.

## Failure behaviour

| Failure | Behaviour |
|---------|-----------|
| Database unreachable | `/ready` → 503, pods leave the Service and the ALB target group; `ExpenseDatabaseUnreachable` fires after 2 min |
| Pod crash / node loss | Deployment replaces pods; PodDisruptionBudget keeps ≥ 1 replica during drains |
| CPU spike | HPA scales 2 → 10 backend pods at 70 % CPU (needs metrics-server) |
| Bad release | Rolling update with `maxUnavailable: 0` and readiness gating; revert the GitOps commit to roll back |
