---
name: deploy
description: >
  GitOps deployment workflows with ArgoCD. Use when deploying to AKS, debugging deployment issues,
  working with Kustomize overlays, configuring NGINX Ingress, or managing ArgoCD applications.
  Auto-invoke when editing files in k8s/ directory or discussing deployment strategies.
allowed-tools: Read, Write, Bash, Grep, Glob
---

## Deployment workflow for devsecops-project

### GitOps principle — always enforce this
- **Git is the single source of truth.** What's in `k8s/` = what's in the cluster.
- **Never run `kubectl apply` directly.** All changes go through Git → ArgoCD auto-syncs.
- **Exception:** Initial cluster setup (installing ArgoCD, Ingress, Kyverno, Falco via Helm).

### Deployment flow
```
Developer pushes code → GitLab CI → builds image → pushes to ACR (tagged $CI_COMMIT_SHORT_SHA)
→ CI updates image tag in k8s/overlays/dev/ → pushes manifest change
→ ArgoCD detects diff → syncs to AKS → pods roll out
→ ArgoCD notifies Slack #deployments
```

### Kustomize structure
```
k8s/
├── base/                    # Common resources (shared across environments)
│   ├── kustomization.yaml   # Lists all base resources
│   ├── namespace.yaml
│   ├── frontend/            # Deployment, Service, Ingress
│   ├── backend/             # Deployment, Service
│   └── database/            # StatefulSet, Service (headless), PVC
└── overlays/
    └── dev/                 # Dev-specific patches
        ├── kustomization.yaml
        └── patches/         # Image tags, replica counts, env vars
```

### Every K8s manifest must include (Kyverno enforces this)
```yaml
metadata:
  labels:
    app.kubernetes.io/name: <component>      # frontend, backend, database
    app.kubernetes.io/part-of: devsecops-project
    app.kubernetes.io/version: <commit-sha>
spec:
  containers:
    - name: <name>
      image: acrdevsecops.azurecr.io/<image>:<commit-sha>  # Never :latest
      imagePullPolicy: IfNotPresent
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 250m
          memory: 256Mi
      securityContext:
        runAsNonRoot: true
        readOnlyRootFilesystem: true
        allowPrivilegeEscalation: false
      livenessProbe:
        httpGet:
          path: /healthz
          port: 8000
        initialDelaySeconds: 10
        periodSeconds: 15
      readinessProbe:
        httpGet:
          path: /readyz
          port: 8000
        initialDelaySeconds: 5
        periodSeconds: 10
```

### ArgoCD commands
```bash
argocd app list                              # List all apps
argocd app get devsecops-project             # Detailed status
argocd app sync devsecops-project            # Force sync
argocd app diff devsecops-project            # Preview what will change
argocd app history devsecops-project         # Deployment history
```

### ArgoCD → Slack notifications
- Trigger events: `on-sync-succeeded`, `on-sync-failed`, `on-health-degraded`
- Channel: `#deployments`
- Webhook stored in: Azure Key Vault → `slack-webhook-deployments`

### Debugging failed deployments
1. `kubectl get events -n devsecops-project --sort-by='.lastTimestamp'` — what happened?
2. `kubectl describe pod <pod-name> -n devsecops-project` — why is it stuck?
3. `kubectl logs <pod-name> -n devsecops-project` — app-level errors?
4. `argocd app get devsecops-project` — is ArgoCD in sync or degraded?
5. Check Slack `#deployments` — did ArgoCD report the failure?

### Teaching points
- **Why GitOps over kubectl apply?** Audit trail, rollback via git revert, drift detection.
- **Why Kustomize over Helm?** Simpler for app manifests, ArgoCD handles natively. Helm for third-party only.
- **Why readiness vs liveness probes?** Liveness = restart if dead. Readiness = stop sending traffic if not ready.
  A pod can be alive but not ready (e.g., waiting for DB connection).
