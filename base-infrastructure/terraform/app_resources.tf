module "risk_module_resources" {
  source = "./app_resources"

  aks_config = {
    cluster_namespace       = "risk-module"
    cluster_oidc_issuer_url = module.resources.cluster_oidc_issuer_url
    service_account_name    = "service-token-reader"
  }

  app_name            = "risk-module"
  environment         = var.environment
  resource_group_name = module.resources.resource_group
}

module "alert_hub_resources" {
  source = "./app_resources"

  aks_config = {
    cluster_namespace       = "alert-hub"
    cluster_oidc_issuer_url = module.resources.cluster_oidc_issuer_url
    service_account_name    = "service-token-reader"
  }

  app_name            = "alert-hub"
  environment         = var.environment
  resource_group_name = module.resources.resource_group
}