# =============================================================================
# variables.tf — All input variables with full metadata and validation
# =============================================================================
#
# WHY VARIABLES (not hardcoded values)?
#   Hardcoded values in .tf files mean changing a region requires editing 10 files.
#   Variables centralize all tuneable values — change once, applies everywhere.
#   Also: variables.tf is committed to git. terraform.tfvars (actual values) is NOT.
#   This separation means no secrets or personal values ever reach the repository.
#
# PATTERN:
#   Each variable has: type, description, default (if optional), validation (if constrained)
# =============================================================================

# -----------------------------------------------------------------------------
# Azure identity & location
# -----------------------------------------------------------------------------

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID where all resources will be created. Find it in Azure Portal > Subscriptions."
  # No default — must be provided explicitly. Too important to guess.
}

variable "location" {
  type        = string
  description = "Azure region for all resources. uaenorth = UAE North (lowest latency for Ahmed)."
  default     = "uaenorth"

  validation {
    # Restrict to regions that support AKS and are cost-effective for students.
    condition     = contains(["uaenorth", "eastus", "westeurope", "uaecentral"], var.location)
    error_message = "Location must be one of: uaenorth, eastus, westeurope, uaecentral."
  }
}

# -----------------------------------------------------------------------------
# Naming
# -----------------------------------------------------------------------------

variable "project_name" {
  type        = string
  description = "Short project identifier used as prefix in all resource names."
  default     = "devsecops"

  validation {
    # ACR names allow only alphanumeric. Keep project_name simple.
    condition     = can(regex("^[a-z0-9]+$", var.project_name))
    error_message = "project_name must be lowercase alphanumeric only (no dashes/underscores) — ACR naming constraint."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment tag. Used in resource tags and naming."
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

# -----------------------------------------------------------------------------
# AKS — Kubernetes cluster
# -----------------------------------------------------------------------------

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for the AKS cluster. Check supported versions with: az aks get-versions -l uaenorth."
  default     = "1.31"
  # Minor version alias — AKS auto-picks the latest stable patch (e.g., 1.31.2).
  # This is safer than pinning an exact patch version which may be deprecated.
}

variable "node_count" {
  type        = number
  description = "Number of worker nodes in the default node pool. Keep at 1 to stay within Azure Student budget (~$36/month)."
  default     = 1

  validation {
    # Azure Student budget cannot afford more than 3 B2s nodes.
    condition     = var.node_count >= 1 && var.node_count <= 3
    error_message = "node_count must be 1-3. Azure Student budget constraint: 1 node = ~$36/mo."
  }
}

variable "node_vm_size" {
  type        = string
  description = "Azure VM size for AKS worker nodes. Standard_B2s = 2 vCPU, 4GB RAM — cheapest viable for K8s (~$30/mo)."
  default     = "Standard_B2s"
}

variable "os_disk_size_gb" {
  type        = number
  description = "OS disk size in GB for each AKS node. 30GB is the minimum for K8s system pods."
  default     = 30

  validation {
    condition     = var.os_disk_size_gb >= 30 && var.os_disk_size_gb <= 128
    error_message = "os_disk_size_gb must be between 30 and 128 GB."
  }
}

# -----------------------------------------------------------------------------
# ACR — Container Registry
# -----------------------------------------------------------------------------

variable "acr_sku" {
  type        = string
  description = "ACR pricing tier. Basic = cheapest (~$5/mo), sufficient for private images + AKS pull."
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "acr_sku must be Basic, Standard, or Premium."
  }
}

# -----------------------------------------------------------------------------
# Key Vault
# -----------------------------------------------------------------------------

variable "kv_sku" {
  type        = string
  description = "Key Vault pricing tier. standard = software-protected keys (cheaper). premium = HSM-backed."
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.kv_sku)
    error_message = "kv_sku must be standard or premium."
  }
}

variable "kv_soft_delete_retention_days" {
  type        = number
  description = "Days to retain soft-deleted KV objects before permanent deletion. Minimum 7, maximum 90."
  default     = 7 # Minimum — allows faster cleanup in dev environment

  validation {
    condition     = var.kv_soft_delete_retention_days >= 7 && var.kv_soft_delete_retention_days <= 90
    error_message = "kv_soft_delete_retention_days must be between 7 and 90."
  }
}
