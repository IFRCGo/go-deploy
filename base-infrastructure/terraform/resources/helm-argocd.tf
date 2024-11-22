resource "helm_release" "argo-cd" {
  name             = "argo-cd"
  chart            = "argo-cd"
  create_namespace = true

  depends_on = [
    azurerm_kubernetes_cluster.ifrcgo
  ]

  repository = "https://argoproj.github.io/argo-helm"
  namespace  = "argocd"
  version    = "7.6.7"

  values = [
    yamlencode({
      configs = {
        cm = {
          "timeout.reconciliation": "60s"  
          "timeout.hard.reconciliation": "90s"
        }
      }
    })
  ]
}