# =============================================================================
# providers.tf — Terraform and provider version pinning + authentication
# =============================================================================
#
# WHY PIN VERSIONS?
#   Without pinning, `terraform init` always pulls the latest provider.
#   A breaking change in azurerm 5.0 could silently destroy your infra.
#   Pinning guarantees reproducible runs across your laptop, CI, and teammates.
#
# WHY OIDC AUTH (no client_secret)?
#   Azure Student Pack restricts Service Principal creation with AD.
#   OIDC (OpenID Connect) lets GitLab CI prove its identity to Azure using
#   a short-lived signed token — no password ever stored anywhere.
#   Flow: GitLab CI → generates OIDC token → Azure validates it → issues access.
# =============================================================================

terraform {
  # Minimum Terraform CLI version required to use this config.
  # ~> 1.9 means ">= 1.9.0 AND < 2.0.0" — allows patch/minor upgrades, blocks major.
  required_version = "~> 1.9"

  required_providers {
    # Azure Resource Manager — manages all Azure resources (AKS, ACR, Key Vault, etc.)
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0" # >= 4.0.0, < 5.0.0
    }

    # Random — generates unique suffixes (e.g., Key Vault name must be globally unique)
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# -----------------------------------------------------------------------------
# Azure Provider configuration
# -----------------------------------------------------------------------------
# Authentication is handled entirely via environment variables — no secrets in code.
#
# Required environment variables (set in GitLab CI Variables, masked + protected):
#   ARM_CLIENT_ID       — App Registration client ID (from OIDC federation setup)
#   ARM_TENANT_ID       — Your Azure AD tenant ID
#   ARM_SUBSCRIPTION_ID — Your Azure subscription ID
#   ARM_USE_OIDC        — Must be "true" to activate OIDC flow
#
# For local development, run: az login
# Terraform will automatically use your Azure CLI credentials.
# -----------------------------------------------------------------------------
provider "azurerm" {
  # Activate OIDC token-based authentication.
  # When true, Terraform reads the OIDC token from the environment
  # (GitLab injects it as CI_JOB_JWT_V2) and exchanges it with Azure.
  use_oidc = true

  # The subscription where all resources will be created.
  # Reads from ARM_SUBSCRIPTION_ID env var — no hardcoding.
  subscription_id = var.subscription_id

  # Resource provider features — controls destroy/update behavior.
  features {
    key_vault {
      # When you run `terraform destroy`, Azure soft-deletes Key Vaults by default
      # (they're recoverable for 7-90 days). This setting HARD deletes them on destroy,
      # which is what we want in a dev/student environment so we can recreate freely.
      purge_soft_delete_on_destroy = true

      # If a Key Vault with the same name was soft-deleted, recover it instead of
      # failing. Useful when you destroy and recreate with the same name.
      recover_soft_deleted_key_vaults = true
    }

    resource_group {
      # Safety net: Terraform will error if you try to destroy a resource group
      # that still has resources Terraform doesn't know about.
      # Prevents accidental deletion of manually created resources.
      prevent_deletion_if_contains_resources = false # set true in production
    }
  }
}

# Random provider needs no configuration — it generates values locally.
provider "random" {}
