---
name: terraform
description: >
  Terraform Infrastructure as Code workflows. Use when creating, modifying, planning, or debugging
  Terraform files. Also use when Ahmed asks about Azure resource provisioning, state management,
  or infrastructure changes. Auto-invoke when editing any file in terraform/ directory.
allowed-tools: Read, Write, Bash, Grep, Glob
---

## Terraform workflow for devsecops-project

### Context
- Cloud: Azure (Student Pack — $100 credit limit)
- Resources: rg-devsecops, aks-devsecops, acrdevsecops, kv-devsecops-*
- State backend: Azure Storage Account `stdevsecopsstate`
- Provider: azurerm (pinned version)

### When writing or editing Terraform files

1. **Always add inline comments** explaining WHY each resource/setting exists. Ahmed is learning.
2. **Pin provider versions** — never use `>=` without an upper bound.
3. **Tag every resource**:
   ```hcl
   tags = {
     project     = "devsecops-project"
     environment = "dev"
     managed-by  = "terraform"
   }
   ```
4. **Use variables with full metadata**:
   ```hcl
   variable "node_count" {
     type        = number
     description = "Number of AKS worker nodes"
     default     = 1
     validation {
       condition     = var.node_count >= 1 && var.node_count <= 3
       error_message = "Node count must be 1-3 (Azure Student budget)."
     }
   }
   ```
5. **Output everything downstream needs**: cluster name, ACR login server, Key Vault URI, resource group name.
6. **Never generate terraform.tfvars** — it's gitignored. Tell Ahmed what values to put in it.

### Terraform commands (always use these)
```bash
cd terraform/
terraform init                    # First time or after backend changes
terraform fmt -recursive          # Format before committing
terraform validate                # Check syntax
terraform plan -out=tfplan        # ALWAYS plan first
terraform apply tfplan            # Apply the reviewed plan
terraform destroy                 # Only when tearing down
```

### Teaching points to mention when relevant
- **Why remote state?** If your laptop dies, local state is gone. Remote state is shared, locked, versioned.
- **Why plan before apply?** In production, blind apply can delete databases. Always review the plan.
- **Why managed identity?** AKS authenticates to ACR without passwords. Zero secrets to manage.
- **Why AcrPull role?** Least privilege — AKS can only pull images, not push or delete.
- **Azure Student constraints**: 1x Standard_B2s node (~$30/mo), ACR Basic (~$5/mo), always stop AKS when idle.

### Common errors and fixes
- "Provider not registered" → `az provider register --namespace Microsoft.ContainerService`
- "Quota exceeded" → Try a different region (eastus, westeurope) or smaller VM
- "State locked" → `terraform force-unlock <LOCK_ID>` (only if you're sure no one else is running)
- "ACR name taken" → ACR names are globally unique, add random suffix
