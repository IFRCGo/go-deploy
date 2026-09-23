# Monitoring -----------------------------------------

locals {
  # Pinned as `serviceAccount.name` in the loki argocd application. The chart's
  # default name changed between 6.28 and 6.55, so the subject below sets it
  # explicitly rather than tracking whatever the chart happens to generate.
  loki_service_account = "monitoring-loki"
}

# Backs Loki's chunks and tsdb index. Keeping them here instead of on a cluster PVC
# means retention is bounded by blob cost rather than disk size.
#
# Unlike the app storage accounts in storage.tf this one carries no random suffix:
# the name is hardcoded in the loki argocd application, which cannot read terraform
# outputs.
resource "azurerm_storage_account" "monitoring" {
  name                     = "${local.prefix}aksmonitoring"
  resource_group_name      = data.azurerm_resource_group.ifrcgo.name
  location                 = data.azurerm_resource_group.ifrcgo.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "loki_chunks" {
  name                  = "loki-chunks"
  storage_account_name  = azurerm_storage_account.monitoring.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "loki_ruler" {
  name                  = "loki-ruler"
  storage_account_name  = azurerm_storage_account.monitoring.name
  container_access_type = "private"
}

# Chunks are written once and read rarely after the first weeks, so they tier down.
# Cool and Cold are both online, no rehydration, only a higher per-read cost.
#
# The prefix selects chunks alone. Loki writes them under the tenant id, which is
# `fake` while `loki.auth_enabled` is false, and keeps the tsdb index under
# `index/`, where every query reads it and it stays Hot. Turning auth on renames
# the prefix and silently stops the tiering.
#
# The thresholds are coupled to `limits_config.retention_period` in the loki
# argocd application, currently 4380h (~183 days). Azure bills an early-deletion
# penalty for leaving Cool inside 30 days or Cold inside 90, and Loki's compactor
# deletes at the retention period, so with a retention of R days the Cold
# threshold has to land in [60, R - 90]. At R = 183 that window is [60, 93] and
# 90 sits inside it. Shortening retention past 180 days closes the window, and
# the Cold action has to go.
#
# Rule names are alphanumeric only. Hyphens pass `plan` and fail `apply`.
resource "azurerm_storage_management_policy" "monitoring" {
  storage_account_id = azurerm_storage_account.monitoring.id

  rule {
    name    = "lokichunkstiering"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["${azurerm_storage_container.loki_chunks.name}/fake"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = 30
        tier_to_cold_after_days_since_modification_greater_than = 90
      }
    }
  }
}

# Loki authenticates to blob storage as this identity, through the AKS OIDC issuer.
# No account key is involved: the thanos object store client falls through to
# DefaultAzureCredential, which picks up the projected service account token.
resource "azurerm_user_assigned_identity" "loki" {
  name                = "Loki${title(var.environment)}WorkloadIdentity"
  location            = data.azurerm_resource_group.ifrcgo.location
  resource_group_name = data.azurerm_resource_group.ifrcgo.name
}

resource "azurerm_federated_identity_credential" "loki" {
  name                = "loki-${var.environment}-blob-writer-identity"
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.ifrcgo.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.loki.id
  resource_group_name = data.azurerm_resource_group.ifrcgo.name
  subject             = "system:serviceaccount:monitoring:${local.loki_service_account}"
}

resource "azurerm_role_assignment" "loki_chunks" {
  scope                = "${azurerm_storage_account.monitoring.id}/blobServices/default/containers/${azurerm_storage_container.loki_chunks.name}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.loki.principal_id

  # The identity is created in this same apply, and entra takes a moment to
  # replicate it. Without this the first apply intermittently fails PrincipalNotFound.
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "loki_ruler" {
  scope                = "${azurerm_storage_account.monitoring.id}/blobServices/default/containers/${azurerm_storage_container.loki_ruler.name}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.loki.principal_id

  # The identity is created in this same apply, and entra takes a moment to
  # replicate it. Without this the first apply intermittently fails PrincipalNotFound.
  skip_service_principal_aad_check = true
}
