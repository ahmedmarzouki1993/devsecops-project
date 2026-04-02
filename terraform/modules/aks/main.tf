# =============================================================================
# modules/aks/main.tf — Azure Kubernetes Service cluster
# =============================================================================
# WHY A MODULE?
#   AKS has many configuration blocks (node pool, network, identity, OIDC).
#   Keeping it isolated means the root module stays clean, and this module
#   can evolve independently (e.g., add a second node pool, change CNI)
#   without touching ACR or Key Vault code.
# =============================================================================

resource "azurerm_kubernetes_cluster" "this" {
  name                = "aks-${var.project_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = var.project_name
  kubernetes_version  = var.kubernetes_version

  # ── Default node pool ──────────────────────────────────────────────────────
  default_node_pool {
    name            = "default"
    vm_size         = var.node_vm_size
    node_count      = var.node_count
    os_disk_size_gb = var.os_disk_size_gb
    os_disk_type    = "Managed"

    node_labels = {
      "nodepool-type" = "system"
      "environment"   = var.environment
      "nodepoolos"    = "linux"
    }
  }

  # ── Identity ───────────────────────────────────────────────────────────────
  # SystemAssigned: Azure creates and rotates this identity automatically.
  # No client_secret to store, rotate, or leak.
  identity {
    type = "SystemAssigned"
  }

  # ── OIDC + Workload Identity ───────────────────────────────────────────────
  # Required for Phase 6: pods authenticate to Key Vault using their K8s
  # service account token — no secrets needed inside pods.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # ── Auto-upgrade channel ───────────────────────────────────────────────────
  # "patch": AKS automatically upgrades to the latest stable patch version
  # within the current minor version. Safe for production — no breaking changes.
  # Required by Checkov bc-azure-2-29 (CIS Azure benchmark).
  automatic_channel_upgrade = "patch"

  # ── Networking ─────────────────────────────────────────────────────────────
  # kubenet: simpler, smaller IP footprint — suitable for single-node dev cluster.
  # Pods get IPs from a private overlay network, not from the Azure VNet.
  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard" # Required for managed outbound IPs
  }

  # ── Maintenance window ─────────────────────────────────────────────────────
  # Allow AKS to patch node OS during off-hours (Sunday 2am UAE time).
  maintenance_window_node_os {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "02:00"
    utc_offset  = "+04:00"
  }

  tags = var.tags
}
