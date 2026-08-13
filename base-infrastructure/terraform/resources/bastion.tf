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

  # Cluster/environment-specific values. The chart itself stays cloud-agnostic; anything
  # Azure/AKS-specific (storage class, LB annotations, reserved IP) is injected here.
  values = [yamlencode({
    environment = var.environment
    # Authorized SSH *public* keys. Concatenated into a single, declarative authorized_keys
    # file by the chart — removing an entry here revokes that key's access.
    keys = [
      # Zoltan
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPGAnkQdf5CIpVoqNVJ17AAzUb02gpTltJI5q5SRKxl8 zol@hp",
      # Daniel
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDU1XLLPq1J4kFvNyg5eUK8uuW8dtW1f3ALVnYr0nVhldxF0J59XtZbNFBLCVHYZL3NQxYQrucll6LbGaMGKbGsTwtqcxqd2fWlhg7nBnvhOzULYbAru3YfpkgnawGin6Y7qW/MQ3fYmqqm8MB7p5+G4sIL76S2yWbi7lcKWnd87yDTGEEoc8H6i6IwNNVHudvuMA4MzGkSgql7gIC2KuU+s2u9Y6fmE92G39BO454SUgAcCJfhuXukZhU4UN3RVYy+F0MxVeLc0hEJi4sCYcoPKREc0//srNyni7b8G8C+z6t02xrzhWwIORlb8Jr2kmbblp7PFMz4r2qRd8MvXAa5ta6kUvMDg0t52JaDMAGy0IjGZh9PznXbp1LYn7uS5NQh4C/t6Q3TXyJbEiaQaObcmjn6w/DWH6gI7ZRYkPGdlctlNm5MWnhjG9Q/FzRIxvaauSFqgs6bfIUGGaY9i1eNiowVSzDPlP7nH0gJpq+uS5Qdyg69m/XH1DqywPoZY7U= ifrcds\\daniel.tovari@5CG41911RW",
      # Arun
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKBaIcVRiTtsc2WUWIq8akcd2owJo75+GbvcOnTf38KP ifrcds\\arun.gandhi@5CG41911S3",
      # Navin
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN/f/A3qkaTHSdbKn8Hv75YiJvRMEXvWTDdIiR7tyAjJ navin@nav-machine",
      # David
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC3FzrQdVh5Qwp5Y6KQGcpqHxKErxCW103iEECuutR/jBZe6X0xjD+cW7e+H8SrUsPQwj87fzOsMAc6v6n+3hdYFa6ekgRG/USEIUR5C/GD1Xjva3Xpp45PasBhJEtYt2ON+dlzwvRyOuv2hvqv2WHBO020ewIlVuQ4pU4Qj5ysvwWGj8GAv/jITiVERmjLTStbFwxeIDT3jQEbwnfV1zZZKiGxIecB/y51nk6oIQ00ZGrYEo5ieWsUSVfLHOX0/lZ0mtrdqxDEgMaCbNaUbICAimsJPamNpoirKc7FoKIKKrLQsK8qE1lClWQEecbW+dgSiwxracooKeWhHq+BkKUCNgEL/C0ff2l9e8sJcLmYZUdPtDCdtUDC8BAlELA5HR6tdCTfFcc0nXltclSSODMnZkQohh5/2fixJTwN5p5csEfBLzbdrturKtT/TbYSoaodg4muPqY4YE5jiJfrHVAGS1DVWz/cRcm1vOxT2V4iW2SNvo8fS2PZOpU5furrvbM= ifrcds\\david.muchatiza@5CG41911S1",
      # Paola
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDGql4RrbxSQTW5QrTh+P+94jGCXOCeZgc23hxL9zFCYQrzL0SMw1F53Z5SFZimIhJswYPqV2pT8L4oTRqIrTCM+looWi7b9/9u+m/KmA+FWbo3u6uRrckkA3nVIKsKHvlOucX2GxE6i+tXdeXEisW49ZpMtuvxMLJ3Eg4MK10d/2d3FKuzTsrxCTlJn8FAE3yOsVow0jdu+381IrkAqRE2GINeQ87hVlQpbo+bL2N/2QZmNjDhBBQkRJLDisW0+UNgo+S9wN7HbpV5LheSJS9wGN7LlmcqlpZFrDO/lVyoMxEQ0588wUI8BVfqAZDEBJPdGtzq513r+5iXEX/9A1Mendlvxfl6ANNRcH9PVZHkRN1dxY3rckQ+Lk3qqIjjfYFYvl5Gybidb1BM2VNWHAuzaDDQzJpeTHIbQnDt7Ke4oX2xWYgyu+kVhqz0HnAV28qMXbMEsrMIrtwl7IjcrorgdduHghZvWFbaJZNtXOfgnf1IYNXkZ9eWPS+Bz9nWMhE= ifrcds\\paola.yela@5CG41911RT",
      # Ranjan
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJA0ec4Gavc+m1MjEZGoUce51yWouMTRTYJZV3s/jgD rsh@rsh-XPS-15-9510",
      # Sushil
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJbRraaLnjdExOtObCgY5RmOALKYzlXAH9GAMxbm9wtX susilnem@sushil-machine",
    ]
    # Idle jump host — kept small. Staging gets a slightly higher CPU request (matches the
    # sizing the go-api chart overrides used previously); the rest comes from values.yaml.
    resources = {
      requests = {
        cpu = var.environment == "staging" ? "0.2" : "0.1"
      }
    }
    persistence = {
      # AKS built-in RWO managed-disk class.
      storageClass = "managed-csi"
    }
    # Defense-in-depth for the pivot surface: allow the pod to reach only cluster-internal
    # RFC1918 ranges (enough to port-forward to in-cluster services) — the public internet
    # and the cloud metadata endpoint (169.254.169.254) are denied. Requires the AKS
    # cluster to have a network-policy engine (azure/calico); it is a harmless no-op
    # otherwise. The chart default egress CIDRs (10/8, 172.16/12, 192.168/16) cover the
    # standard AKS pod/service ranges.
    networkPolicy = {
      enabled = true
    }
    service = {
      # Reserved static IP so the bastion endpoint is stable across recreations.
      loadBalancerIP = azurerm_public_ip.bastion.ip_address
      annotations = {
        "service.beta.kubernetes.io/azure-load-balancer-resource-group" = data.azurerm_resource_group.ifrcgo.name
      }
    }
  })]
}
