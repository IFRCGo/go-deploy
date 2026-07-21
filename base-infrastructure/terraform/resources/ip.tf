resource "azurerm_public_ip" "ifrcgo" {
  lifecycle {
    ignore_changes = all
  }
  name                = "${local.prefix}PublicIP"
  resource_group_name = data.azurerm_resource_group.ifrcgo.name
  location            = data.azurerm_resource_group.ifrcgo.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = var.environment
  }
}

# Traefik Public IP
resource "azurerm_public_ip" "traefik" {

  name                = "${local.prefix}TraefikPublicIP"
  resource_group_name = data.azurerm_resource_group.ifrcgo.name
  location            = data.azurerm_resource_group.ifrcgo.location

  allocation_method = "Static"
  sku               = "Standard"

  tags = {
    Environment = var.environment
  }
}

# SSH bastion Public IP (see bastion.tf) — reserved so the bastion endpoint is
# stable across recreations (fixed IP / DNS can be put in front later).
resource "azurerm_public_ip" "bastion" {
  name                = "${local.prefix}-bastion-PublicIP"
  resource_group_name = data.azurerm_resource_group.ifrcgo.name
  location            = data.azurerm_resource_group.ifrcgo.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = var.environment
  }
}
