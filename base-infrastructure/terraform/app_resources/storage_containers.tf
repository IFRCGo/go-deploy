# Create Container
resource "azurerm_storage_container" "app_container" {
  count = var.storage_config.enabled ? length(var.storage_config.container_refs) : 0

  name                  = lower("${var.app_name}-${var.environment}-${var.storage_config.container_refs[count.index]}-container")
  storage_account_name  = var.storage_config.storage_account_name
  container_access_type = "private"
}

# Grant workload identity access to container
resource "azurerm_role_assignment" "storage_blob_reader" {
  count = var.storage_config.enabled ? length(var.storage_config.container_refs) : 0

  scope                = "${var.storage_config.storage_account_id}/blobServices/default/containers/${azurerm_storage_container.app_container[count.index].name}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}