# CLAUDE.md — devsecops-project

> **What is this file?** This is the brain of the project. When Ahmed uses Claude Code in VS Code,
> Claude reads this file first to understand the project context, the current phase, and what to do next.
> It is also a structured learning guide: every section explains not just WHAT to do, but WHY — like a
> senior DevOps engineer mentoring a junior on a real production project.
>
> **How to use with Claude Code:**
> - Open this project in VS Code
> - Use Claude Code (terminal or sidebar) to ask questions like:
>   - "What phase am I on and what do I do next?"
>   - "Write the Terraform files for Phase 1"
>   - "Explain why we use multi-stage Docker builds"
>   - "Help me debug this pipeline failure"
> - Claude Code will read this file automatically and give you answers scoped to YOUR project.
> - After completing each phase, ask Claude Code to update the phase status below.

---

## How Claude Code should behave with this project

When Ahmed asks for help:

1. **Check the current phase** in the status table below. Don't jump ahead.
2. **Teach, don't just give answers.** Explain the WHY before the HOW. Ahmed is building production
   skills, not copying commands.
3. **Always consider Azure Student Pack constraints** ($100 credit, 1 node, budget limits).
4. **Follow the coding conventions** defined in this file. Don't generate code that violates them.
5. **Security first.** Never generate code with hardcoded secrets, privileged containers, or `latest` tags.
6. **After each task**, suggest a validation step so Ahmed can verify it works.
7. **Use the key commands reference** at the bottom — don't invent different resource names.
8. **When writing Terraform/K8s/CI configs**, always add inline comments explaining what each block does
   and why it exists. Ahmed is learning — comments are not optional.
9. **Use your skills.** You have project-specific skills in `.claude/skills/` — use them when relevant.
10. **Use MCP servers** when available — query Kubernetes directly, look up live docs via Context7,
    break down complex tasks with Sequential Thinking.

---

## Claude Code setup — MCP servers and skills

> **For Ahmed:** Run this setup ONCE after cloning the repo and installing Claude Code.
> MCP servers give Claude Code superpowers — direct access to your cluster, GitLab, and live documentation.

### MCP servers (Model Context Protocol)

**What are MCP servers?** Think of them as plugins for Claude Code. Instead of you running
`kubectl get pods` and pasting the output, Claude Code runs it directly through the Kubernetes MCP.
Instead of Claude relying on potentially outdated training data, Context7 fetches the CURRENT
documentation for Terraform, ArgoCD, FastAPI, etc.

**Setup:** Run the setup script once:
```bash
chmod +x scripts/setup-mcp.sh
./scripts/setup-mcp.sh
```

Or add them manually:
```bash
# Sequential Thinking — helps Claude plan multi-step tasks
claude mcp add sequential-thinking --scope local -- npx -y mcp-sequentialthinking-tools

# Kubernetes — direct kubectl access via your kubeconfig
claude mcp add kubernetes --scope local -- npx -y @modelcontextprotocol/server-kubernetes

# GitLab — interact with repo, pipelines, MRs (requires PAT)
export GITLAB_TOKEN=glpat-xxxxx
claude mcp add gitlab --scope local -e GITLAB_TOKEN=$GITLAB_TOKEN -- npx -y @modelcontextprotocol/server-gitlab

# Context7 — live documentation lookup (Terraform, K8s, FastAPI, ArgoCD)
claude mcp add context7 --scope local -- npx -y @upstash/context7-mcp@latest
```

**Verify:** Inside Claude Code, type `/mcp` to see connected servers.

| MCP server          | What it gives Claude Code                                          | When it helps                              |
| ------------------- | ------------------------------------------------------------------ | ------------------------------------------ |
| Sequential Thinking | Step-by-step reasoning for complex tasks                           | Debugging CI failures, planning Terraform  |
| Kubernetes          | Direct kubectl — pods, logs, events, deployments                   | Debugging AKS, checking deployment status  |
| GitLab              | Repo access, pipeline status, MRs, issues                         | Checking pipeline results, creating MRs    |
| Context7            | Live docs for Terraform, K8s, FastAPI, ArgoCD, etc.                | Getting current API syntax, not outdated   |

