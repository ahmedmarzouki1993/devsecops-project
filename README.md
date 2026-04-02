# DevSecOps Portfolio Project

A production-grade DevSecOps platform built on Azure AKS demonstrating the full software delivery lifecycle with security integrated at every layer — from commit to runtime.

**Owner:** Ahmed Marzouki — Cloud Architecture & DevOps Engineer
**Stack:** Azure AKS · GitLab CI · ArgoCD · Kyverno · Falco · Prometheus · Grafana · Terraform

---

## Architecture

```
Developer ──push──▶ GitLab ──trigger──▶ GitLab CI (6 security gates)
                                              │
                              ┌───────────────▼──────────────┐
                              │        Security Gates         │
                              │  Gitleaks → Bandit → pip-audit│
                              │  Checkov → Trivy → Cosign     │
                              └───────────────┬──────────────┘
                                              │ signed image → ACR
                                              ▼
                                    ArgoCD (GitOps sync)
                                              │
                              ┌───────────────▼──────────────────┐
                              │      AKS Cluster (1× B2s)        │
                              │                                   │
                              │  NGINX Ingress (LoadBalancer)     │
                              │       /api/* → Backend            │
                              │       /*     → Frontend           │
                              │                                   │
                              │  ┌──────────┐  ┌──────────────┐  │
                              │  │ Frontend │  │   Backend    │  │
                              │  │ React+   │  │   FastAPI    │──┼──▶ PostgreSQL
                              │  │ nginx    │  │   Python     │  │    StatefulSet
                              │  └──────────┘  └──────────────┘  │
                              │                                   │
                              │  Kyverno (admission control)      │
                              │  Falco  (runtime detection) ──▶ Slack #alerts
                              │  Prometheus + Grafana       ──▶ Slack #alerts
                              │  NetworkPolicies (zero-trust)     │
                              └───────────────────────────────────┘
                                        ▲
                               Azure Key Vault (secrets via CSI)
                               Terraform (all infra as code)
```

---

## Security Layers

This project implements **defense in depth** — every layer adds an independent security control.

| Layer | Tool | What it blocks |
|-------|------|----------------|
| **Shift Left** | Gitleaks, Bandit, pip-audit | Secrets in code, SAST findings, CVE dependencies |
| **Image scanning** | Trivy | Critical/High CVEs in container images |
| **Image signing** | Cosign | Unsigned images cannot be deployed (Kyverno verifies) |
| **Admission control** | Kyverno | `latest` tags, privileged pods, missing resource limits |
| **Network isolation** | NetworkPolicies | Frontend→DB direct path blocked, zero-trust between tiers |
| **Pod hardening** | Pod Security Standards | Enforces baseline; audits against restricted profile |
| **Runtime detection** | Falco | Shell in container, unexpected file writes, privilege escalation |
| **Secrets** | Azure Key Vault + CSI | DB passwords never in Git, auto-mounted into pods as files |
| **Observability** | Prometheus + Grafana | CPU/memory thresholds alert to Slack before users notice |

---

## Project Phases

| Phase | Name | Status |
|-------|------|--------|
| 0 | Prerequisites & environment | ✅ Complete |
| 1 | Terraform (AKS, ACR, Key Vault) | ✅ Complete |
| 2 | Application development | ✅ Complete |
| 3 | CI pipeline + security gates | ✅ Complete |
| 4 | GitOps deployment (ArgoCD) | ✅ Complete |
| 5 | Runtime security (Kyverno + Falco) | ✅ Complete |
| 6 | Secrets management (Key Vault CSI) | ✅ Complete |
| 7 | Monitoring + alerting (Prometheus + Grafana) | ✅ Complete |
| 8 | Hardening (NetworkPolicies, PSS, RBAC) | ✅ Complete |

---

## Repository Structure

```
devsecops-project/
├── terraform/              # Phase 1 — AKS, ACR, Key Vault, budget alert
├── app/
│   ├── backend/            # Phase 2 — FastAPI (Python 3.12), pytest tests
│   └── frontend/           # Phase 2 — React + nginx (non-root, alpine)
├── k8s/
│   ├── base/               # Kustomize base — canonical manifests
│   │   ├── backend/        # Deployment + Service
│   │   ├── frontend/       # Deployment + Service + Ingress + nginx ConfigMap
│   │   ├── database/       # StatefulSet + PVC + Service
│   │   ├── netpol/         # Phase 8 — NetworkPolicies (zero-trust)
│   │   ├── namespace.yaml  # PSS labels (enforce: baseline, warn/audit: restricted)
│   │   ├── serviceaccount.yaml
│   │   ├── secret-provider.yaml  # CSI SecretProviderClass → Key Vault
│   │   └── rbac.yaml       # Least-privilege Role + RoleBinding
│   └── overlays/dev/       # Dev overlay — image tags from CI_COMMIT_SHORT_SHA
├── security/
│   ├── kyverno/            # Phase 5 — ClusterPolicies (enforce mode)
│   └── falco/              # Phase 5 — Falco + Falcosidekick → Slack
├── monitoring/             # Phase 7 — ServiceMonitor, Grafana dashboards
├── notifications/          # Phase 4 — ArgoCD notification templates → Slack
├── .gitlab-ci.yml          # Phase 3 — 6 security gates pipeline
├── scripts/
│   ├── audit-rbac.sh       # Phase 8 — RBAC cluster-admin audit
│   └── bootstrap-tf-state.sh
└── docs/
```

