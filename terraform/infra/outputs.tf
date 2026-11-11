# =============================================================================
# Outputs — Saved to tf-outputs.json via infra.sh
# Uploaded as GitHub artifact. Downloaded by build + deploy jobs.
# Same pattern as P4 pipeline artifacts, different platform.
# =============================================================================

output "resource_group_name" {
  description = "Resource group containing all project resources"
  value       = module.infra.resource_group_name
}

output "acr_login_server" {
  description = "ACR login server URL (e.g., acratlas05dev.azurecr.io)"
  value       = module.infra.acr_login_server
}

output "acr_name" {
  description = "ACR name for az acr login command"
  value       = module.infra.acr_name
}

output "aks_cluster_name" {
  description = "AKS cluster name for az aks get-credentials"
  value       = module.infra.aks_cluster_name
}

output "kube_config_raw" {
  description = "Raw kubeconfig — sensitive, excluded from tf-outputs.json"
  value       = module.infra.kube_config_raw
  sensitive   = true
}