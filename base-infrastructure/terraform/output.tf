output "alert_hub_app_resource_details" {
  value = {
    key_vault_name = module.alert_hub_resources.key_vault_name
    workload_id    = module.alert_hub_resources.workload_client_id
    tenant_id      = module.alert_hub_resources.tenant_id
    storage_containers = module.alert_hub_resources.storage_containers
  }
}

output "risk_module_app_resource_details" {
  value = {
    key_vault_name = module.risk_module_resources.key_vault_name
    workload_id    = module.risk_module_resources.workload_client_id
    tenant_id      = module.risk_module_resources.tenant_id
  }
}