---

## CI Pipeline — 6 Security Gates

Every push to `main` triggers the pipeline. **All gates must pass before the image is pushed.**

```yaml
stages: [scan, build, sign, notify]
```

| Gate | Tool | Fail condition | Typical duration |
|------|------|----------------|-----------------|
| 1 | **Gitleaks** | Any secret in git history | ~5s |
| 2 | **Bandit** | High-severity Python finding | ~10s |
| 3 | **pip-audit** | Known CVE in dependencies | ~15s |
| 4 | **Checkov** | Critical Terraform/K8s misconfiguration | ~20s |
| 5 | **Trivy** | Critical or High CVE in image | ~60s |
| 6 | **Cosign** | Signing failure | ~10s |

**Why this order?** Fast checks first. Gitleaks (5s) before Trivy (60s). Fail fast = save CI minutes.

---

## Kyverno Policies

Three ClusterPolicies in **Enforce** mode (violations are rejected, not just warned):

| Policy | What it blocks |
|--------|----------------|
| `block-latest-tag` | Any image tagged `:latest` in the namespace |
| `block-privileged-pods` | `privileged: true`, `hostPID`, `hostNetwork`, `hostIPC` |
| `require-resource-limits` | Pods missing `resources.limits.cpu` or `resources.limits.memory` |

Test them:
```bash
# Should be denied — latest tag
kubectl run test --image=nginx:latest -n devsecops-project

# Should be denied — privileged
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: priv-test
  namespace: devsecops-project
spec:
  containers:
  - name: c
    image: nginx:1.27-alpine
    securityContext:
      privileged: true
EOF
```

---

## Network Policies — Zero Trust

The `devsecops-project` namespace uses a **default-deny-all** policy with explicit allow rules:

```
Internet → NGINX Ingress Controller
         → frontend:8080     ✅ allowed
         → backend:8000      ✅ allowed (via /api/*)

frontend  → backend          ✗ BLOCKED (browser calls go through Ingress, not pod-to-pod)
frontend  → database         ✗ BLOCKED
backend   → database:5432    ✅ allowed
backend   → DNS:53           ✅ allowed
Prometheus → backend:8000    ✅ allowed (metrics scraping)
```

Verify:
```bash
# This should FAIL (frontend cannot reach database)
kubectl exec -n devsecops-project deploy/frontend -- \
  nc -zv database 5432
```

---

## Falco Runtime Detection

Falco watches syscalls via eBPF and alerts on suspicious behavior:

| Rule | Trigger | Alert destination |
|------|---------|------------------|
| Terminal shell in container | `kubectl exec` → shell | Slack #alerts |
| Package management | `apt`, `yum` inside container | Slack #alerts |
| Write below /etc | Any write to system config dirs | Slack #alerts |

Test:
```bash
kubectl exec -n devsecops-project deploy/backend -- /bin/sh
# Falco detects this → Slack #alerts receives alert within seconds
```

---

## Secrets Management

Database credentials never appear in Git. The flow:

```
Azure Key Vault (kv-devsecops-*)
  └─ Secrets: db-password, db-user, db-name
       │
       ▼ CSI Secrets Store Driver (kubelet managed identity)
  SecretProviderClass (kv-secrets)
       │ syncs to
       ▼
  K8s Secret: db-credentials
       │ referenced by
       ▼
  PostgreSQL StatefulSet + Backend Deployment (env vars via secretKeyRef)
```

No `kubectl create secret` commands. No base64-encoded values in YAML. Key Vault is the single source of truth.

---

## Monitoring & Log Aggregation

### Metrics — Prometheus + Grafana
- **Prometheus** scrapes `/metrics` from the FastAPI backend every 15s via `ServiceMonitor` CRD
- **Grafana** dashboard ("FastAPI Observability") shows: request rate, p99 latency, error rate by handler, 5xx count
- Deployed via `kube-prometheus-stack` Helm chart

