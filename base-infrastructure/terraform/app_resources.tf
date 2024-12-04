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

locals {
  alerthub_db_name = "alerthubdb"
}

module "alert_hub_resources" {
  source = "./app_resources"

  app_name            = "alert-hub"
  environment         = var.environment
  resource_group_name = module.resources.resource_group

  aks_config = {
    cluster_namespace       = "alert-hub"
    cluster_oidc_issuer_url = module.resources.cluster_oidc_issuer_url
    service_account_name    = "service-token-reader"
  }

  database_config = {
    create_database = true
    database_name   = local.alerthub_db_name
    server_id       = module.resources.alert_hub_db_server_id
  }

  secrets = {
    DB_ADMIN_PASSWORD = module.resources.alert_hub_db_admin_password
    DB_NAME           = local.alerthub_db_name
  }

  storage_config = {
    enabled = true

    container_refs = [
      "media",
      "static"
    ]

    storage_account_id   = module.resources.storage_account_id
    storage_account_name = module.resources.storage_account_name
  }
}