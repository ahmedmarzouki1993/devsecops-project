# =============================================================================
# modules/acr/variables.tf — Inputs for the ACR module
# =============================================================================
# These are the ONLY values this module needs from the outside world.
# The module doesn't know about AKS or Key Vault — it just creates a registry.
# =============================================================================

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to create ACR in."
}

variable "location" {
  type        = string
  description = "Azure region for the registry."
}

variable "project_name" {
  type        = string
  description = "Project identifier used in the registry name (alphanumeric only)."
}

variable "suffix" {
  type        = string
  description = "Random suffix for globally unique ACR name."
}

variable "sku" {
  type        = string
  description = "ACR pricing tier: Basic | Standard | Premium."
  default     = "Basic"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the registry."
  default     = {}
}
