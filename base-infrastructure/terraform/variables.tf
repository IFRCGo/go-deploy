variable "environment" {
  type    = string
  default = "staging"
}

# variable "subscriptionId" {
#   type = string
# }

variable "REGION" {
  type    = string
  default = "west europe"
}

# variable "RESOURCES_DB_NAME" {
#   type    = string
#   default = ""
# }

# variable "RESOURCES_DB_SERVER" {
#   type    = string
#   default = ""
# }

variable "cacheppuccino_translation_api_key" {
  type        = string
  sensitive   = true
  description = "Translation API key for cacheppuccino"
}
