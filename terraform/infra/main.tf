# =============================================================================
# Atlas-05 Infrastructure — AKS + ACR via atlas-infra-base
# =============================================================================
# Phase 2: Runs from GitHub Actions using OIDC credential (Phase 1).
# Separate state from OIDC bootstrap (atlas-05.tfstate vs atlas-05-oidc.tfstate).
#
# P4 retro fixes applied:
#   - Provider: azurerm ~> 4.14 (matches atlas-infra-base)
#   - Module vars: aks_kubernetes_version, aks_node_count, aks_node_size
#     (NOT kubernetes_version, node_count, node_vm_size)
# =============================================================================

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-atlas-tfstate"
    storage_account_name = "atlastfstate2606"
    container_name       = "tfstate"
    key                  = "atlas-05.tfstate"
    use_oidc             = true
  }
}

provider "azurerm" {
  features {}
  use_oidc        = true
  subscription_id = var.subscription_id
}

# -----------------------------------------------------------------------------
# Infrastructure Module
# Source: github.com/manoj-2606/atlas-infra-base
# Provisions: Resource Group, VNet, AKS (1 node B2s), ACR (Basic)
# -----------------------------------------------------------------------------
module "infra" {
  source = "git::https://github.com/manoj-2606/atlas-infra-base.git"

  project_name           = var.project_name
  environment            = var.environment
  location               = var.location
  aks_kubernetes_version = var.aks_kubernetes_version
  aks_node_count         = var.aks_node_count
  aks_node_size          = var.aks_node_size
  os_disk_size_gb        = var.os_disk_size_gb
  tags                   = var.tags
}