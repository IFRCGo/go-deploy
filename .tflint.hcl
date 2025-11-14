tflint {
  required_version = ">= 0.55"
}

config {
  format = "compact"
}

plugin "azurerm" {
    enabled = true
    deprecated = true
}
