---
name: debug-k8s
description: >
  Kubernetes debugging and troubleshooting. Use when pods are crashing, deployments are stuck,
  services are unreachable, or Ahmed asks "why isn't it working?" about anything cluster-related.
  Also use when interpreting kubectl output, events, or logs.
allowed-tools: Read, Bash, Grep
---

## Kubernetes debugging for devsecops-project

### Debugging decision tree — follow this order

```
Pod not running?
├── kubectl get pods -n devsecops-project
│   ├── STATUS: ImagePullBackOff → ACR auth issue or wrong image tag
│   ├── STATUS: CrashLoopBackOff → App crashes on startup (check logs)
│   ├── STATUS: Pending → No node resources (check requests/limits)
│   ├── STATUS: Init:Error → Init container failed
│   └── STATUS: Running but not ready → Readiness probe failing
│
├── kubectl describe pod <name> -n devsecops-project
│   └── Look at "Events" section at the bottom — this tells you WHAT happened
│
├── kubectl logs <name> -n devsecops-project
│   └── Look for Python tracebacks, connection errors, missing env vars
│
└── kubectl get events -n devsecops-project --sort-by='.lastTimestamp'
    └── Cluster-level view of what's happening
```

### Common issues and fixes

**ImagePullBackOff:**
```bash
# Check ACR attachment
az aks check-acr -g rg-devsecops -n aks-devsecops --acr acrdevsecops.azurecr.io
# If not attached, fix it:
az aks update -g rg-devsecops -n aks-devsecops --attach-acr acrdevsecops
```

**CrashLoopBackOff:**
```bash
# Get the crash logs (--previous shows the LAST crashed instance)
kubectl logs <pod> -n devsecops-project --previous
# Common causes: missing env var, DB not reachable, wrong port, permission denied
```

**Pending (no resources):**
```bash
# Check node capacity
kubectl describe node | grep -A 5 "Allocated resources"
# With 1 B2s node (2 vCPU, 4GB RAM), you have limited room
# Fix: reduce resource requests, or scale node pool (costs more $$)
```

**Service unreachable:**
```bash
# Is the service pointing to the right pods?
kubectl get endpoints <service> -n devsecops-project
# If ENDPOINTS is empty, the selector labels don't match the pod labels

# Test from inside the cluster:
kubectl run debug --rm -it --image=busybox -n devsecops-project -- wget -qO- http://backend:8000/healthz
```

**Ingress not routing:**
```bash
# Check ingress resource
kubectl get ingress -n devsecops-project
# Check NGINX Ingress Controller logs
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller | tail -20
# Check if LoadBalancer has external IP
kubectl get svc -n ingress-nginx
```

### Teaching approach
When Ahmed hits an error:
1. **Don't just give the fix.** Ask: "What does this error message tell you?" — help him read errors.
2. **Explain the debugging path.** "I started with `get pods` → saw CrashLoopBackOff → checked logs → found missing env var."
3. **Connect to concepts.** "This is why readiness probes matter — K8s was sending traffic before the DB was connected."

### Useful aliases (suggest Ahmed adds to .bashrc)
```bash
alias k='kubectl'
alias kgp='kubectl get pods -n devsecops-project'
alias kgd='kubectl get deploy -n devsecops-project'
alias kgs='kubectl get svc -n devsecops-project'
alias kge='kubectl get events -n devsecops-project --sort-by=.lastTimestamp'
alias klf='kubectl logs -f -n devsecops-project'
```