### Logs — Loki + Promtail
- **Promtail** DaemonSet automatically collects stdout/stderr from all pods and ships to Loki
- **Loki** stores and indexes logs — queryable in Grafana using LogQL
- Grafana log panel shows all `devsecops-project` namespace logs with live filtering via `$log_keyword` variable

### Slack Alert Routing
Alerts are routed to `#alerts` only when `severity ≥ warning` — noise from `info`/`debug` is discarded:

| Source | Severity filter | Channel |
|--------|----------------|---------|
| Grafana alert rules | `warning`, `error`, `critical` | `#alerts` |
| Falco (Falcosidekick) | `warning` and above | `#alerts` |
| ArgoCD sync | all sync events | `#deployments` |
| GitLab CI | pipeline pass/fail | `#ci-pipeline` |

Access Grafana:
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Open http://localhost:3000 — dashboard: "FastAPI Observability (K8s)"
```

---

## Infrastructure (Terraform)

All Azure resources are created with Terraform, tagged, and stored in remote state.

### Resources

| Resource | Name | SKU |
|----------|------|-----|
| Resource Group | `rg-devsecops` | — |
| AKS Cluster | `aks-devsecops` | 1× Standard_B2s |
| Container Registry | `acrdevsecops` | Basic |
| Key Vault | `kv-devsecops-<unique>` | Standard |
| TF State Storage | `stdevsecopsstate` | LRS |

### Security hardening (CIS Azure benchmark — Checkov)
- AKS: `automatic_channel_upgrade = patch`, Calico network policy, Secrets Store CSI auto-rotation, 50 max pods/node
- ACR: untagged manifest retention policy (7 days), admin credentials disabled
- Key Vault: purge protection enabled, network ACLs deny-all with AzureServices bypass
- 20 checks intentionally skipped with justification (Premium SKU requirements, student budget constraints)

```bash
cd terraform/
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

**Cost:** ~$36/month running, ~$6/month when AKS is stopped.
**Budget alert** set at $80 via Azure Cost Management.

```bash
# Always stop AKS when not actively using it
az aks stop -g rg-devsecops -n aks-devsecops
```

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| GitLab CI over GitHub Actions | Enterprise-relevant, built-in container registry backup |
| ArgoCD over Flux | Richer UI, easier RBAC, app-of-apps pattern |
| Kustomize over Helm for app manifests | Simpler GitOps, ArgoCD native, no templating complexity |
| Kubelet managed identity for CSI | Avoids workload identity complexity on Student Pack AKS |
| ACR over GitLab Registry | Managed identity pull auth — zero imagePullSecrets |
| PostgreSQL in-cluster (not managed) | Student Pack budget: managed PostgreSQL = $15-25/mo extra |
| enforce:baseline + warn:restricted | Practical PSS migration path — zero false positives while tracking the full gap |
| NetworkPolicy default-deny | Zero-trust networking: explicit allow > implicit allow |

---

## Quick Reference

```bash
# Azure
az aks get-credentials -g rg-devsecops -n aks-devsecops
az aks stop -g rg-devsecops -n aks-devsecops      # Save money
az aks start -g rg-devsecops -n aks-devsecops

# Application
kubectl get all -n devsecops-project
kubectl logs -n devsecops-project deploy/backend -f
kubectl port-forward -n devsecops-project svc/backend 8000:8000

# ArgoCD
argocd app sync devsecops-project
argocd app get devsecops-project

# Security audit
bash scripts/audit-rbac.sh
kubectl get clusterpolicies
falco --list | grep -i "shell"

# Monitoring
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

---

## Skills Demonstrated

- **Infrastructure as Code** — Terraform modules, remote state, tagging strategy, CIS benchmark hardening
- **Container security** — Multi-stage builds, non-root, Trivy scanning, Cosign image signing
- **CI/CD pipeline design** — GitLab CI with 6 ordered security gates, fail-fast strategy
- **GitOps** — ArgoCD self-healing sync, Kustomize overlay pattern, Slack deployment notifications
- **Admission control** — Kyverno ClusterPolicies in enforce mode, policy testing
- **Runtime security** — Falco eBPF syscall monitoring, Falcosidekick alert routing
- **Secrets management** — Azure Key Vault + CSI Secrets Store, zero secrets in Git
- **Network hardening** — Kubernetes NetworkPolicies, zero-trust default-deny architecture
- **Observability** — Prometheus + Loki + Grafana stack, custom dashboard, severity-based Slack routing
- **Cost management** — Azure Student Pack constraints, budget alerts, AKS stop/start habit
- **Compliance** — Checkov Terraform scanning, 16 CIS checks passing, 20 skipped with documented justification
