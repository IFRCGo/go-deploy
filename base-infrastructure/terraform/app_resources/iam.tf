# Grant the user applying the infra changes administrative rights on the vault
resource "azurerm_role_assignment" "key_vault_admin" {
  scope                = azurerm_key_vault.app_kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Create an IAM identity that will be used by the application
resource "azurerm_user_assigned_identity" "workload" {
  name                = "${replace(title(var.app_name), "-", "")}${title(var.environment)}WorkloadIdentity"
  location            = data.azurerm_resource_group.app_rg.location
  resource_group_name = data.azurerm_resource_group.app_rg.name
}

# Grant application IAM identity permission to access secrets
resource "azurerm_role_assignment" "key_vault_reader" {
  scope                = azurerm_key_vault.app_kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}

# Configures a federated identity credential for Azure AD, enabling workload identities (such as Kubernetes service accounts)
# to authenticate to Azure resources using OIDC (OpenID Connect). This allows a specific service account in the cluster to assume
# the user-assigned managed identity without needing a secret, improving security and enabling fine-grained access control.
#
# - `audience`: Specifies the token audience (Azure AD's token exchange endpoint in this case).
# - `issuer`: URL of the OIDC issuer from the Kubernetes cluster (for validating identity tokens).
# - `subject`: The Kubernetes service account that will be associated with the Azure managed identity.
resource "azurerm_federated_identity_credential" "cred" {
  name                = "${var.app_name}-${var.environment}-secret-reader-identity"
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_config.cluster_oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.workload.id
  resource_group_name = var.resource_group_name
  subject             = "system:serviceaccount:${var.aks_config.cluster_namespace}:${var.aks_config.service_account_name}"
}

# Grant app developers administrative rights on the vault
resource "azurerm_role_assignment" "key_vault_devs" {
  count                = length(var.vault_admin_ids)
  scope                = azurerm_key_vault.app_kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.vault_admin_ids[count.index]
}