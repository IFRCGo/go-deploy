# These resources create credentials that can be used in CI Pipelines to push to the registry
resource "azurerm_container_registry_scope_map" "ci" {
  name = "${var.app_name}-${var.environment}-ci-scope-map"

  actions = [
    "repositories/*/content/read",
    "repositories/*/content/write"
  ]

  container_registry_name = azurerm_container_registry.shared.name
  description             = "Scope map for CI push actions"
  resource_group_name     = data.azurerm_resource_group.app_rg.name
}

# Create an ACR token
resource "azurerm_container_registry_token" "ci" {
  name                    = "${var.app_name}-${var.environment}-ci-token"
  container_registry_name = azurerm_container_registry.shared.name
  resource_group_name     = data.azurerm_resource_group.app_rg.name
  scope_map_id            = azurerm_container_registry_scope_map.ci.id
}

# Obtain the username and password for the token
resource "azurerm_container_registry_token_password" "ci" {
  container_registry_token_id = azurerm_container_registry_token.ci.id

  password1 {
  }
}