# =============================================================================
# Outputs — Copy these values into GitHub Repository Secrets
# =============================================================================
# After running this Terraform:
#   1. Go to GitHub → atlas-05-gha-oidc → Settings → Secrets → Actions
#   2. Create 3 repository secrets with these exact names and values:
#      - AZURE_CLIENT_ID
#      - AZURE_TENANT_ID
#      - AZURE_SUBSCRIPTION_ID
# =============================================================================

output "azure_client_id" {
  description = "App Registration Client ID → GitHub Secret: AZURE_CLIENT_ID"
  value       = azuread_application.gha_oidc.client_id
}

output "azure_tenant_id" {
  description = "Entra ID Tenant ID → GitHub Secret: AZURE_TENANT_ID"
  value       = data.azuread_client_config.current.tenant_id
}

output "azure_subscription_id" {
  description = "Azure Subscription ID → GitHub Secret: AZURE_SUBSCRIPTION_ID"
  value       = data.azurerm_subscription.current.subscription_id
}

output "service_principal_object_id" {
  description = "Service Principal Object ID (for troubleshooting role assignments)"
  value       = azuread_service_principal.gha_oidc.object_id
}

output "federated_credentials" {
  description = "Federated credentials created (for verification)"
  value = {
    main_branch = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
    env_dev     = "repo:${var.github_org}/${var.github_repo}:environment:atlas-05-dev"
    env_staging = "repo:${var.github_org}/${var.github_repo}:environment:atlas-05-staging"
  }
}