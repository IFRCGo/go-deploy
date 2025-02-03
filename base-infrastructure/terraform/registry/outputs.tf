# Output container registry credentials
output "acr_token_username" {
  value = azurerm_container_registry_token.ci.name
}

output "acr_token_password" {
  value     = azurerm_container_registry_token_password.ci.password1[0].value
  sensitive = true
}

output "registry_server" {
  value = azurerm_container_registry.shared.login_server
}