### Custom skills (auto-invoked by Claude Code)

**What are skills?** Reusable instruction sets in `.claude/skills/`. Claude Code loads them
automatically when your task matches the skill description. You can also invoke them manually
with `/skill-name`.

| Skill              | Invoke with        | Auto-triggers when                                           |
| ------------------ | ------------------ | ------------------------------------------------------------ |
| `/terraform`       | `/terraform`       | Editing files in `terraform/`, asking about IaC              |
| `/security-scan`   | `/security-scan`   | Editing Dockerfile, .gitlab-ci.yml, fixing CVEs              |
| `/deploy`          | `/deploy`          | Working with k8s/ manifests, ArgoCD, Ingress                 |
| `/debug-k8s`       | `/debug-k8s`       | Pods crashing, services unreachable, "why isn't it working?" |
| `/phase-guide`     | `/phase-guide`     | "What's next?", "what phase am I on?", starting a session    |

**Each skill contains:**
- Context specific to this project (resource names, conventions)
- Decision trees for common problems
- Teaching points Claude should mention when relevant
- Exact commands to run (no guessing)

### Project-shared MCP config (`.mcp.json`)

The `.mcp.json` at the project root defines MCP servers that are automatically available when
anyone opens this project in Claude Code with `--scope project`. It's committed to Git so every
collaborator gets the same setup.

---

## Project identity

| Field              | Value                                                     |
| ------------------ | --------------------------------------------------------- |
| **Name**           | devsecops-project                                         |
| **Type**           | Production-grade DevSecOps platform (portfolio project)   |
| **Owner**          | Ahmed Marzouki — Cloud Architecture & DevOps Engineer     |
| **Repository**     | GitLab (private) — `gitlab.com/<USERNAME>/devsecops-project` |
| **Cloud**          | Microsoft Azure (Student Pack — $100 credit limit)        |
| **Current phase**  | Phase 5 — Runtime security                               |

---

## Architecture overview

```
                         ┌─────────────────────────────────────┐
                         │           NOTIFICATION LAYER         │
                         │           Slack Workspace            │
                         │  #ci-pipeline  #deployments  #alerts │
                         └──────▲──────────▲──────────▲────────┘
                                │          │          │
Developer ──push──▶ GitLab ──trigger──▶ GitLab CI (6 security gates)
                                              │
                                              │ on success: push signed image
                                              ▼
                                         Azure ACR ◄── Cosign (signed)
                                              │
                                              │ image tag updated in k8s/ manifests
                                              ▼
                                         ArgoCD (GitOps) ──notify──▶ Slack
                                              │
                                              ▼
                              ┌───────────────────────────────────┐
                              │      AKS Cluster (1× B2s node)   │
                              │                                   │
                              │   ┌─────────────────────────┐     │
                              │   │    NGINX Ingress         │     │
                              │   │    (LoadBalancer)        │     │
                              │   └────┬────────┬────────┘   │     │
                              │        │        │            │     │
                              │        ▼        ▼            │     │
                              │   ┌────────┐ ┌─────────┐    │     │
                              │   │Frontend│ │ Backend  │    │     │
                              │   │React + │ │ FastAPI  │────┼──▶ PostgreSQL
                              │   │ Nginx  │ │ Python   │    │   (StatefulSet)
                              │   └────────┘ └─────────┘    │     │
                              │                              │     │
                              │   Kyverno (policy enforce)   │     │
                              │   Falco (runtime detect) ──notify──▶ Slack
                              │                              │     │
                              │   Prometheus ──▶ Grafana ──notify──▶ Slack
                              └──────────────────────────────┘
                                        ▲
                                   Azure Key Vault (secrets via CSI)
                                   Terraform (all infra as code)
```

### Why this architecture?

Every layer exists for a reason that maps to a real-world production concern:

