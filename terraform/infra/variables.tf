# =============================================================================
# Variables — OIDC Bootstrap
# =============================================================================

variable "app_registration_name" {
  description = "Display name for the App Registration in Entra ID"
  type        = string
  default     = "atlas-05-gha-oidc-sp"
}

variable "github_org" {
  description = "GitHub organization or username"
  type        = string
  default     = "manoj-2606"
}

variable "github_repo" {
  description = "GitHub repository name (without org prefix)"
  type        = string
  default     = "atlas-05-gha-oidc"
}