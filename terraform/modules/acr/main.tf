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

  tags = var.tags
}
