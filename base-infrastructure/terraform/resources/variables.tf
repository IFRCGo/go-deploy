variable "environment" {
  type = string
}

variable "subscriptionId" {
  type = string
}

variable "REGION" {
  type = string
  default = ""
}

variable "RESOURCES_DB_NAME" {
  type = string
  default = ""
}

variable "RESOURCES_DB_SERVER" {
  type = string
  default = ""
}

# -----------------
# Attach ACR
# Defaults to common resources

### Staging Resources

variable "ifrcgo_test_resources_rg" {
  type = string
  default = "ifrctgo002rg"
}

variable "ifrcgo_test_resources_acr" {
  type    = string
  default = "ifrcgoacr"
}

variable "ifrcgo_test_resources_db_server" {
 type = string
 default = ""
}

variable "ifrcgo_test_resources_db" {
 type = string
 default = ""
}

### Production Resources

variable "ifrcgo_prod_resources_rg" {
  type = string
  default = "ifrcpgo002rg"
}

variable "ifrcgo_prod_resources_acr" {
  type    = string
  default = "ifrcgoacr"
}

variable "ifrcgo_prod_resources_db_server" {
 type = string
 default = ""
}

variable "ifrcgo_prod_resources_db" {
 type = string
 default = ""
}

# -----------------
# Local variables

locals {
  stack_id              = "ifrcgo"
  location              = lower(replace(var.REGION, " ", ""))
  prefix                = var.environment == "staging" ? "ifrctgo" : "ifrcpgo"
  # prefixnodashes        = "${local.stack_id}${var.environment}"
  storage               = "${local.prefix}"
  deploy_secrets_prefix = "${local.prefix}"
  ifrcgo_test_resources_db_server = var.RESOURCES_DB_SERVER
  ifrcgo_prod_resources_db_server = var.RESOURCES_DB_SERVER
  ifrcgo_test_resources_db = var.RESOURCES_DB_NAME
  ifrcgo_prod_resources_db = var.RESOURCES_DB_NAME

}
