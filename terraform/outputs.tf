# =============================================================================
# outputs.tf — Root module outputs (reads from child modules)
# =============================================================================
# After `terraform apply`, these values are printed to the terminal.
# Use them to configure kubectl, GitLab CI variables, and docker push commands.
#
# Commands:
#   terraform output                        # print all
#   terraform output -raw acr_login_server  # single value (no quotes, for scripts)
#   terraform output -json                  # machine-readable
# =============================================================================

# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

output "resource_group_name" {
  description = "Main resource group name. Used in az CLI commands."
  value       = azurerm_resource_group.main.name
}

output "location" {
  description = "Azure region where all resources are deployed."
  value       = azurerm_resource_group.main.location
}

# -----------------------------------------------------------------------------
# ACR — Container Registry
# -----------------------------------------------------------------------------

output "acr_name" {
  description = "ACR registry name. Used in: az acr login --name <name>"
  value       = module.acr.name
}

output "acr_login_server" {
  description = "ACR login server URL. Image prefix for docker tag/push. Example: acrdevsecopsab12.azurecr.io"
  value       = module.acr.login_server
}

# -----------------------------------------------------------------------------
# AKS Cluster
# -----------------------------------------------------------------------------

output "aks_cluster_name" {
  description = "AKS cluster name. Used in: az aks get-credentials -g <rg> -n <name>"
  value       = module.aks.cluster_name
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL — needed in Phase 6 to create federated identity credentials for pod → Key Vault auth."
  value       = module.aks.oidc_issuer_url
}

output "kube_config" {
  description = "Raw kubeconfig. SENSITIVE. Use: terraform output -raw kube_config > ~/.kube/config"
  value       = module.aks.kube_config_raw
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Key Vault
# -----------------------------------------------------------------------------

output "key_vault_name" {
  description = "Key Vault name. Used in: az keyvault secret set --vault-name <name>"
  value       = module.key_vault.name
}

output "key_vault_uri" {
  description = "Key Vault URI. Used in the CSI SecretProviderClass manifest in Phase 6."
  value       = module.key_vault.uri
}

# -----------------------------------------------------------------------------
# GitLab CI — copy these into Settings > CI/CD > Variables
# -----------------------------------------------------------------------------

output "gitlab_ci_variables" {
  description = "Copy these values into GitLab CI/CD Variables (masked where noted in docs/phase-1/README.md)."
  value = {
    ACR_LOGIN_SERVER     = module.acr.login_server
    AKS_CLUSTER_NAME     = module.aks.cluster_name
    AZURE_RESOURCE_GROUP = azurerm_resource_group.main.name
    KEY_VAULT_NAME       = module.key_vault.name
    KEY_VAULT_URI        = module.key_vault.uri
  }
}
