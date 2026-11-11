# =============================================================================
# OIDC Bootstrap — App Registration + Federated Credentials + Role Assignment
# =============================================================================
# Purpose: Create the trust between GitHub Actions and Azure.
#          Run ONCE from ADO using MI-ADO-API service connection.
#          After this, GitHub Actions can authenticate to Azure via OIDC.
# =============================================================================

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-atlas-tfstate"
    storage_account_name = "atlastfstate2606"
    container_name       = "tfstate"
    key                  = "atlas-05-oidc.tfstate"
    use_oidc             = true
  }
}

provider "azurerm" {
  features {}
  use_oidc = true
}

provider "azuread" {
  use_oidc = true
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

# Current Azure subscription details
data "azurerm_subscription" "current" {}

# Current Entra ID client config (tenant ID, object ID)
data "azuread_client_config" "current" {}

# -----------------------------------------------------------------------------
# App Registration
# -----------------------------------------------------------------------------
# This is the identity that GitHub Actions will authenticate as.
# Think of it as a "service account" for GHA — but with no password.

resource "azuread_application" "gha_oidc" {
  display_name = var.app_registration_name

  tags = ["atlas-platform", "github-actions", "oidc"]
}

# Service Principal — the "instance" of the App Registration in this tenant
resource "azuread_service_principal" "gha_oidc" {
  client_id = azuread_application.gha_oidc.client_id
}

# -----------------------------------------------------------------------------
# Federated Identity Credentials (3 total)
# -----------------------------------------------------------------------------
# Each credential trusts a specific GitHub context.
# Production-grade: no wildcard (*). Each context is explicitly trusted.

# 1. Main branch — for CI/CD runs triggered by push to main
resource "azuread_application_federated_identity_credential" "main_branch" {
  application_id = azuread_application.gha_oidc.id
  display_name   = "github-main-branch"
  description    = "Trust GitHub Actions on main branch of ${var.github_repo}"

  audiences = ["api://AzureADTokenExchange"]
  issuer    = "https://token.actions.githubusercontent.com"
  subject   = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
}

# 2. Dev environment — for deployments to atlas-05-dev GitHub Environment
resource "azuread_application_federated_identity_credential" "env_dev" {
  application_id = azuread_application.gha_oidc.id
  display_name   = "github-env-dev"
  description    = "Trust GitHub Actions dev environment of ${var.github_repo}"

  audiences = ["api://AzureADTokenExchange"]
  issuer    = "https://token.actions.githubusercontent.com"
  subject   = "repo:${var.github_org}/${var.github_repo}:environment:atlas-05-dev"
}

# 3. Staging environment — for deployments to atlas-05-staging GitHub Environment
resource "azuread_application_federated_identity_credential" "env_staging" {
  application_id = azuread_application.gha_oidc.id
  display_name   = "github-env-staging"
  description    = "Trust GitHub Actions staging environment of ${var.github_repo}"

  audiences = ["api://AzureADTokenExchange"]
  issuer    = "https://token.actions.githubusercontent.com"
  subject   = "repo:${var.github_org}/${var.github_repo}:environment:atlas-05-staging"
}

# -----------------------------------------------------------------------------
# Role Assignment — Contributor on Subscription
# -----------------------------------------------------------------------------
# The service principal needs Contributor to create RGs, VNets, AKS, ACR.
# Scoped to subscription (not Management Group) — standard for portfolio projects.

resource "azurerm_role_assignment" "gha_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.gha_oidc.object_id

  # Skip check avoids race condition where SP isn't fully replicated yet
  skip_service_principal_aad_check = true
}