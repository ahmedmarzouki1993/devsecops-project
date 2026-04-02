# =============================================================================
# modules/acr/outputs.tf — Values this module exposes to the root module
# =============================================================================
# The root module reads these to wire ACR into AKS (role assignment)
# and into GitLab CI variables (login_server for docker push).
# =============================================================================

output "id" {
  description = "Full Azure resource ID of the registry. Used for the AcrPull role assignment scope."
  value       = azurerm_container_registry.this.id
}

output "name" {
  description = "Registry name. Used in: az acr login --name <name>"
  value       = azurerm_container_registry.this.name
}

output "login_server" {
  description = "Registry login server URL. Used as image prefix: <login_server>/backend:tag"
  value       = azurerm_container_registry.this.login_server
}
