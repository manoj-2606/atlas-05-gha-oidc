# =============================================================================
# Input Variables — Infra
# Values provided via environments/*.tfvars
# Variable names match atlas-infra-base/variables.tf exactly
# =============================================================================

variable "subscription_id" {
  description = "Azure Subscription ID — required by azurerm v4.x provider"
  type        = string
}

variable "project_name" {
  description = "Project identifier used in resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging)"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  # No default — must be explicit in tfvars
}

variable "aks_kubernetes_version" {
  description = "AKS Kubernetes version — ALWAYS verify: az aks get-versions --location centralindia"
  type        = string
  # No default — versions deprecate. Must be set in tfvars and verified per run.
}

variable "aks_node_count" {
  description = "Number of AKS worker nodes"
  type        = number
  default     = 1
}

variable "aks_node_size" {
  description = "AKS node VM SKU — B2s for non-prod (FinOps: ~$0.04/hr)"
  type        = string
  default     = "Standard_B2s"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB — 30GB minimum viable (FinOps: no overprovisioning)"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Resource tags for cost attribution and lifecycle management"
  type        = map(string)
  default     = {}
}