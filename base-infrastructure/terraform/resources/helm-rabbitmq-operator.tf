# NOTE: It is installed in rabbitmq-system
resource "helm_release" "rabbitmq-cluster-operator" {
  name        = "rabbitmq-cluster-operator"
  max_history = 10

  chart   = "oci://ghcr.io/toggle-corp/helm-charts/rabbitmq-cluster-operator"
  version = "v2.17.0"

  depends_on = [
    azurerm_kubernetes_cluster.ifrcgo
  ]
}
