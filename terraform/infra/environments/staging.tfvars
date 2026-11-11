# =============================================================================
# Staging Environment — EXISTS TO SHOW THE PATTERN
#
# In production: staging = separate AKS cluster (separate RG, VNet, node pool).
# In this portfolio: staging deploys to SAME AKS cluster, different Helm
# namespace (staging) + values-staging.yaml. Keeps cost under ₹100.
#
# This file is NOT used by the pipeline — exists for completeness.
# =============================================================================

project_name           = "atlas-05"
environment            = "staging"
location               = "centralindia"
aks_kubernetes_version = "1.36.5" # VERIFY: az aks get-versions --location centralindia --output table

aks_node_count  = 1
aks_node_size   = "Standard_B2s"
os_disk_size_gb = 30

tags = {
  project     = "atlas-05-gha-oidc"
  environment = "staging"
  team        = "platform"
  cost-center = "atlas-portfolio"
  created-by  = "terraform"
  managed-by  = "github-actions"
  destroy-by  = "end-of-day"
}