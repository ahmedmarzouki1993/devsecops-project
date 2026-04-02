# Phase 1 — Terraform Infrastructure

> **Status:** Ready to apply
> **Goal:** Provision all Azure infrastructure using Terraform (IaC)
> **Estimated cost:** ~$36/month running | ~$6/month with AKS stopped

---

## What was built

### Files created

| File | Purpose |
|------|---------|
| `terraform/providers.tf` | Terraform version + azurerm provider with OIDC auth |
| `terraform/backend.tf` | Remote state in Azure Storage (not local) |
| `terraform/variables.tf` | All input variables with types, descriptions, validation |
| `terraform/main.tf` | All Azure resources (RG, ACR, AKS, Key Vault, role assignments) |
| `terraform/outputs.tf` | Values printed after apply (ACR URL, cluster name, KV URI) |
| `terraform/terraform.tfvars.example` | Template for your personal `.tfvars` (never committed) |
| `terraform/.gitignore` | Protects state, tfvars, .terraform/ from git |
| `scripts/bootstrap-tf-state.sh` | One-time script to create the storage for Terraform state |

---

## Azure resources created by `terraform apply`

| Resource | Name | Why it exists |
|----------|------|---------------|
| Resource Group | `rg-devsecops` | Container for all project resources |
| Container Registry | `acrdevsecops<suffix>` | Stores Docker images built by GitLab CI |
| AKS Cluster | `aks-devsecops` | Kubernetes cluster that runs the 3-tier app |
| Key Vault | `kv-devsecops-<suffix>` | Stores secrets (DB password, Slack webhooks, TLS certs) |
| Role: AcrPull | AKS kubelet → ACR | Lets AKS pull images without imagePullSecrets |
| Role: KV Secrets User | AKS identity → KV | Lets pods read secrets from Key Vault (Phase 6) |
| Role: KV Administrator | Terraform runner → KV | Lets CI pipeline write secrets during apply |

> **Separate state storage** (created by bootstrap script):
> | Resource | Name |
> |----------|------|
> | Resource Group | `rg-devsecops-state` |
> | Storage Account | `stdevsecopsstate` |
> | Blob Container | `tfstate` |

---

## Architecture decisions explained

### Why OIDC auth (no client_secret)?
Azure Student Pack does not support creating Service Principals with Active Directory app registrations that have `client_secret`. OIDC (OpenID Connect) solves this:
- GitLab CI generates a short-lived signed token per job
- Azure validates the token against the GitLab OIDC issuer
- No password ever stored anywhere

### Why remote state in Azure Storage?
Local state = lost if laptop dies. Remote state in Azure Storage gives you:
- **Durability**: 99.9999999% — 3 copies in the same datacenter
- **Locking**: Azure Blob leases prevent two `terraform apply` runs simultaneously
- **History**: Blob versioning keeps last 7 days of state (disaster recovery)

### Why SystemAssigned Managed Identity for AKS?
Service principals require storing a `client_secret` — it expires, must be rotated, can leak. SystemAssigned Managed Identity = Azure creates and rotates the credential automatically. The identity lives and dies with the AKS cluster.

### Why OIDC issuer + Workload Identity enabled on AKS?
These are needed in Phase 6 for the Key Vault CSI driver. Enabling now costs nothing and prevents rebuilding the cluster later. The OIDC issuer URL is an output so Phase 6 can use it directly.

### Why `Standard_B2s` node?
- 2 vCPU, 4GB RAM — minimum viable for K8s system pods + your 3-tier app
- Burstable: earns CPU credits when idle, spends them on spikes
- ~$30/month — fits Azure Student $100 budget with room for ACR (~$5) and Key Vault (~$1)
- **Always stop AKS when not using it**: `az aks stop -g rg-devsecops -n aks-devsecops`

---

## How to run Phase 1

### Prerequisites
- `az login` completed
- Terraform `v1.14.7` installed ✅
- Azure CLI `2.84.0` installed ✅

### Step 1 — Bootstrap state storage (run once)
```bash
chmod +x scripts/bootstrap-tf-state.sh
./scripts/bootstrap-tf-state.sh
```
This creates `rg-devsecops-state` and `stdevsecopsstate` storage account.

### Step 2 — Configure your variables
```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
```
Edit `terraform.tfvars` — set your real `subscription_id`:
```bash
# Get your subscription ID:
az account show --query id -o tsv
```

