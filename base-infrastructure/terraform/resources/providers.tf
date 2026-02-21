provider "azurerm" {
  features {}
}

terraform {
  required_version = "~> 1.14.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.117.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "=2.5.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "=2.24.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.1"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.5"
    }
  }
}
