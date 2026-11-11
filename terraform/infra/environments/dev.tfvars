# =============================================================================
# Dev Environment — PRIMARY environment for P5
# Staging deploys to same cluster, different Helm namespace.
# =============================================================================

project_name           = "atlas-05"
environment            = "dev"
location               = "centralindia"
aks_kubernetes_version = "1.4" # VERIFY: az aks get-versions --location centralindia --output table

# FinOps: Right-sized for portfolio demo
aks_node_count  = 1
aks_node_size   = "Standard_B2s" # ~$0.04/hr — cheapest viable for AKS
os_disk_size_gb = 30             # Minimum viable — no overprovisioning

# FinOps: Every resource tagged for cost attribution
tags = {
  project     = "atlas-05-gha-oidc"
  environment = "dev"
  team        = "platform"
  cost-center = "atlas-portfolio"
  created-by  = "terraform"
  managed-by  = "github-actions"
  destroy-by  = "end-of-day"
}