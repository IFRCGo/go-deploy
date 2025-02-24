provider azurerm {
  features {}
}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.117.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "=2.5.1"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "=2.24.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.1"
    }
  }
}