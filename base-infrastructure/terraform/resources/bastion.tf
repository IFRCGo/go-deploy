# SSH bastion — cluster-wide access jump host.
# This is cluster access infrastructure (not tied to any single application), so it lives
# here in base-infrastructure rather than in an application Helm chart. The Kubernetes
# resources are defined by the local chart at base-infrastructure/charts/ssh-bastion and
# applied via this helm_release (matching how the other cluster components — traefik,
# argocd, cert-manager, etc. — are deployed).
#
# TODO: An older copy of this bastion is still shipped by the go-api Helm chart
# (deploy/helm/ifrcgo-helm/templates/bastion.yaml) and runs in the `default` namespace.
# Both run in parallel for now; users should migrate to the new IP exposed by this
# resource. The go-api copy will be removed in the upcoming go-api updates.
#
# NOTE: after editing anything under charts/ssh-bastion, bump the chart `version` in
# Chart.yaml so the helm provider detects the change and redeploys.

resource "helm_release" "bastion" {
  name             = "ssh-bastion"
  namespace        = "bastion"
  create_namespace = true
  chart            = "${path.module}/../../charts/ssh-bastion"

  depends_on = [
    azurerm_public_ip.bastion,
  ]

  values = [yamlencode({
    environment = var.environment
    # Idle jump host — kept small. Staging gets a slightly higher CPU request (matches the
    # sizing the go-api chart overrides used previously); everything else comes from the
    # chart's values.yaml.
    resources = {
      requests = {
        cpu = var.environment == "staging" ? "0.2" : "0.1"
      }
    }
    service = {
      # Reserved static IP so the bastion endpoint is stable across recreations.
      loadBalancerIP     = azurerm_public_ip.bastion.ip_address
      azureResourceGroup = data.azurerm_resource_group.ifrcgo.name
    }
  })]
}
