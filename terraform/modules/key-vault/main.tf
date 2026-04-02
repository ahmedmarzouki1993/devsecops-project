# =============================================================================
# modules/key-vault/main.tf — Azure Key Vault + access role assignments
# =============================================================================
# WHY A MODULE?
#   Key Vault + its role assignments form a logical unit — the vault is only
#   useful if the right identities can access it. Keeping both together means
#   you can't accidentally create a vault with no access (or too much access).
#
# WHY RBAC (not access policies)?
#   Access policies are KV-specific and can't be audited with Azure Policy.
#   RBAC uses the same Azure role system as all other resources — consistent,
#   auditable, and works with Privileged Identity Management (PIM) in prod.
# =============================================================================

resource "azurerm_key_vault" "this" {
  # Name max 24 chars. "kv-devsecops-ab12" = 18 chars — safe.
  name                = "kv-${var.project_name}-${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = var.tenant_id
  sku_name            = var.sku_name

  # Soft delete: deleted secrets are recoverable for this many days before permanent deletion.
  # 7 = minimum — faster cleanup in dev. Use 90 in production for compliance.
  soft_delete_retention_days = var.soft_delete_retention_days

  # Purge protection: if true, nobody can permanently delete for retention_days.
  # Keep false in dev so terraform destroy works cleanly.
  # Set true in production for compliance (PCI-DSS, ISO27001).
  purge_protection_enabled = false

  # Use Azure RBAC instead of legacy access policies.
  # rbac_authorization_enabled = true means roles (below) control all access.
  rbac_authorization_enabled = true

  tags = var.tags
}

# ── Role: Terraform runner → Key Vault Administrator ──────────────────────────
# WHY?
#   With RBAC enabled, even the creator has no access by default.
#   The CI pipeline (Terraform runner) needs admin access to create/update secrets
#   during terraform apply (e.g., seeding the DB password in Phase 6).
resource "azurerm_role_assignment" "terraform_kv_admin" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.terraform_runner_object_id
}

# ── Role: AKS cluster identity → Key Vault Secrets User ──────────────────────
# WHY?
#   In Phase 6, the CSI Secrets Store driver uses the AKS cluster identity
#   to mount secrets from Key Vault directly into pods as files.
#   "Key Vault Secrets User" = read-only: get + list secrets. Least privilege.
resource "azurerm_role_assignment" "aks_kv_secrets_reader" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.aks_principal_id
}
