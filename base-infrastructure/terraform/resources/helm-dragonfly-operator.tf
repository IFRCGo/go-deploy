resource "helm_release" "dragonfly-operator" {
  name             = "dragonfly-operator"
  namespace        = "dragonfly-operator-system"
  create_namespace = true
  max_history      = 10

  chart   = "oci://ghcr.io/dragonflydb/dragonfly-operator/helm/dragonfly-operator"
  version = "v1.3.0"

  depends_on = [
    azurerm_kubernetes_cluster.ifrcgo
  ]
}
