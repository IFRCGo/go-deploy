output "alert_hub_app_resource_details" {
  value = {
    database_name      = module.alert_hub_resources.database_name
    key_vault_name     = module.alert_hub_resources.key_vault_name
    storage_containers = module.alert_hub_resources.storage_containers
    tenant_id          = module.alert_hub_resources.tenant_id
    workload_id        = module.alert_hub_resources.workload_client_id
  }
}

output "risk_module_app_resource_details" {
  value = {
    database_name      = module.risk_module_resources.database_name
    key_vault_name     = module.risk_module_resources.key_vault_name
    storage_containers = module.risk_module_resources.storage_containers
    tenant_id          = module.risk_module_resources.tenant_id
    workload_id        = module.risk_module_resources.workload_client_id
  }
}

output "sdt_app_resource_details" {
  value = {
    key_vault_name     = module.sdt_resources.key_vault_name
    workload_id        = module.sdt_resources.workload_client_id
  }
}

output "motandon_etl_app_resource_details" {
  value = {
    key_vault_name     = module.montandon_etl_resources.key_vault_name
    workload_id        = module.montandon_etl_resources.workload_client_id
  }
}