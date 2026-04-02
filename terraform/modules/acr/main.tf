# =============================================================================
# modules/acr/main.tf — Azure Container Registry
# =============================================================================
# WHY A MODULE?
#   The ACR resource is self-contained — it has no hard dependency on AKS or
#   Key Vault. Isolating it here means you can:
#   - Test it independently (terraform plan in this directory alone)
#   - Reuse it in other projects with different variable values
#   - Replace it (e.g., switch to Harbor) without touching AKS/KV code
# =============================================================================

# checkov:skip=CKV_AZURE_165: "Geo-replication requires Premium SKU — exceeds student budget"
# checkov:skip=CKV_AZURE_233: "Zone redundancy requires Premium SKU — exceeds student budget"
# checkov:skip=CKV_AZURE_163: "Vulnerability scanning (Defender for Containers) requires Premium SKU"
# checkov:skip=CKV_AZURE_164: "Trust policy requires Premium SKU"
# checkov:skip=CKV_AZURE_166: "Quarantine policy requires Premium SKU"
# checkov:skip=CKV_AZURE_139: "Public network access required — GitLab CI runner pushes images over public internet"
resource "azurerm_container_registry" "this" {
  # Name: alphanumeric only, globally unique, 5-50 chars
  # The root module passes a random suffix to guarantee uniqueness.
  name                = "acr${var.project_name}${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku

  # Disable static admin credentials — AKS authenticates via Managed Identity (AcrPull role).
  # Admin = static password that can leak. Managed Identity = rotating short-lived token.
  admin_enabled = false

  # Automatically delete untagged image manifests after 7 days to prevent registry bloat.
  # CKV_AZURE_167: retention policy required by CIS Azure benchmark.
  retention_policy {
    days    = 7
    enabled = true
  }

  tags = var.tags
}
