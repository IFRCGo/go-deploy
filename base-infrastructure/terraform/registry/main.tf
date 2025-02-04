resource "azurerm_container_registry" "shared" {
  name                = "${title(var.app_name)}${title(var.environment)}ContainerRegistry"
  resource_group_name = data.azurerm_resource_group.app_rg.name
  location            = data.azurerm_resource_group.app_rg.location
  sku                 = var.registry_sku
}