- **GitLab CI security gates** = "Shift left." Find vulnerabilities BEFORE production. Production fix costs 100× more.
- **ArgoCD (GitOps)** = "Git is the single source of truth." Nobody runs `kubectl apply` manually. Every change is auditable.
- **Kyverno** = "Admission control." A bouncer at the door — no privileged containers, no unsigned images, no missing labels.
- **Falco** = "Runtime detection." Catches bad behavior AFTER deployment — shell in container = possible breach.
- **Slack notifications** = "Observability for humans." Never watch a terminal. Notifications flow to you.
- **Key Vault** = "Secrets never in code." Key Vault + CSI driver mounts secrets directly into pods as files.

---

## 3-tier application

| Tier     | Tech              | Container base                          | K8s resource                           |
| -------- | ----------------- | --------------------------------------- | -------------------------------------- |
| Frontend | React + Nginx     | `node:20-alpine` → `nginx:1.27-alpine` | Deployment + Service + Ingress         |
| Backend  | FastAPI (Python)  | `python:3.12-slim` (multi-stage)        | Deployment + Service                   |
| Database | PostgreSQL 16     | `postgres:16-alpine`                    | StatefulSet + PVC + Service (headless) |

**Why these base images?**
- `alpine` = ~5MB vs ~100MB. Smaller image = smaller attack surface = faster pulls.
- `python:3.12-slim` not alpine — alpine uses `musl` libc which breaks some Python packages.
- `postgres:16-alpine` is fine — PostgreSQL has no libc-sensitive Python dependencies.

---

## Tech stack (locked)

### Core infrastructure

| Layer              | Tool                          | Why                                                          |
| ------------------ | ----------------------------- | ------------------------------------------------------------ |
| Source control     | GitLab                        | Built-in CI/CD, container registry backup, enterprise-standard |
| CI pipeline        | GitLab CI                     | Native to GitLab, `.gitlab-ci.yml` in repo, 400 min/mo free |
| CD / GitOps        | ArgoCD                        | Industry standard K8s GitOps, auto-syncs from Git            |
| Container registry | Azure ACR (Basic)             | Managed identity auth with AKS — no imagePullSecrets         |
| IaC                | Terraform                     | Cloud-agnostic, declarative, state management                |
| Orchestration      | AKS (1× Standard_B2s)        | Managed K8s, free control plane, cheapest viable node        |
| Ingress            | NGINX Ingress Controller      | Most mature K8s ingress, wide community                      |
| Secrets            | Azure Key Vault + CSI driver  | Secrets never in YAML, auto-rotation, audit logging          |

### Security gates (CI pipeline — executed in order)

> **Why this order?** Fast checks first. Gitleaks (3s) before Trivy (60s). "Fail fast" saves CI minutes.

| Gate | Tool      | What it does                             | Fails on                  | Duration |
| ---- | --------- | ---------------------------------------- | ------------------------- | -------- |
| 1    | Gitleaks  | Scans git history for hardcoded secrets  | Any detected secret       | ~5s      |
| 2    | Bandit    | Python static analysis (SAST)            | High-severity findings    | ~10s     |
| 3    | pip-audit | Python dependency CVE check              | Known vulnerabilities     | ~15s     |
| 4    | Checkov   | Terraform/K8s misconfiguration scanner   | High/critical misconfigs  | ~20s     |
| 5    | Trivy     | Container image vulnerability scan       | Critical/High CVEs        | ~60s     |
| 6    | Cosign    | Cryptographically signs the built image  | Signing failure           | ~10s     |

### Runtime security

| Tool    | Role                  | Why                                                                |
| ------- | --------------------- | ------------------------------------------------------------------ |
| Kyverno | Policy enforcement    | Blocks bad deployments BEFORE they run — firewall for YAML         |
| Falco   | Runtime detection     | Detects suspicious behavior AFTER deployment — shell, file tampering |

### Notifications (Slack)

