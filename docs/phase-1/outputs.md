# Phase 1 — Applied Outputs

> **Date applied:** 2026-03-29
> **Status:** Complete ✅
> **Duration:** ~10 minutes total

---

## Real resource names (post-apply)

| Resource | Name | Notes |
|----------|------|-------|
| Resource Group | `rg-devsecops` | `uaenorth` |
| Container Registry | `acrdevsecops9nsi` | suffix = `9nsi` |
| ACR Login Server | `acrdevsecops9nsi.azurecr.io` | use as image prefix |
| AKS Cluster | `aks-devsecops` | K8s `v1.32.10`, 1× `Standard_B2s_v2` |
| Key Vault | `kv-devsecops-9nsi` | RBAC-enabled, standard SKU |
| Key Vault URI | `https://kv-devsecops-9nsi.vault.azure.net/` | for CSI driver in Phase 6 |
| OIDC Issuer URL | `https://uaenorth.oic.prod-aks.azure.com/604f1a96-.../1da0efde-.../` | for Phase 6 federated identity |

## State storage (bootstrap)

| Resource | Name |
|----------|------|
| Resource Group | `rg-devsecops-state` |
| Storage Account | `stdevsecopsstate` |
| Container | `tfstate` |
| Blob key | `devsecops.terraform.tfstate` |

---

## Issues encountered and fixed

| Issue | Root cause | Fix applied |
|-------|-----------|-------------|
| AKS `K8sVersionNotSupported` | K8s `1.31` in UAE North only has LTS patches (requires Premium tier) | Updated to `1.32` |
| AKS `Standard_B2s` not allowed | Old B-series not available on Student subscription in UAE North | Updated to `Standard_B2s_v2` (equivalent: 2 vCPU, 4GB RAM) |
| MFA expired on first bootstrap run | Azure Student MFA session expired | Re-authenticated with `az login` |

---

## GitLab CI variables to set

Go to: **GitLab → Settings → CI/CD → Variables**

| Variable | Value | Masked? |
|----------|-------|---------|
| `AZURE_CLIENT_ID` | *(from OIDC App Registration — set up before Phase 3)* | Yes |
| `AZURE_TENANT_ID` | `604f1a96-cbe8-43f8-abbf-f8eaf5d85730` | Yes |
| `AZURE_SUBSCRIPTION_ID` | `b4ddcf08-8c5e-42a6-86c1-70091724a93c` | Yes |
| `ACR_LOGIN_SERVER` | `acrdevsecops9nsi.azurecr.io` | No |
| `AKS_CLUSTER_NAME` | `aks-devsecops` | No |
| `AZURE_RESOURCE_GROUP` | `rg-devsecops` | No |
| `KEY_VAULT_NAME` | `kv-devsecops-9nsi` | No |
| `KEY_VAULT_URI` | `https://kv-devsecops-9nsi.vault.azure.net/` | No |

---

## Verification commands

```bash
# Cluster node
kubectl get nodes -o wide
# Result: aks-default-12416966-vmss000000   Ready   v1.32.10

# ACR login
az acr login --name acrdevsecops9nsi

# Key Vault
az keyvault show --name kv-devsecops-9nsi --query "{name:name, uri:properties.vaultUri}" -o table

# Stop AKS when done (IMPORTANT — saves ~$30/month)
az aks stop -g rg-devsecops -n aks-devsecops
```
