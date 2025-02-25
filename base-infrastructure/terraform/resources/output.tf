output "alert_hub_db_admin_password" {
  value = random_password.alert_hub_db_admin.result
}

output "alert_hub_db_server_id" {
  value = azurerm_postgresql_flexible_server.alerthub.id 
}

output "environment" {
  value = var.environment
}

output "location" {
  value = local.location
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.ifrcgo.name
}

output "cluster_oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.ifrcgo.oidc_issuer_url
}

output "cluster_kubelet_identity" {
  value = azurerm_kubernetes_cluster.ifrcgo.kubelet_identity[0].object_id
}

output "resource_group" {
  value = data.azurerm_resource_group.ifrcgo.name
}

output "image_registry" {
  value = data.azurerm_container_registry.ifrcgo.name
}

output "azure_storage_name" {
  value = azurerm_storage_account.ifrcgo.id
}

output "azure_strorage_key" {
  value = azurerm_storage_account.ifrcgo.primary_access_key
}

output "azure_storage_connection_string" {
  value = azurerm_storage_account.ifrcgo.primary_connection_string
}

# Montandon DB Details
output "montandon_db_user_password" {
  value = random_password.montandon_db_user.result
}

output "montandon_db_host" {
  value = azurerm_postgresql_flexible_server.montandon.fqdn
}

output "montandon_db_server_id" {
  value = azurerm_postgresql_flexible_server.montandon.id 
}

# SDT DB Details
output "sdt_db_admin_password" {
  value = random_password.sdt_db_admin.result
}

output "sdt_db_host" {
  value = azurerm_postgresql_flexible_server.sdt.fqdn
}

output "sdt_db_server_id" {
  value = azurerm_postgresql_flexible_server.sdt.id 
}

output "storage_account_name" {
  value = azurerm_storage_account.ifrcgo.name 
}

output "storage_account_id" {
  value = azurerm_storage_account.ifrcgo.id
}