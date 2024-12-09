output "database_name" {
  value = var.database_config.create_database ? azurerm_postgresql_flexible_server_database.app[0].name : null
}

output "key_vault_id" {
  value = azurerm_key_vault.app_kv.id
}

output "key_vault_name" {
  value = azurerm_key_vault.app_kv.name
}

output "storage_containers" {
  value = var.storage_config.enabled ? azurerm_storage_container.app_container[*].name : null
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "workload_client_id" {
  value = azurerm_user_assigned_identity.workload.client_id
}

output "workload_id" {
  value = azurerm_user_assigned_identity.workload.id
}