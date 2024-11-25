variable "app_name" {
  description = "The application name for which the module resources are being created"
  type = string
}

variable "aks_config" {
  description = "Configuration for the Azure Kubernetes Service (AKS) deployment."

  type = object(
    {
      cluster_namespace       = string
      cluster_oidc_issuer_url = string
      service_account_name    = string
    }
  )

  default = {
    cluster_namespace       = null
    cluster_oidc_issuer_url = null
    service_account_name    = "service-token-reader"
  }
}

variable "environment" {
  description = "The deployment environment (production, staging, or sandbox)"
  type = string
}

variable "key_vault_network_acls" {
  description = "Configuration for network ACLs"

  type = object(
    {
      default_action             = string
      bypass                     = string
      ip_rules                   = list(string)
      virtual_network_subnet_ids = list(string)
    }
  )

  default = {
    default_action             = "Allow"
    bypass                     = "AzureServices"
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }
}

variable "resource_group_name" {
  type = string
}

variable "secrets" {
  type    = map(string)
  default = {}
}