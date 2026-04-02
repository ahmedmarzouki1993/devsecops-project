# =============================================================================
# main.tf — Root module: orchestrates all child modules
# =============================================================================
#
# WHY MODULES?
#   A flat main.tf with 8+ resources becomes hard to read and maintain.
#   Modules create a clean separation of concerns:
#     - Each module owns ONE component (ACR, AKS, or Key Vault)
#     - Each module has its own variables.tf and outputs.tf = clear interface
#     - Root main.tf is just wiring — it reads like a diagram, not a script
#     - Modules can be tested, versioned, and reused independently
#
# STRUCTURE:
#   modules/acr/       → Container Registry
#   modules/aks/       → Kubernetes Cluster
#   modules/key-vault/ → Key Vault + RBAC role assignments
#
# DATA FLOW:
#   random_string.suffix ──────────────────────────────────────┐
#   data.azurerm_client_config.current ──────────────────────┐ │
#   azurerm_resource_group.main ──────────────────────────┐  │ │
#                                                          ▼  ▼ ▼
#   module.acr       ← resource_group, location, project, suffix
#   module.aks       ← resource_group, location, project, k8s_version, node config
#   module.key_vault ← resource_group, location, project, suffix, tenant_id,
#                      aks.principal_id, client_config.object_id
#   module.aks + module.acr → role assignment (AcrPull) in root
# =============================================================================

# -----------------------------------------------------------------------------
# Data sources
# -----------------------------------------------------------------------------

# Reads the identity of whoever is running Terraform.
# Used for: tenant_id (Key Vault), object_id (KV admin role assignment).
data "azurerm_client_config" "current" {}

# -----------------------------------------------------------------------------
# Shared infrastructure
# -----------------------------------------------------------------------------

# Single resource group — all project resources live here.
# WHY ONE GROUP? Easier cost tracking, policy enforcement, and bulk deletion.
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}"
  location = var.location

  tags = local.common_tags
}

# 4-char random suffix for globally unique resource names (ACR, Key Vault).
# These names must be unique across ALL Azure customers worldwide.
resource "random_string" "suffix" {
  length  = 4
  upper   = false # ACR names are lowercase only
  special = false # ACR naming: alphanumeric only
}

# Common tags applied to every resource — centralised here so all modules get them.
locals {
  common_tags = {
    project     = var.project_name # for Azure Cost Management filtering
    environment = var.environment  # dev / staging / prod
    managed-by  = "terraform"      # signals: don't modify manually
  }
}

# -----------------------------------------------------------------------------
# Module: Container Registry (ACR)
# -----------------------------------------------------------------------------
# Stores Docker images built and pushed by GitLab CI.
# AKS pulls from here using Managed Identity (no imagePullSecrets).

module "acr" {
  source = "./modules/acr"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project_name        = var.project_name
  suffix              = random_string.suffix.result
  sku                 = var.acr_sku
  tags                = local.common_tags
}

# -----------------------------------------------------------------------------
# Module: AKS Cluster
# -----------------------------------------------------------------------------
# Managed Kubernetes — Azure handles control plane (API server, etcd) for free.
# We pay only for the worker node (1x Standard_B2s ≈ $30/mo).

module "aks" {
  source = "./modules/aks"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project_name        = var.project_name
  kubernetes_version  = var.kubernetes_version
  node_count          = var.node_count
  node_vm_size        = var.node_vm_size
  os_disk_size_gb     = var.os_disk_size_gb
  environment         = var.environment
  tags                = local.common_tags
}

# -----------------------------------------------------------------------------
# Module: Key Vault
# -----------------------------------------------------------------------------
# Stores secrets: DB password, Slack webhook URLs, TLS certs.
# In Phase 6, the CSI Secrets Store driver mounts secrets directly into pods.

module "key_vault" {
  source = "./modules/key-vault"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  project_name               = var.project_name
  suffix                     = random_string.suffix.result
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = var.kv_sku
  soft_delete_retention_days = var.kv_soft_delete_retention_days

  # Terraform runner gets KV Administrator (to seed secrets during apply)
  terraform_runner_object_id = data.azurerm_client_config.current.object_id

  # AKS cluster identity gets KV Secrets User (to read secrets in Phase 6)
  aks_principal_id = module.aks.principal_id

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Role Assignment: AKS kubelet → ACR (AcrPull)
# -----------------------------------------------------------------------------
# WHY in root and not inside a module?
#   This role assignment spans TWO modules (AKS + ACR) — it needs outputs from both.
#   Cross-module wiring belongs in the root module, not inside either child module.
#
# WHY kubelet_identity (not cluster identity)?
#   The kubelet is the node agent that actually pulls images when scheduling pods.
#   The cluster identity is the control plane — it doesn't pull images.
#   Using the wrong identity = AcrPull role exists but pods still get ErrImagePull.

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = module.acr.id # scoped to THIS registry only (least privilege)
  role_definition_name = "AcrPull"     # read images only — no push, no delete
  principal_id         = module.aks.kubelet_identity_object_id

  # Managed identities need this flag — they're not "classic" service principals.
  skip_service_principal_aad_check = true
}
