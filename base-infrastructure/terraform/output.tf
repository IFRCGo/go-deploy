output "alert_hub_app_resource_details" {
  value = {
    key_vault_name = module.alert_hub_resources.key_vault_name
    workload_id    = module.alert_hub_resources.workload_id
    tenant_id      = module.alert_hub_resources.tenant_id
  }
}

output "risk_module_app_resource_details" {
  value = {
    key_vault_name = module.risk_module_resources.key_vault_name
    workload_id    = module.risk_module_resources.workload_id
    tenant_id      = module.risk_module_resources.tenant_id
  }
}