| Source                        | Channel          | Notifies on                                  |
| ----------------------------- | ---------------- | -------------------------------------------- |
| GitLab CI pipeline            | `#ci-pipeline`   | Pipeline success/failure, gate results       |
| ArgoCD                        | `#deployments`   | Sync success/failure, health changes         |
| Falco (via Falcosidekick)     | `#alerts`        | Runtime threats (shell in container, etc.)    |
| Grafana                       | `#alerts`        | CPU/memory thresholds, pod crashes           |

**Webhook URLs are secrets.** Store in GitLab CI Variables (masked) and Azure Key Vault. Never hardcode.

### Monitoring

| Tool       | Role                    |
| ---------- | ----------------------- |
| Prometheus | Metrics collection      |
| Grafana    | Dashboards + Slack alerts |

---

## Azure Student Pack constraints

| Constraint              | Impact                              | Workaround                                    |
| ----------------------- | ----------------------------------- | --------------------------------------------- |
| $100 total credit       | Must minimize costs                 | 1 node AKS, ACR Basic, stop cluster when idle |
| GitLab CI 400 min/mo    | ~33-50 pipeline runs/month          | Register self-hosted runner (free, unlimited)  |
| No budget alerts default| Could burn credit silently          | Set Azure budget alert at $80                  |

### Monthly cost: ~$36 running, ~$6 if you stop AKS when idle.

> **CRITICAL HABIT:** `az aks stop -g rg-devsecops -n aks-devsecops` every time you're done.

---

## Project phases — learning roadmap

| Phase | Name                           | What you'll learn                                          | Status       |
| ----- | ------------------------------ | ---------------------------------------------------------- | ------------ |
| 0     | Prerequisites & environment    | Tool installation, Azure setup, repo structure             | ✅ Complete   |
| 1     | Terraform (AKS, ACR, KV)      | Infrastructure as Code, state management, Azure networking | ✅ Complete   |
| 2     | Application development        | FastAPI, React basics, Docker multi-stage builds, security | ✅ Complete   |
| 3     | CI pipeline + security gates   | GitLab CI, SAST, SCA, container scanning, Slack notify     | ✅ Complete   |
| 4     | GitOps deployment (ArgoCD)     | GitOps principles, Kustomize, NGINX Ingress, Slack notify  | ✅ Complete   |
| 5     | Runtime security               | Kyverno admission, Falco detection, Slack alerts           | 🔲 Pending   |
| 6     | Secrets management             | Key Vault, CSI Secrets Store, workload identity            | 🔲 Pending   |
| 7     | Monitoring + alerting          | Prometheus, Grafana, dashboards, Slack alerts              | 🔲 Pending   |
| 8     | Hardening & documentation      | Network policies, Pod Security, RBAC, README               | 🔲 Pending   |

> **Claude Code:** Use the `/phase-guide` skill to check completion criteria for each phase.

### Phase teaching approach
- Phase 1-2: Explain every concept. Ahmed is learning foundations.
- Phase 3-4: Explain less, ask more. "What do you think this error means?"
- Phase 5-8: Guide, don't hand-hold. "Try running X, then tell me what you see."

### Phase details — key teaching concepts per phase

**Phase 1 — Terraform:** Why remote state (shared, locked). Why `plan` before `apply` (review changes). Why managed identity (zero passwords). Why tags (cost tracking, ownership).

**Phase 2 — App development:** 12-factor apps (config from env vars). Why multi-stage builds (smaller, safer). Why non-root (container escape → root on host). Why health endpoints (K8s needs them).

**Phase 3 — CI + Slack:** Shift left (fix in CI, not prod). Why scan order (fail fast). How Cosign signing works (crypto proof of build). Webhook URLs are secrets.

**Phase 4 — GitOps:** Git = truth. Pull-based deployment. Drift detection. Why Kustomize over Helm for apps.

**Phase 5 — Runtime security:** Admission control (Kyverno blocks bad YAML). eBPF-based detection (Falco sees syscalls). Falcosidekick routes to Slack.

