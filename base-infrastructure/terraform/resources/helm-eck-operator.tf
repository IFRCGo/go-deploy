# Elastic Cloud on Kubernetes (ECK) operator + CRDs.
resource "helm_release" "eck-operator" {
  name             = "eck-operator"
  namespace        = "elastic-system"
  create_namespace = true
  max_history      = 10

  repository = "https://helm.elastic.co"
  chart      = "eck-operator"

  # WARNING: We run Elasticsearch 7.x, which this operator supports but already
  # flags as deprecated (see the deprecation warning in the operator logs).
  # Before bumping, confirm the target ECK version still supports ES 7.x — newer
  # majors drop it. Do NOT upgrade if ES 7 support is missing.
  version = "3.5.0" # https://github.com/elastic/cloud-on-k8s/releases

  depends_on = [
    azurerm_kubernetes_cluster.ifrcgo
  ]
}
