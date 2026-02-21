module "resources" {
  source      = "./resources/"
  environment = var.environment
  # subscriptionId      = var.subscriptionId
  REGION = var.REGION
  # RESOURCES_DB_NAME   = var.RESOURCES_DB_NAME
  # RESOURCES_DB_SERVER = var.RESOURCES_DB_SERVER
}

terraform {
  required_version = "~> 1.14.0"

  backend "azurerm" {
    resource_group_name  = "ifrctgo002rg"
    storage_account_name = "ifrcgoterraform"
    container_name       = "terraform"
    # TODO: Replace this with terragrunt
    # NOTE: this is meant to be replaced in
    # - base-infrastructure/scripts/apply-infra.sh
    # - base-infrastructure/scripts/plan-infra.sh
    # so that the correct environment is deployed
    key = "ENVIRONMENT_TO_REPLACE"
  }
}

output "resources" {
  value     = module.resources
  sensitive = true
}