### Step 3 — Initialize Terraform (downloads providers)
```bash
terraform init
```
Expected output: `Terraform has been successfully initialized!`

### Step 4 — Plan (review what will be created — NO changes yet)
```bash
terraform plan -out=tfplan
```
Review the plan. You should see **+7 resources to add**, 0 to change, 0 to destroy.

### Step 5 — Apply (create the real resources)
```bash
terraform apply tfplan
```
Takes ~8-12 minutes (AKS provisioning is the slowest step).

### Step 6 — Get credentials and verify
```bash
# Get kubectl credentials
az aks get-credentials -g rg-devsecops -n aks-devsecops

# Verify cluster is running
kubectl get nodes

# Check all outputs
terraform output
```

---

## Expected outputs after apply

```
aks_cluster_name           = "aks-devsecops"
aks_oidc_issuer_url        = "https://oidc.prod-aks.azure.com/..."
acr_login_server           = "acrdevsecopsab12.azurecr.io"
acr_name                   = "acrdevsecopsab12"
key_vault_name             = "kv-devsecops-ab12"
key_vault_uri              = "https://kv-devsecops-ab12.vault.azure.net/"
resource_group_name        = "rg-devsecops"
location                   = "uaenorth"
gitlab_ci_variables        = {
  ACR_LOGIN_SERVER     = "acrdevsecopsab12.azurecr.io"
  AKS_CLUSTER_NAME     = "aks-devsecops"
  AZURE_RESOURCE_GROUP = "rg-devsecops"
  KEY_VAULT_NAME       = "kv-devsecops-ab12"
  KEY_VAULT_URI        = "https://kv-devsecops-ab12.vault.azure.net/"
}
```

---

## GitLab CI variables to set after apply

Go to: GitLab → Settings → CI/CD → Variables → Add variable

| Variable | Where to get value | Masked? |
|----------|-------------------|---------|
| `AZURE_CLIENT_ID` | App Registration client ID (OIDC setup) | Yes |
| `AZURE_TENANT_ID` | `az account show --query tenantId -o tsv` | Yes |
| `AZURE_SUBSCRIPTION_ID` | `az account show --query id -o tsv` | Yes |
| `ACR_LOGIN_SERVER` | `terraform output -raw acr_login_server` | No |
| `AKS_CLUSTER_NAME` | `terraform output -raw aks_cluster_name` | No |
| `AZURE_RESOURCE_GROUP` | `terraform output -raw resource_group_name` | No |
| `KEY_VAULT_NAME` | `terraform output -raw key_vault_name` | No |

---

## Cost control

```bash
# STOP AKS when done (saves ~$30/month while stopped — you only pay for disk)
az aks stop -g rg-devsecops -n aks-devsecops

# START AKS when working
az aks start -g rg-devsecops -n aks-devsecops

# Check current AKS state
az aks show -g rg-devsecops -n aks-devsecops --query powerState.code -o tsv
```

Monthly cost breakdown:
| Resource | Running | Stopped |
|----------|---------|---------|
| AKS node (B2s) | ~$30 | ~$2 (disk only) |
| ACR Basic | ~$5 | ~$5 |
| Key Vault | ~$0.03 | ~$0.03 |
| Storage (state) | ~$0.01 | ~$0.01 |
| **Total** | **~$35** | **~$7** |

---

## Common errors and fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `Provider not registered` | Azure RP not enabled | `az provider register --namespace Microsoft.ContainerService` |
| `ACR name already taken` | Name is globally unique | Change `project_name` in tfvars or add a digit |
| `Quota exceeded` | Student subscription limits | Try `eastus` region or a smaller VM |
| `State locked` | Previous apply crashed | `terraform force-unlock <LOCK_ID>` |
| `soft-deleted vault` | KV with same name was deleted | `terraform apply` recovers it (recover_soft_deleted_key_vaults = true) |

---

## Next phase

After Phase 1 completes, Phase 2 finishes:
- Build Docker images for backend and frontend
- Push images to the ACR you just created
- Test locally with `docker-compose`

```bash
# Tag and push after ACR is created
ACR=$(terraform output -raw acr_login_server)
az acr login --name $(terraform output -raw acr_name)
docker build -t $ACR/backend:dev ./app/backend/
docker push $ACR/backend:dev
```
