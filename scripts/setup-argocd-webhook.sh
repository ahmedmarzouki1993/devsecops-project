#!/usr/bin/env bash
# =============================================================================
# setup-argocd-webhook.sh — Configure GitLab → ArgoCD instant sync webhook
#
# WHAT THIS DOES:
#   By default ArgoCD polls GitLab every 3 minutes for changes.
#   A webhook makes sync INSTANT — GitLab calls ArgoCD the moment you push.
#
# HOW IT WORKS:
#   1. Generate a random shared secret
#   2. Patch argocd-secret (K8s Secret) so ArgoCD validates incoming webhooks
#   3. Print the webhook URL + secret for you to add in GitLab
#
# PREREQUISITES:
#   - kubectl connected to AKS: az aks get-credentials -g rg-devsecops -n aks-devsecops
#   - ArgoCD running in argocd namespace
#   - ArgoCD server has an external IP (LoadBalancer service)
#
# USAGE:
#   chmod +x scripts/setup-argocd-webhook.sh
#   ./scripts/setup-argocd-webhook.sh
# =============================================================================

set -euo pipefail

echo "=== ArgoCD GitLab Webhook Setup ==="
echo ""

# Step 1: Get ArgoCD server external IP
echo ">>> Getting ArgoCD server external IP..."
ARGOCD_IP=$(kubectl get svc argocd-server -n argocd \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -z "$ARGOCD_IP" ]; then
  # Try hostname (some LBs use hostname instead of IP)
  ARGOCD_IP=$(kubectl get svc argocd-server -n argocd \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
fi

if [ -z "$ARGOCD_IP" ]; then
  echo "ERROR: Could not get ArgoCD server external IP."
  echo "Make sure AKS is running: az aks start -g rg-devsecops -n aks-devsecops"
  echo "And ArgoCD is installed: kubectl get svc argocd-server -n argocd"
  exit 1
fi

ARGOCD_URL="https://${ARGOCD_IP}"
WEBHOOK_URL="${ARGOCD_URL}/api/webhook"

echo "    ArgoCD URL: $ARGOCD_URL"
echo ""

# Step 2: Generate a random webhook secret (32 hex chars)
WEBHOOK_SECRET=$(openssl rand -hex 16)
echo ">>> Generated webhook secret: $WEBHOOK_SECRET"
echo "    (Save this — you'll paste it into GitLab)"
echo ""

# Step 3: Patch argocd-secret with the GitLab webhook secret
# ArgoCD reads webhook.gitlab.secret from this K8s Secret to validate
# every incoming webhook request from GitLab.
# Without this, ArgoCD accepts ANY webhook call — a security risk.
echo ">>> Patching argocd-secret with webhook.gitlab.secret..."
kubectl patch secret argocd-secret -n argocd \
  --type='merge' \
  -p "{\"stringData\": {\"webhook.gitlab.secret\": \"${WEBHOOK_SECRET}\"}}"

echo "    argocd-secret patched successfully."
echo ""

# Step 4: Print GitLab configuration instructions
echo "================================================================"
echo "  NEXT STEP: Add webhook in GitLab"
echo "================================================================"
echo ""
echo "  1. Go to: https://gitlab.com/ahmed_marzouki/devsecops-project"
echo "     → Settings → Webhooks → Add new webhook"
echo ""
echo "  2. Fill in:"
echo "     URL:          $WEBHOOK_URL"
echo "     Secret token: $WEBHOOK_SECRET"
echo ""
echo "  3. Tick these triggers:"
echo "     [x] Push events         (branch: main)"
echo "     [x] Tag push events"
echo ""
echo "  4. Untick SSL verification if your ArgoCD uses a self-signed cert"
echo "     (common on AKS with no custom domain)"
echo ""
echo "  5. Click 'Add webhook', then 'Test → Push events' to verify"
echo ""
echo "  Expected result: ArgoCD syncs within seconds of every push to main"
echo "================================================================"