**Phase 6 — Secrets:** K8s Secrets aren't secret (base64 ≠ encryption). CSI driver mounts from Key Vault. Workload identity (pods auth without passwords).

**Phase 7 — Monitoring:** Three pillars (metrics, logs, traces). Prometheus pull model. PromQL basics. Grafana alert rules → Slack.

**Phase 8 — Hardening:** Network policies (who talks to whom). Pod Security Standards (restricted). RBAC (least privilege, no cluster-admin).

---

## Repository structure

```
devsecops-project/
├── .claude/                        # Claude Code configuration
│   └── skills/                     # Custom skills (auto-invoked)
│       ├── terraform/SKILL.md      # IaC workflow + teaching points
│       ├── security-scan/SKILL.md  # Security gates + Dockerfile checks
│       ├── deploy/SKILL.md         # GitOps + ArgoCD + Kustomize
│       ├── debug-k8s/SKILL.md      # K8s troubleshooting decision tree
│       └── phase-guide/SKILL.md    # Phase tracker + completion criteria
├── .mcp.json                       # Project-shared MCP server config
├── scripts/
│   └── setup-mcp.sh               # One-time MCP server setup script
├── terraform/                      # Phase 1 — Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── terraform.tfvars            # GITIGNORED — never commit
├── app/
│   ├── backend/                    # Phase 2 — FastAPI
│   │   ├── app/
│   │   │   ├── __init__.py
│   │   │   ├── main.py
│   │   │   ├── config.py
│   │   │   ├── models.py
│   │   │   ├── database.py
│   │   │   └── routers/
│   │   │       ├── health.py       # /healthz + /readyz
│   │   │       └── items.py        # CRUD demo
│   │   ├── tests/
│   │   ├── requirements.txt
│   │   ├── Dockerfile
│   │   └── .dockerignore
│   └── frontend/                   # Phase 2 — React
│       ├── src/
│       ├── public/
│       ├── package.json
│       ├── Dockerfile
│       ├── .dockerignore
│       └── nginx.conf
├── k8s/                            # Phase 4 — GitOps manifests
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── frontend/
│   │   ├── backend/
│   │   └── database/
│   └── overlays/dev/
├── security/                       # Phase 5 — Runtime policies
│   ├── kyverno/
│   └── falco/
├── monitoring/                     # Phase 7 — Observability
├── notifications/                  # Slack configs
│   ├── argocd-notifications-cm.yaml
│   └── README.md
├── .gitlab-ci.yml                  # Phase 3 — CI pipeline
├── .gitignore
├── CLAUDE.md                       # ← You are here
└── README.md
```

---

## Coding conventions

### Python (backend)
- Python 3.12, FastAPI, pydantic-settings, sqlalchemy 2.0+, alembic
- Type hints everywhere, docstrings on public functions
- Format: `black`, lint: `ruff`, test: `pytest` (80%+ coverage)
- **Never hardcode anything** — env vars or Key Vault

### Dockerfiles
- Multi-stage builds, specific version tags (never `latest`)
- Non-root user (UID 1001), no build tools in final stage
- `.dockerignore`, dependency-first COPY for layer caching

### Kubernetes manifests
- Kustomize base + overlays, `devsecops-project` namespace
- Every pod: resource limits, probes, securityContext (runAsNonRoot, readOnlyRootFilesystem)
- Labels: `app.kubernetes.io/name`, `part-of: devsecops-project`, `version`
- Image tag: `$CI_COMMIT_SHORT_SHA`, `imagePullPolicy: IfNotPresent`

### Terraform
- Provider version pinned, remote state in Azure Storage
- All resources tagged: project, environment, managed-by
- Variables with description, type, validation
- ALWAYS `plan -out=tfplan` then `apply tfplan`

### GitLab CI
- Stages: scan → build → sign → notify
- Secrets: GitLab CI/CD Variables (masked + protected), never in YAML
- Required variables: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `ACR_LOGIN_SERVER`, `SLACK_WEBHOOK_CI`

