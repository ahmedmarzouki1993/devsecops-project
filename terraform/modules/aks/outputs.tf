# =============================================================================
# modules/aks/outputs.tf — Values exposed to the root module
# =============================================================================
# Root module uses these to:
#   - Create the AcrPull role assignment (kubelet_identity_object_id → ACR)
#   - Create the KV Secrets User role assignment (principal_id → Key Vault)
#   - Export the OIDC issuer URL for Phase 6 (federated identity credentials)
#   - Export kube_config for kubectl access
# =============================================================================

output "cluster_name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.this.name
}

output "cluster_id" {
  description = "Full Azure resource ID of the cluster."
  value       = azurerm_kubernetes_cluster.this.id
}

output "principal_id" {
  description = "Object ID of the cluster's SystemAssigned managed identity. Used for Key Vault role assignment."
  value       = azurerm_kubernetes_cluster.this.identity[0].principal_id
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet managed identity. Used for AcrPull role assignment — the kubelet is what actually pulls images."
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL published by AKS. Used in Phase 6 to create federated identity credentials for pod → Key Vault auth."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "kube_config_raw" {
  description = "Raw kubeconfig. SENSITIVE — never log or commit this value."
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive   = true
}
