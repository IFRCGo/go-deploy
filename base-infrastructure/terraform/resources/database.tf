# tflint-ignore: terraform_unused_declarations
data "azurerm_postgresql_flexible_server" "ifrcgo" {
  name                = var.environment == "staging" ? var.ifrcgo_test_resources_db_server : var.ifrcgo_prod_resources_db_server
  resource_group_name = data.azurerm_resource_group.ifrcgo.name
}

# Database for AlertHub
resource "random_password" "alert_hub_db_admin" {
  length  = 16
  special = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_postgresql_flexible_server" "alerthub" {
  name                          = "alerthub-${var.environment}-psql-flexible-server"
  resource_group_name           = data.azurerm_resource_group.ifrcgo.name
  location                      = data.azurerm_resource_group.ifrcgo.location
  version                       = "13"
  administrator_login           = "postgres"
  administrator_password        = random_password.alert_hub_db_admin.result
  auto_grow_enabled             = true
  backup_retention_days         = 35
  sku_name                      = "GP_Standard_D4s_v3"
  delegated_subnet_id           = azurerm_subnet.postgres.id
  private_dns_zone_id           = azurerm_private_dns_zone.ifrcgo.id
  public_network_access_enabled = false
  zone                          = 1

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.ifrcgo
  ]
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "alerthub_db_vnet_rule" {
  name             = "alerthub-${var.environment}-psql-vnet-access-fw-rule"
  server_id        = azurerm_postgresql_flexible_server.alerthub.id
  start_ip_address = cidrhost(azurerm_virtual_network.ifrcgo-cluster.address_space[0], 0)
  end_ip_address   = cidrhost(azurerm_virtual_network.ifrcgo-cluster.address_space[0], -1)
}

# Enable extensions
resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.alerthub.id
  value     = "POSTGIS"
}

# AlertHub Database Configuration Optimizations to allow managing historical data
# For a D2s_v3 (8GB RAM) instance
resource "azurerm_postgresql_flexible_server_configuration" "alerthub_postgres_config" {
  for_each = {
    #    effective_cache_size             = "12288000"   # 12GB - About 75% of total RAM
    #    shared_buffers                   = "2097152"    # 2GB 
    #    work_mem                         = "65536"      # 64MB
    #    maintenance_work_mem             = "1048576"    # 1GB - About 6.4% of RAM
    #    random_page_cost                 = "1.1"        # Lower value for SSD storage
    #    effective_io_concurrency         = "300"        # Higher value for SSD storage
    #    max_parallel_workers             = "4"          # Equal to number of vCPUs
    #    max_parallel_workers_per_gather  = "2"          # Half of max_parallel_workers
  }

  name      = each.key
  server_id = azurerm_postgresql_flexible_server.alerthub.id
  value     = each.value
}

# Database for SDT
resource "random_password" "sdt_db_admin" {
  length  = 16
  special = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_postgresql_flexible_server" "sdt" {
  name                          = "sdt-${var.environment}-psql-flexible-server"
  resource_group_name           = data.azurerm_resource_group.ifrcgo.name
  location                      = data.azurerm_resource_group.ifrcgo.location
  version                       = "14"
  administrator_login           = "postgres"
  administrator_password        = random_password.sdt_db_admin.result
  backup_retention_days         = 35
  storage_mb                    = 32768
  sku_name                      = "GP_Standard_D2ds_v5"
  delegated_subnet_id           = azurerm_subnet.postgres.id
  private_dns_zone_id           = azurerm_private_dns_zone.ifrcgo.id
  public_network_access_enabled = false
  zone                          = 1

  lifecycle {
    ignore_changes = [
      version
    ]
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.ifrcgo
  ]
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "sdt_db_vnet_rule" {
  name             = "sdt-${var.environment}-psql-vnet-access-fw-rule"
  server_id        = azurerm_postgresql_flexible_server.sdt.id
  start_ip_address = cidrhost(azurerm_virtual_network.ifrcgo-cluster.address_space[0], 0)
  end_ip_address   = cidrhost(azurerm_virtual_network.ifrcgo-cluster.address_space[0], -1)
}

# Enable extensions for SDT database
resource "azurerm_postgresql_flexible_server_configuration" "sdt_db_extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.sdt.id
  value     = "CITEXT"
}

# Database for Montandon
resource "random_password" "montandon_db_user" {
  length  = 16
  special = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_postgresql_flexible_server" "montandon" {
  name                          = "montandon-${var.environment}-psql-flexible-server"
  resource_group_name           = data.azurerm_resource_group.ifrcgo.name
  location                      = data.azurerm_resource_group.ifrcgo.location
  version                       = "16"
  administrator_login           = "postgres"
  administrator_password        = random_password.montandon_db_user.result
  backup_retention_days         = 35
  storage_mb                    = 32768
  sku_name                      = "GP_Standard_D2ds_v5"
  delegated_subnet_id           = azurerm_subnet.postgres.id
  private_dns_zone_id           = azurerm_private_dns_zone.ifrcgo.id
  public_network_access_enabled = false
  zone                          = 1

  lifecycle {
    ignore_changes = [
      version
    ]
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.ifrcgo
  ]
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "montandon_db_vnet_rule" {
  name             = "montandon-${var.environment}-psql-vnet-access-fw-rule"
  server_id        = azurerm_postgresql_flexible_server.montandon.id
  start_ip_address = cidrhost(azurerm_virtual_network.ifrcgo-cluster.address_space[0], 0)
  end_ip_address   = cidrhost(azurerm_virtual_network.ifrcgo-cluster.address_space[0], -1)
}

# Enable extensions for montandon-etl db
resource "azurerm_postgresql_flexible_server_configuration" "montandon_db_extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.montandon.id
  value     = "POSTGIS"
}

resource "random_password" "montandon_eoapi_db_user" {
  length  = 16
  special = true

  lifecycle {
    create_before_destroy = true
  }
}


# Database server and instance for montandon eoAPI
resource "azurerm_postgresql_flexible_server" "montandon_eoapi" {
  name                          = "montandon-eoapi-${var.environment}-psql-flexible-server"
  resource_group_name           = data.azurerm_resource_group.ifrcgo.name
  location                      = data.azurerm_resource_group.ifrcgo.location
  version                       = "16"
  administrator_login           = "postgres"
  administrator_password        = random_password.montandon_eoapi_db_user.result
  backup_retention_days         = 35
  auto_grow_enabled             = true
  sku_name                      = "GP_Standard_D2ds_v5"
  delegated_subnet_id           = azurerm_subnet.postgres.id
  private_dns_zone_id           = azurerm_private_dns_zone.ifrcgo.id
  public_network_access_enabled = false
  zone                          = 1

  lifecycle {
    ignore_changes = [
      version
    ]
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.ifrcgo
  ]
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "montandon_eoapi_db_vnet_rule" {
  name             = "montandon-eoapi-${var.environment}-psql-vnet-access-fw-rule"
  server_id        = azurerm_postgresql_flexible_server.montandon_eoapi.id
  start_ip_address = cidrhost(azurerm_virtual_network.ifrcgo-cluster.address_space[0], 0)
  end_ip_address   = cidrhost(azurerm_virtual_network.ifrcgo-cluster.address_space[0], -1)
}

# Enable extensions for montandon-eoapi db
resource "azurerm_postgresql_flexible_server_configuration" "montandon_eoapi_db_extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.montandon_eoapi.id
  value     = "POSTGIS"
}
