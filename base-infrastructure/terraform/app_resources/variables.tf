variable "app_name" {
  description = "The application name for which the module resources are being created"
  type        = string
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

variable "database_config" {
  description = "Configuration for the application database"

  type = object(
    {
      create_database = bool
      database_name   = string
      server_id       = string
    }
  )

  default = {
    create_database = false
    database_name   = null
    server_id       = null
  }
}

variable "environment" {
  description = "The deployment environment (production, staging, or sandbox)"
  type        = string
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

variable "storage_config" {
  description = "Configuration for the application storage containers"

  type = object(
    {
      enabled              = bool
      storage_account_id   = any
      storage_account_name = any
      container_refs       = list(string)
    }
  )

  default = {
    enabled              = false
    storage_account_id   = null
    storage_account_name = null
    container_refs       = []
  }
}