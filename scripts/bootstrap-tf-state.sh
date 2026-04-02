#!/usr/bin/env bash
# =============================================================================
# bootstrap-tf-state.sh — Create Azure Storage for Terraform remote state
# =============================================================================
#
# WHY THIS SCRIPT EXISTS:
#   Terraform remote state lives in Azure Storage.
#   But you can't use Terraform to create the storage for Terraform state —
#   that's a chicken-and-egg problem (state doesn't exist yet to track itself).
#   Solution: create it ONCE with Azure CLI, then Terraform uses it forever.
#
# RUN THIS ONCE before the first `terraform init`.
# It is idempotent — safe to run multiple times, won't duplicate resources.
#
# PREREQUISITES:
#   - az login (already authenticated)
#   - Azure CLI installed
#
# USAGE:
#   chmod +x scripts/bootstrap-tf-state.sh
#   ./scripts/bootstrap-tf-state.sh
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# ── Configuration ─────────────────────────────────────────────────────────────
# Separate resource group for state — kept alive even when main infra is destroyed.
# This way `terraform destroy` on main infra doesn't delete your state file.
STATE_RG="rg-devsecops-state"
STATE_SA="stdevsecopsstate"    # Storage account: globally unique, lowercase, alphanumeric
STATE_CONTAINER="tfstate"
LOCATION="uaenorth"            # Must match var.location in variables.tf

echo "=================================================="
echo "Bootstrapping Terraform remote state storage"
echo "  Resource Group : $STATE_RG"
echo "  Storage Account: $STATE_SA"
echo "  Container      : $STATE_CONTAINER"
echo "  Location       : $LOCATION"
echo "=================================================="

# ── Step 1: Create the state resource group ───────────────────────────────────
echo ""
echo "[1/4] Creating resource group: $STATE_RG"
az group create \
  --name "$STATE_RG" \
  --location "$LOCATION" \
  --tags project=devsecops managed-by=bootstrap \
  --output table

# ── Step 2: Create the storage account ───────────────────────────────────────
# --sku Standard_LRS: Locally Redundant Storage — 3 copies in same datacenter.
# Cheapest option, sufficient for state files. (~$0.02/GB/month)
# --https-only: Terraform state contains secrets — enforce encryption in transit.
# --min-tls-version TLS1_2: Don't allow old TLS versions.
echo ""
echo "[2/4] Creating storage account: $STATE_SA"
echo "      NOTE: If this fails with 'already taken', add a suffix (e.g., stdevsecopsstate2)"
az storage account create \
  --name "$STATE_SA" \
  --resource-group "$STATE_RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --output table

# ── Step 3: Create the blob container ─────────────────────────────────────────
# The container holds the .tfstate file (like a folder inside the storage account).
echo ""
echo "[3/4] Creating blob container: $STATE_CONTAINER"
az storage container create \
  --name "$STATE_CONTAINER" \
  --account-name "$STATE_SA" \
  --auth-mode login \
  --output table

# ── Step 4: Enable versioning ─────────────────────────────────────────────────
# WHY VERSIONING?
#   Terraform overwrites the state blob on every apply.
#   Versioning keeps the last 7 days of state — you can restore if state is corrupted.
#   This has saved many engineers from disasters.
echo ""
echo "[4/4] Enabling blob versioning (state history for 7 days)"
az storage account blob-service-properties update \
  --account-name "$STATE_SA" \
  --resource-group "$STATE_RG" \
  --enable-versioning true \
  --output table

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "=================================================="
echo "Bootstrap complete!"
echo ""
echo "Next steps:"
echo "  1. cd terraform/"
echo "  2. cp terraform.tfvars.example terraform.tfvars"
echo "  3. Edit terraform.tfvars with your subscription_id"
echo "  4. terraform init"
echo "  5. terraform plan -out=tfplan"
echo "  6. terraform apply tfplan"
echo "=================================================="
