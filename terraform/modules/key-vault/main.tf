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
  #checkov:skip=CKV_AZURE_189: Public access required — CSI Secrets Store driver reaches KV over public endpoint (no VNet peering in student setup)
  #checkov:skip=CKV2_AZURE_32: Private endpoint requires VNet integration and private DNS zone — out of scope for student budget
  # Name max 24 chars. "kv-devsecops-ab12" = 18 chars — safe.
  name                = "kv-${var.project_name}-${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = var.tenant_id
  sku_name            = var.sku_name

  # Soft delete: deleted secrets are recoverable for this many days before permanent deletion.
  # 7 = minimum — faster cleanup in dev. Use 90 in production for compliance.
  soft_delete_retention_days = var.soft_delete_retention_days

  # Purge protection: prevents permanent deletion during retention period.
  # Required by CKV_AZURE_110 and CKV_AZURE_42 (CIS Azure benchmark).
  # NOTE: enabling this means `terraform destroy` will leave the KV in a soft-deleted
  # state for soft_delete_retention_days — run `az keyvault purge` manually if needed.
  purge_protection_enabled = true

  # Use Azure RBAC instead of legacy access policies.
  # rbac_authorization_enabled = true means roles (below) control all access.
  rbac_authorization_enabled = true

  # Firewall: deny all public traffic by default, allow Azure services (CSI driver, Terraform).
  # CKV_AZURE_109: network ACLs required by CIS Azure benchmark.
  network_acls {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

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
