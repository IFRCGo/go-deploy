resource "helm_release" "ifrcgo-ingress-nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  version          = "4.12.1"
  create_namespace = true
  depends_on = [
    azurerm_public_ip.ifrcgo
  ]

  set = [
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
      value = data.azurerm_resource_group.ifrcgo.name
    },
    {
      name  = "controller.service.externalTrafficPolicy"
      value = "Local"
    },
    {
      name  = "controller.replicaCount"
      value = 1
    },
    {
      name  = "controller.service.loadBalancerIP"
      value = azurerm_public_ip.ifrcgo.ip_address
    },
    # IP logging (preserve client IPs for ingress logs)
    {
      name  = "controller.config.use-forwarded-headers"
      value = "true"
    },
    {
      name  = "controller.config.compute-full-forwarded-for"
      value = "true"
    },
    {
      name  = "controller.config.real-ip-header"
      value = "X-Forwarded-For"
    },
    {
      name  = "controller.config.set-real-ip-from"
      value = local.aks_subnet_cidr
    },
  ]

}
