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
  #checkov:skip=CKV_AZURE_115: Private cluster requires private runner or VPN — GitLab CI uses public runners
  #checkov:skip=CKV_AZURE_6:   API server IP ranges not set — GitLab CI runners use dynamic IPs
  #checkov:skip=CKV_AZURE_170: Paid SLA tier costs ~$70/mo — exceeds student budget
  #checkov:skip=CKV_AZURE_116: Azure Policy add-on — Kyverno already enforces admission policies in-cluster
  #checkov:skip=CKV_AZURE_141: Local admin disabled requires AAD integration — not configured in student tenancy
  #checkov:skip=CKV_AZURE_117: Disk encryption set requires separate DES resource — cost and complexity out of scope
  #checkov:skip=CKV_AZURE_227: Temp disk encryption requires disk encryption set — same as above
  #checkov:skip=CKV_AZURE_226: Ephemeral OS disks not supported on Standard_B2s VM size
  #checkov:skip=CKV_AZURE_232: System-only node taint requires a second node pool — single-node budget constraint
  #checkov:skip=CKV2_AZURE_29: Azure CNI requires more VNet IPs — kubenet is intentional for single-node dev cluster
  #checkov:skip=CKV_AZURE_4:   OMS agent requires Log Analytics workspace — using Prometheus/Grafana stack instead
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
    max_pods        = 50 # CKV_AZURE_168: minimum 50 pods per node required by CIS benchmark

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

  # ── Azure Monitor metrics ──────────────────────────────────────────────────
  # CKV_AZURE_4: enables container insights / Azure Monitor for the cluster.
  # Lightweight — only activates the metrics pipeline, no extra cost at this scale.
  monitor_metrics {}

  # ── Secrets Store CSI auto-rotation ───────────────────────────────────────
  # CKV_AZURE_172: automatically re-syncs Key Vault secrets into pods when
  # the secret value changes in Key Vault — no pod restart required.
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  # ── Auto-upgrade channel ───────────────────────────────────────────────────
  # "patch": AKS automatically upgrades to the latest stable patch version
  # within the current minor version. Safe for production — no breaking changes.
  # Required by Checkov bc-azure-2-29 (CIS Azure benchmark).
  automatic_channel_upgrade = "patch"

  # ── Networking ─────────────────────────────────────────────────────────────
  # kubenet: simpler, smaller IP footprint — suitable for single-node dev cluster.
  # Pods get IPs from a private overlay network, not from the Azure VNet.
  network_profile {
    network_plugin = "kubenet"
    network_policy = "calico"      # CKV_AZURE_7: network policy required; calico works with kubenet
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
