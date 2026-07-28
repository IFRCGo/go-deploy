# Reference from: "./helm-ingress-nginx.tf" file.

resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  namespace        = "traefik"
  version          = "40.2.0"
  create_namespace = true

  depends_on = [
    azurerm_public_ip.traefik,
  ]

  values = [yamlencode({

    deployment = {
      replicas = 1
    }

    service = {
      annotations = {
        "service.beta.kubernetes.io/azure-load-balancer-resource-group" = data.azurerm_resource_group.ifrcgo.name
        # AzureLoadBalanacer Health probe path
        "service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path" = "/ping"
      }
      spec = {
        loadBalancerIP        = azurerm_public_ip.traefik.ip_address
        externalTrafficPolicy = "Local"
      }
    }

    ingressClass = {
      enabled = true
      # NOTE: Keep false until nginx is fully removed
      isDefaultClass = false
    }

    providers = {
      # NOTE: Uses the same ingressClass as nginx for now, until nginx is fully removed
      kubernetesIngress = {
        ingressClass = "nginx"
      }
      kubernetesIngressNGINX = {
        enabled = true
      }
    }

    # Replaces nginx: use-forwarded-headers, real-ip-header, set-real-ip-from
    # Trust X-Forwarded-For only from the AKS subnet (10.1.0.0/16)
    ports = {
      web = {
        http = {
          redirections = {
            entryPoint = {
              to        = "websecure"
              scheme    = "https"
              permanent = true
            }
          }
        }
        forwardedHeaders = {
          trustedIPs = [local.aks_subnet_cidr]
        }
      }
      websecure = {
        forwardedHeaders = {
          trustedIPs = [local.aks_subnet_cidr]
        }
      }
    }

    logs = {
      access = {
        enabled = true
      }
    }

    # Not exposing dashboard on plain HTTP
    api = {
      insecure = false
    }

  })]
}