### Git
- Branch protection on `main`, MR required
- Conventional commits: `feat:`, `fix:`, `chore:`, `docs:`, `security:`, `infra:`

---

## Slack setup guide (do in Phase 3)

1. Create Slack workspace → 3 channels: `#ci-pipeline`, `#deployments`, `#alerts`
2. Create Slack App → Incoming Webhooks → generate URL per channel
3. Store webhooks:
   - `#ci-pipeline` → GitLab CI Variable `SLACK_WEBHOOK_CI` (masked)
   - `#deployments` → Key Vault `slack-webhook-deployments`
   - `#alerts` → Key Vault `slack-webhook-alerts`
4. Test: `curl -X POST -H 'Content-type: application/json' --data '{"text":"test"}' "$SLACK_WEBHOOK_CI"`

---

## Key commands reference

```bash
# AZURE
az login
az aks get-credentials -g rg-devsecops -n aks-devsecops
az aks stop -g rg-devsecops -n aks-devsecops                    # STOP (save $$$)
az aks start -g rg-devsecops -n aks-devsecops
az acr login --name acrdevsecops

# TERRAFORM
cd terraform/ && terraform init && terraform plan -out=tfplan && terraform apply tfplan

# DOCKER
docker build -t devsecops-backend:dev ./app/backend/
docker build -t devsecops-frontend:dev ./app/frontend/

# SECURITY
gitleaks detect --source .
bandit -r app/backend/app/
pip-audit -r app/backend/requirements.txt
checkov -d terraform/
trivy image devsecops-backend:dev

# KUBERNETES
kubectl get all -n devsecops-project
kubectl logs -n devsecops-project deploy/backend -f
kubectl port-forward -n devsecops-project svc/backend 8000:8000

# ARGOCD
argocd app sync devsecops-project
argocd app get devsecops-project
```

---

## Resource naming

| Resource           | Name                   |
| ------------------ | ---------------------- |
| Resource Group     | `rg-devsecops`         |
| AKS Cluster        | `aks-devsecops`        |
| ACR                | `acrdevsecops`         |
| Key Vault          | `kv-devsecops-<unique>`|
| TF State Storage   | `stdevsecopsstate`     |
| K8s Namespace      | `devsecops-project`    |
| Image tags         | `$CI_COMMIT_SHORT_SHA` |

---

## Security principles

1. **Shift left** — Fix in CI, not production
2. **Defense in depth** — CI gates + Kyverno + Falco + Network Policies
3. **Least privilege** — Non-root, RBAC scoped, read-only filesystems
4. **Secrets never in code** — Key Vault → CSI → pod mount
5. **Signed images only** — Cosign signs, Kyverno verifies
6. **Immutable infrastructure** — No SSH, no kubectl exec in prod, all through Git
7. **Alert on everything** — Silence = blind spots

---

## Trade-offs (interview-ready)

| Decision                              | Rationale                                                 |
| ------------------------------------- | --------------------------------------------------------- |
| PostgreSQL in-cluster, not managed    | Budget: managed = $15-25/mo. Trade-off: we handle backups |
| Single AKS node (no HA)              | Budget. Trade-off: node failure = downtime                |
| ACR over GitLab Registry             | Managed identity auth — zero secrets for pulls            |
| GitLab CI over GitHub Actions         | Enterprise-relevant, built-in CI                          |
| Kustomize over Helm for app manifests | Simpler for GitOps, ArgoCD native                         |
| Slack over PagerDuty                  | Free, easy webhooks, good for portfolio                   |

---

## Reminders

- **Stop AKS when idle:** `az aks stop -g rg-devsecops -n aks-devsecops`
- **Budget alert at $80** — set up in Phase 1
- **GitLab CI:** 400 min/mo → self-hosted runner as backup
- **Never commit:** `.tfvars`, `.env`, `*.pem`, `*.key`, kubeconfig, webhooks
- **Image tags:** `$CI_COMMIT_SHORT_SHA`, never `latest`
- **Read errors fully** — 80% of the answer is in the error message
