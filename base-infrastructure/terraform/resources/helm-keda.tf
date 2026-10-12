# KEDA: event-driven autoscaling (used by montandon-etl celery workers via rabbitmq queue length)
resource "helm_release" "keda" {
  name             = "keda"
  namespace        = "keda"
  create_namespace = true
  max_history      = 10

  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = "2.21.0"

  depends_on = [
    azurerm_kubernetes_cluster.ifrcgo
  ]
}
