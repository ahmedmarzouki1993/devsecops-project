# =============================================================================
# modules/aks/variables.tf — Inputs for the AKS module
# =============================================================================

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to create AKS in."
}

variable "location" {
  type        = string
  description = "Azure region for the cluster."
}

variable "project_name" {
  type        = string
  description = "Project identifier — used in the cluster name and dns_prefix."
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes minor version alias (e.g., '1.31'). AKS picks the latest stable patch."
  default     = "1.32"
}

variable "node_count" {
  type        = number
  description = "Number of worker nodes. Keep at 1 for Azure Student budget."
  default     = 1

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 3
    error_message = "node_count must be 1-3 (Azure Student budget constraint)."
  }
}

variable "node_vm_size" {
  type        = string
  description = "VM size for worker nodes. Standard_B2s = 2 vCPU, 4GB RAM, ~$30/mo."
  default     = "Standard_B2s_v2"
}

variable "os_disk_size_gb" {
  type        = number
  description = "OS disk size in GB for each node."
  default     = 30
}

variable "environment" {
  type        = string
  description = "Environment label applied as a node label."
  default     = "dev"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the cluster."
  default     = {}
}
