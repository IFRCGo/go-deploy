resource "helm_release" "ifrcgo-ingress-nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  version          = "4.12.1"
  create_namespace = true
  depends_on       = [
    azurerm_public_ip.ifrcgo
  ]

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = data.azurerm_resource_group.ifrcgo.name
  }

  set {
    name = "controller.service.externalTrafficPolicy"
    value = "Local"
  }

  set {
    name = "controller.replicaCount"
    value = 1
  }

  set {
    name = "controller.service.loadBalancerIP"
    value = azurerm_public_ip.ifrcgo.ip_address
  }


}