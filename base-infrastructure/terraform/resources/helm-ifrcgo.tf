resource "helm_release" "ifrcgo" {
  lifecycle {
    ignore_changes = all
  }

  name  = "ifrcgo-helm"
  chart = "../helm/ifrcgo-helm"
  wait = true
  depends_on = [
    helm_release.ifrcgo-ingress-nginx,
    helm_release.ifrcgo-cert-manager
  ]

  # values = [
  #   file("${path.root}/../helm/ifrcgo-helm/values.yaml"),
  #   file("${path.root}/../helm/ifrcgo-helm/values-${var.environment}.yaml"),
  # ]

#   set {
#     name = "env.DJANGO_SECRET_KEY"
#     value = var.DJANGO_SECRET_KEY
#   }

#   set {
#     name = "env.DJANGO_DB_USER"
#     value = var.DJANGO_DB_USER
#   }

#   set {
#     name = "env.DJANGO_DB_PASS"
#     value = var.DJANGO_DB_PASS
#   }

#   set {
#     name = "env.DJANGO_DB_HOST"
#     value = var.DJANGO_DB_HOST
#   }

#   set {
#     name = "env.DJANGO_DB_PORT"
#     value = var.DJANGO_DB_PORT
#   }

# #  set {
# #    name = "env.AZURE_STORAGE_ACCOUNT"
# #    value = azurerm_storage_account.ifrcgo.id
# #  }
# #
# #  set {
# #    name = "env.AZURE_STORAGE_KEY"
# #    value = azurerm_storage_account.ifrcgo.primary_access_key
# #  }

#   set {
#     name = "env.AZURE_STORAGE_ACCOUNT"
#     value = var.AZURE_STORAGE_ACCOUNT
#   }

#   set {
#     name = "env.AZURE_STORAGE_KEY"
#     value = var.AZURE_STORAGE_KEY
#   }

#   set {
#     name = "env.EMAIL_API_ENDPOINT"
#     value = var.EMAIL_API_ENDPOINT
#   }

#   set {
#     name = "env.EMAIL_HOST"
#     value = var.EMAIL_HOST
#   }

#   set {
#     name = "env.EMAIL_PORT"
#     value = var.EMAIL_PORT
#   }

#   set {
#     name = "env.EMAIL_USER"
#     value = var.EMAIL_USER
#   }

#   set {
#     name = "env.EMAIL_PASS"
#     value = var.EMAIL_PASS
#   }

#   set {
#     name = "env.TEST_EMAILS"
#     value = var.TEST_EMAILS
#   }

#   set {
#     name = "env.AWS_TRANSLATE_ACCESS_KEY"
#     value = var.AWS_TRANSLATE_ACCESS_KEY
#   }

#   set {
#     name = "env.AWS_TRANSLATE_SECRET_KEY"
#     value = var.AWS_TRANSLATE_SECRET_KEY
#   }

#   set {
#     name = "env.AWS_TRANSLATE_REGION"
#     value = var.AWS_TRANSLATE_REGION
#   }

#   set {
#     name = "env.MOLNIX_API_BASE"
#     value = var.MOLNIX_API_BASE
#   }

#   set {
#     name = "env.MOLNIX_USERNAME"
#     value = var.MOLNIX_USERNAME
#   }

#   set {
#     name = "env.MOLNIX_PASSWORD"
#     value = var.MOLNIX_PASSWORD
#   }

#   set {
#     name = "env.ERP_API_ENDPOINT"
#     value = var.ERP_API_ENDPOINT
#   }

#   set {
#     name = "env.ERP_API_SUBSCRIPTION_KEY"
#     value = var.ERP_API_SUBSCRIPTION_KEY
#   }

#   set {
#     name = "env.FDRS_APIKEY"
#     value = var.FDRS_APIKEY
#   }

#   set {
#     name = "env.FDRS_CREDENTIAL"
#     value = var.FDRS_CREDENTIAL
#   }

#   set {
#     name = "env.HPC_CREDENTIAL"
#     value = var.HPC_CREDENTIAL
#   }

#   set {
#     name = "env.APPLICATION_INSIGHTS_INSTRUMENTATION_KEY"
#     value = var.APPLICATION_INSIGHTS_INSTRUMENTATION_KEY
#   }

#   set {
#     name = "env.GO_FTPHOST"
#     value = var.GO_FTPHOST
#   }

#   set {
#     name = "env.GO_FTPUSER"
#     value = var.GO_FTPUSER
#   }

#   set {
#     name = "env.GO_FTPPASS"
#     value = var.GO_FTPPASS
#   }

#   set {
#     name = "env.GO_DBPASS"
#     value = var.GO_DBPASS
#   }

#   set {
#     name = "env.APPEALS_USER"
#     value = var.APPEALS_USER
#   }

#   set {
#     name = "env.APPEALS_PASS"
#     value = var.APPEALS_PASS
#   }

#   set {
#     name = "env.IFRC_TRANSLATION_HEADER_API_KEY"
#     value = var.IFRC_TRANSLATION_HEADER_API_KEY
#   }

#   set {
#     name  = "elasticsearch.disk.name"
#     value = "${local.prefix}-disk"
#   }

#   set {
#     name  = "elasticsearch.disk.uri"
#     value = azurerm_managed_disk.ifrcgo.id
#   }

#   set {
#     name = "secrets.API_TLS_CRT"
#     value = var.API_TLS_CRT
#   }

#   set {
#     name = "secrets.API_TLS_KEY"
#     value = var.API_TLS_KEY
#   }

#   set {
#     name = "secrets.API_ADDITIONAL_DOMAIN_TLS_CRT"
#     value = var.API_ADDITIONAL_DOMAIN_TLS_CRT
#   }

#   set {
#     name = "secrets.API_ADDITIONAL_DOMAIN_TLS_KEY"
#     value = var.API_ADDITIONAL_DOMAIN_TLS_KEY
#   }
}
