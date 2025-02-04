variable "app_name" {
  type = string
}

variable "pull_principal_ids" {
  type    = list(any)
  default = []
}

variable "environment" {
  type = string
}

variable "registry_sku" {
  type    = string
  default = "Basic"
}

variable "resource_group_name" {
  type = string
}