# =============================================================================
# backend.tf — Remote state configuration
# =============================================================================
#
# WHY REMOTE STATE?
#   By default Terraform stores state in a local terraform.tfstate file.
#   Problems with local state:
#     1. If your laptop dies → state is lost → Terraform can't manage existing infra
#     2. Two people run `terraform apply` simultaneously → state corruption
#     3. State contains sensitive values (passwords, certs) → risky in git
#
#   Remote state in Azure Storage solves all three:
#     1. Stored durably in Azure Blob Storage (99.9999999% durability)
#     2. State locking via Azure Blob leases — only one apply at a time
#     3. State never committed to git — stays in Azure
#
# IMPORTANT: The storage account must exist BEFORE running `terraform init`.
#            Run scripts/bootstrap-tf-state.sh ONCE to create it.
# =============================================================================

terraform {
  backend "azurerm" {
    # Resource group that holds ONLY the state storage account.
    # Kept separate from rg-devsecops so you can destroy the main infra
    # without losing the state file.
    resource_group_name = "rg-devsecops-state"

    # Storage account name — must be globally unique, lowercase, alphanumeric, 3-24 chars.
    # Created by scripts/bootstrap-tf-state.sh before first terraform init.
    storage_account_name = "stdevsecopsstate"

    # Blob container inside the storage account that holds state files.
    container_name = "tfstate"

    # The blob (file) name for this project's state.
    # Using a descriptive name allows multiple projects to share one storage account.
    key = "devsecops.terraform.tfstate"

    # Use OIDC for backend authentication — same flow as the provider.
    # Reads ARM_CLIENT_ID, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID, ARM_USE_OIDC from env.
    use_oidc = true
  }
}
