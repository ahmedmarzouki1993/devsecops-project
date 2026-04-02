# =============================================================================
# modules/key-vault/variables.tf — Inputs for the Key Vault module
# =============================================================================

variable "resource_group_name" {
  type        = string
  description = "Resource group to create the Key Vault in."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "project_name" {
  type        = string
  description = "Project identifier used in Key Vault name."
}

variable "suffix" {
  type        = string
  description = "Random suffix for globally unique Key Vault name."
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID. Key Vault uses this to validate which AAD tenant to trust."
}

variable "sku_name" {
  type        = string
  description = "Key Vault SKU: standard (software keys) or premium (HSM-backed keys)."
  default     = "standard"
}

variable "soft_delete_retention_days" {
  type        = number
  description = "Days deleted objects are recoverable before permanent deletion. Min 7, max 90."
  default     = 7
}

# ── Role assignment inputs ──────────────────────────────────────────────────
# The KV module also owns the role assignments that grant access to this vault.
# Keeping roles inside the module means all KV access control is in one place.

variable "terraform_runner_object_id" {
  type        = string
  description = "Object ID of the Terraform runner identity (OIDC service principal or local az login user). Gets Key Vault Administrator role."
}

variable "aks_principal_id" {
  type        = string
  description = "Object ID of the AKS cluster's SystemAssigned managed identity. Gets Key Vault Secrets User role."
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the Key Vault."
  default     = {}
}
