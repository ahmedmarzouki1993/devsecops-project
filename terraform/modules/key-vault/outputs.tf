# =============================================================================
# modules/key-vault/outputs.tf — Values exposed to the root module
# =============================================================================

output "id" {
  description = "Full Azure resource ID of the Key Vault."
  value       = azurerm_key_vault.this.id
}

output "name" {
  description = "Key Vault name. Used in: az keyvault secret set --vault-name <name>"
  value       = azurerm_key_vault.this.name
}

output "uri" {
  description = "Key Vault URI. Used in the CSI SecretProviderClass manifest in Phase 6. Example: https://kv-devsecops-ab12.vault.azure.net/"
  value       = azurerm_key_vault.this.vault_uri
}
