# Add a secret to the Key Vault
resource "azurerm_key_vault_secret" "secret_" {
  for_each     = var.secrets
  name         = replace(each.key, "_", "-")
  value        = each.value
  key_vault_id = azurerm_key_vault.app_kv.id

  # Ensure secrets are deleted before creating identity loses permission to do so
  depends_on = [
    azurerm_role_assignment.key_vault_admin,
  ]

  lifecycle {
    ignore_changes = all
  }
}