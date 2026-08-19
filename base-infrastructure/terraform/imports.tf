# One-off adoption of resources that predate this configuration.
#
# The go-api workload identity was created outside Terraform for the legacy
# `go-api-<environment>-workload-sa` federation, under the same name
# module.go_api_resources derives from app_name and environment, so the first
# apply of that module fails with "resource already exists".
#
# The identity holds no role assignments, and the federated credential the legacy
# deployment uses stays unmanaged: the module adds a second credential rather than
# replacing it, so both service accounts keep working during the parallel run.
#
# NOTE: Terraform owns the identity once this is imported, so destroying
# module.go_api_resources also removes the legacy credential along with its parent.
#
# TODO: Clear this file once staging and production have both been applied.

locals {
  # Every environment in this configuration lives in the same subscription.
  subscription_id = "39308fb0-9929-4b29-aafa-b3c78a8b0658"

  # Mirrors azurerm_user_assigned_identity.workload in ./app_resources/iam.tf
  go_api_workload_identity_name = "${replace(title("go-api"), "-", "")}${title(var.environment)}WorkloadIdentity"
}

import {
  to = module.go_api_resources.azurerm_user_assigned_identity.workload
  id = "/subscriptions/${local.subscription_id}/resourceGroups/${module.resources.resource_group}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${local.go_api_workload_identity_name}"
}
