resource "azurerm_storage_account" "ifrcgo" {
  name                     = "${local.storage}"
  resource_group_name      = data.azurerm_resource_group.ifrcgo.name
  location                 = data.azurerm_resource_group.ifrcgo.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "data" {
  name                  = "dsgoapikey"
  storage_account_name  = azurerm_storage_account.ifrcgo.name
  container_access_type = "private"
}

resource "random_integer" "sdt_storage_account_suffix" {
  min = 1000
  max = 9999
}

resource "azurerm_storage_account" "sdt" {
  name                     = "sdt${var.environment}${random_integer.sdt_storage_account_suffix.result}"
  resource_group_name      = data.azurerm_resource_group.ifrcgo.name
  location                 = data.azurerm_resource_group.ifrcgo.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "random_integer" "montandon_storage_account_suffix" {
  min = 1000
  max = 9999
}

resource "azurerm_storage_account" "montandon" {
  name                     = "monty${var.environment}${random_integer.montandon_storage_account_suffix.result}"
  resource_group_name      = data.azurerm_resource_group.ifrcgo.name
  location                 = data.azurerm_resource_group.ifrcgo.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}