resource "azurerm_kubernetes_cluster" "ifrcgo" {
  #  lifecycle {
  #    ignore_changes = all
  #  }

  name                = "${local.prefix}-cluster"
  location            = data.azurerm_resource_group.ifrcgo.location
  resource_group_name = data.azurerm_resource_group.ifrcgo.name
  dns_prefix          = "${local.prefix}-cluster"

  # XXX: Make sure to user azure supported versions
  # https://releases.aks.azure.com/
  # https://endoflife.date/azure-kubernetes-service
  # renovate: datasource=github-tags depName=kubernetes/kubernetes
  kubernetes_version = "1.37.0"

  default_node_pool {
    name                        = "nodepool1"
    vm_size                     = "Standard_D8s_v5"
    vnet_subnet_id              = azurerm_subnet.aks.id
    enable_auto_scaling         = true
    min_count                   = 1
    max_count                   = var.environment == "staging" ? 3 : 4
    temporary_name_for_rotation = "nodepooltemp"

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "IFRCGo"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = var.secret_rotation_interval
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true
}

# add the role to the identity the kubernetes cluster was assigned
resource "azurerm_role_assignment" "network" {
  scope                = data.azurerm_resource_group.ifrcgo.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.ifrcgo.identity[0].principal_id
}

resource "azurerm_role_assignment" "storage" {
  scope                = data.azurerm_resource_group.ifrcgo.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_kubernetes_cluster.ifrcgo.identity[0].principal_id
}

# Kubernetes provider. No resource in this configuration uses it, and it cannot be deleted
# while an orphaned kubernetes_* resource is still in state. This block sits inside a child
# module, so its provider address cannot be implied; destroying such an orphan without it
# fails with "Provider configuration not present".
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.ifrcgo.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.ifrcgo.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.ifrcgo.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.ifrcgo.kube_config[0].cluster_ca_certificate)
}
