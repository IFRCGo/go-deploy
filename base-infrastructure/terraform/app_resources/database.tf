resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = var.database_config.database_name
  server_id = var.database_config.server_id
  collation = "en_US.utf8"
  charset   = "utf8"

  lifecycle {
    prevent_destroy = false
  }
}