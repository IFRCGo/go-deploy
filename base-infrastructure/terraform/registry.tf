module "go_shared_registry" {
  source      = "./registry"
  app_name    = "ifrcgo"
  environment = var.environment

  pull_principal_ids = [
    module.resources.cluster_kubelet_identity
  ]

  registry_sku        = "Standard"
  resource_group_name = module.resources.resource_group
}