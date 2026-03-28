---
name: phase-guide
description: >
  Project phase tracker and learning guide. Use when Ahmed asks "what should I do next?",
  "what phase am I on?", "guide me through phase X", or any question about project progress.
  Also use when starting a new Claude Code session to orient yourself.
allowed-tools: Read, Write, Bash, Grep, Glob
---

## Phase guide for devsecops-project

### How to determine current phase
Read the CLAUDE.md file at the project root. Find the "Project phases — learning roadmap" table.
The current phase is the first one with status 🔲 Pending.

### After completing a phase
Update CLAUDE.md: change the phase status from `🔲 Pending` to `✅ Complete`.
Also update the `Current phase` field in the Project Identity table.

### Phase completion criteria

**Phase 0 — Prerequisites ✅**
- All tools installed: az, terraform, kubectl, docker, helm, trivy, cosign, node, python3, git
- Azure subscription active, providers registered
- GitLab repo created with correct directory structure
- CLAUDE.md in repo root

**Phase 1 — Terraform**
- `terraform apply` succeeds
- AKS cluster has 1 Ready node: `kubectl get nodes`
- ACR is accessible: `az acr show --name acrdevsecops`
- Key Vault exists: `az keyvault show --name kv-devsecops-*`
- Azure budget alert set at $80
- All resources tagged with project/environment/managed-by

**Phase 2 — Application development**
- Backend: `docker build` succeeds, `curl localhost:8000/healthz` returns 200
- Frontend: `docker build` succeeds, accessible on localhost:3000
- Images scanned with Trivy: no Critical CVEs
- Both images run as non-root (verify with `docker run --rm <image> whoami`)
- Tests pass: `pytest app/backend/tests/`

**Phase 3 — CI pipeline + Slack**
- Push to GitLab triggers pipeline
- All 6 security gates pass
- Image appears in ACR tagged with commit SHA
- Image is signed (verify with `cosign verify`)
- Slack notification arrives in #ci-pipeline

**Phase 4 — GitOps (ArgoCD)**
- ArgoCD installed and accessible
- App syncs from k8s/ directory
- Change image tag → ArgoCD auto-syncs
- NGINX Ingress routes traffic to frontend and backend
- Slack notification arrives in #deployments on sync

**Phase 5 — Runtime security**
- Kyverno blocks: `kubectl run test --image=nginx:latest` → denied
- Kyverno blocks: privileged pod creation → denied
- Falco detects: `kubectl exec` into a pod → alert in Slack #alerts

**Phase 6 — Secrets management**
- DB password comes from Key Vault, not K8s Secret
- Slack webhooks come from Key Vault
- Pod restarts still work after removing K8s Secrets

**Phase 7 — Monitoring**
- Prometheus scrapes metrics from backend /metrics endpoint
- Grafana dashboard shows cluster health
- Stress test triggers Slack alert in #alerts

**Phase 8 — Hardening**
- Network policies: frontend cannot reach database directly
- Pod Security Standards: restricted profile applied
- RBAC: no cluster-admin bindings except system
- README.md is complete and portfolio-ready

### Teaching approach per phase
- Phase 1-2: Explain every concept. Ahmed is learning foundations.
- Phase 3-4: Explain less, ask more. "What do you think this error means?"
- Phase 5-8: Guide, don't hand-hold. "Try running X, then tell me what you see."
