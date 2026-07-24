# SSH bastion — cluster-wide access jump host.
# This is cluster access infrastructure (not tied to any single application), so it lives here in base-infrastructure rather than in an application Helm chart.

# TODO: An older copy of this bastion is still shipped by the go-api Helm chart (deploy/helm/ifrcgo-helm/templates/bastion.yaml) and runs in the `default` namespace.
# Both run in parallel for now; users should migrate to the new IP exposed by this resource. The go-api copy will be removed in the upcoming go-api updates.

locals {
  # renovate: datasource=docker depName=lscr.io/linuxserver/openssh-server versioning=regex:^version-(?<major>\d+)\.(?<minor>\d+)_p(?<patch>\d+)-r(?<build>\d+)$
  bastion_image = "lscr.io/linuxserver/openssh-server:version-10.3_p1-r0"

  # Idle SSH jump host — kept small, tuned per environment, NOTE: matches the sizing the go-api chart overrides used previously
  bastion_resources = {
    requests = {
      cpu    = var.environment == "staging" ? "0.2" : "0.1"
      memory = "0.05Gi"
    }
    limits = { cpu = "1", memory = "0.2Gi" }
  }

  # Authorized SSH *public* keys (filename => key)
  bastion_keys = {
    "zoltan.pub"   = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPGAnkQdf5CIpVoqNVJ17AAzUb02gpTltJI5q5SRKxl8 zol@hp"
    "daniel.pub"   = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDU1XLLPq1J4kFvNyg5eUK8uuW8dtW1f3ALVnYr0nVhldxF0J59XtZbNFBLCVHYZL3NQxYQrucll6LbGaMGKbGsTwtqcxqd2fWlhg7nBnvhOzULYbAru3YfpkgnawGin6Y7qW/MQ3fYmqqm8MB7p5+G4sIL76S2yWbi7lcKWnd87yDTGEEoc8H6i6IwNNVHudvuMA4MzGkSgql7gIC2KuU+s2u9Y6fmE92G39BO454SUgAcCJfhuXukZhU4UN3RVYy+F0MxVeLc0hEJi4sCYcoPKREc0//srNyni7b8G8C+z6t02xrzhWwIORlb8Jr2kmbblp7PFMz4r2qRd8MvXAa5ta6kUvMDg0t52JaDMAGy0IjGZh9PznXbp1LYn7uS5NQh4C/t6Q3TXyJbEiaQaObcmjn6w/DWH6gI7ZRYkPGdlctlNm5MWnhjG9Q/FzRIxvaauSFqgs6bfIUGGaY9i1eNiowVSzDPlP7nH0gJpq+uS5Qdyg69m/XH1DqywPoZY7U= ifrcds\\daniel.tovari@5CG41911RW"
    "arun.pub"     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIERqaO+XlqTbvoh88Kuj9c377x77NChWhNP8VpbM1/hf ifrcds\\arun.gandhi@5CG1355NPN"
    "thenav56.pub" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN/f/A3qkaTHSdbKn8Hv75YiJvRMEXvWTDdIiR7tyAjJ navin@nav-machine"
    "david.pub"    = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC3FzrQdVh5Qwp5Y6KQGcpqHxKErxCW103iEECuutR/jBZe6X0xjD+cW7e+H8SrUsPQwj87fzOsMAc6v6n+3hdYFa6ekgRG/USEIUR5C/GD1Xjva3Xpp45PasBhJEtYt2ON+dlzwvRyOuv2hvqv2WHBO020ewIlVuQ4pU4Qj5ysvwWGj8GAv/jITiVERmjLTStbFwxeIDT3jQEbwnfV1zZZKiGxIecB/y51nk6oIQ00ZGrYEo5ieWsUSVfLHOX0/lZ0mtrdqxDEgMaCbNaUbICAimsJPamNpoirKc7FoKIKKrLQsK8qE1lClWQEecbW+dgSiwxracooKeWhHq+BkKUCNgEL/C0ff2l9e8sJcLmYZUdPtDCdtUDC8BAlELA5HR6tdCTfFcc0nXltclSSODMnZkQohh5/2fixJTwN5p5csEfBLzbdrturKtT/TbYSoaodg4muPqY4YE5jiJfrHVAGS1DVWz/cRcm1vOxT2V4iW2SNvo8fS2PZOpU5furrvbM= ifrcds\\david.muchatiza@5CG41911S1"
    "paola.pub"    = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDGql4RrbxSQTW5QrTh+P+94jGCXOCeZgc23hxL9zFCYQrzL0SMw1F53Z5SFZimIhJswYPqV2pT8L4oTRqIrTCM+looWi7b9/9u+m/KmA+FWbo3u6uRrckkA3nVIKsKHvlOucX2GxE6i+tXdeXEisW49ZpMtuvxMLJ3Eg4MK10d/2d3FKuzTsrxCTlJn8FAE3yOsVow0jdu+381IrkAqRE2GINeQ87hVlQpbo+bL2N/2QZmNjDhBBQkRJLDisW0+UNgo+S9wN7HbpV5LheSJS9wGN7LlmcqlpZFrDO/lVyoMxEQ0588wUI8BVfqAZDEBJPdGtzq513r+5iXEX/9A1Mendlvxfl6ANNRcH9PVZHkRN1dxY3rckQ+Lk3qqIjjfYFYvl5Gybidb1BM2VNWHAuzaDDQzJpeTHIbQnDt7Ke4oX2xWYgyu+kVhqz0HnAV28qMXbMEsrMIrtwl7IjcrorgdduHghZvWFbaJZNtXOfgnf1IYNXkZ9eWPS+Bz9nWMhE= ifrcds\\paola.yela@5CG41911RT"
    "ranjan.pub"   = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJA0ec4Gavc+m1MjEZGoUce51yWouMTRTYJZV3s/jgD rsh@rsh-XPS-15-9510"
  }
}

resource "kubernetes_namespace" "bastion" {
  metadata {
    name = "bastion"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      environment                    = var.environment
    }
  }
}

# Authorized public keys, one file per key (mounted as PUBLIC_KEY_DIR).
resource "kubernetes_config_map" "bastion_authorized_keys" {
  metadata {
    name      = "ssh-bastion-authorized-keys"
    namespace = kubernetes_namespace.bastion.metadata[0].name
  }
  data = local.bastion_keys
}

# linuxserver/openssh-server ships with TCP forwarding disabled (AllowTcpForwarding no).
# The image's /etc/ssh/sshd_config has `Include /etc/ssh/sshd_config.d/*.conf` near the top,
# above that directive, so a drop-in here wins (sshd uses the first value obtained).
# Agent forwarding is intentionally NOT enabled: this box is used for port-forwarding /
# ProxyJump, which only needs TCP forwarding, and agent forwarding is a security downgrade.
resource "kubernetes_config_map" "bastion_fix_sshd_config" {
  metadata {
    name      = "ssh-bastion-fix-sshd-config"
    namespace = kubernetes_namespace.bastion.metadata[0].name
  }
  data = {
    "100-ifrc-forwarding.conf" = <<-EOT
      # Jump host for port-forwarding / ProxyJump. Key-only auth (PasswordAuthentication
      # no, GatewayPorts no, X11Forwarding no are already set by the image defaults).
      AllowTcpForwarding yes

      # Auth hardening (internet-exposed LoadBalancer)
      PermitRootLogin no
      KbdInteractiveAuthentication no
      MaxAuthTries 3
      LoginGraceTime 30
      AllowUsers user

      # Audit trail (log key fingerprint per login) + reap dead sessions/tunnels
      LogLevel VERBOSE
      ClientAliveInterval 300
      ClientAliveCountMax 2
    EOT
  }
}

resource "kubernetes_stateful_set" "bastion" {
  metadata {
    name      = "ssh-bastion"
    namespace = kubernetes_namespace.bastion.metadata[0].name
    labels = {
      app         = "ssh-bastion"
      environment = var.environment
    }
  }

  spec {
    replicas     = 1
    service_name = "ssh-bastion"

    selector {
      match_labels = {
        app = "ssh-bastion"
      }
    }

    template {
      metadata {
        labels = {
          app = "ssh-bastion"
        }
      }

      spec {
        container {
          name  = "ssh-bastion"
          image = local.bastion_image

          port {
            container_port = 2222
          }

          resources {
            requests = {
              cpu    = local.bastion_resources.requests.cpu
              memory = local.bastion_resources.requests.memory
            }
            limits = {
              cpu    = local.bastion_resources.limits.cpu
              memory = local.bastion_resources.limits.memory
            }
          }

          env {
            name  = "PUID"
            value = "1000"
          }
          env {
            name  = "PGID"
            value = "1000"
          }
          env {
            name  = "USER_NAME"
            value = "user"
          }
          env {
            name  = "PASSWORD_ACCESS"
            value = "false"
          }
          env {
            name  = "SUDO_ACCESS"
            value = "false"
          }
          env {
            name  = "PUBLIC_KEY_DIR"
            value = "/ssh-public_keys"
          }

          volume_mount {
            name       = "ssh-authorized-keys"
            mount_path = "/ssh-public_keys"
            read_only  = true
          }
          volume_mount {
            name       = "config-volume"
            mount_path = "/config"
          }
          volume_mount {
            name       = "fix-sshd-config"
            mount_path = "/etc/ssh/sshd_config.d/100-ifrc-forwarding.conf"
            sub_path   = "100-ifrc-forwarding.conf"
            read_only  = true
          }
        }

        volume {
          name = "ssh-authorized-keys"
          config_map {
            name = kubernetes_config_map.bastion_authorized_keys.metadata[0].name
          }
        }
        volume {
          name = "fix-sshd-config"
          config_map {
            name = kubernetes_config_map.bastion_fix_sshd_config.metadata[0].name
          }
        }
      }
    }

    # Persists the server host keys across pod restarts (avoids host-key-changed warnings for users).
    volume_claim_template {
      metadata {
        name = "config-volume"
      }
      spec {
        access_modes = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = "100Mi"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "bastion" {
  metadata {
    name      = "ssh-bastion"
    namespace = kubernetes_namespace.bastion.metadata[0].name
    labels = {
      app         = "ssh-bastion"
      environment = var.environment
    }
    annotations = {
      "service.beta.kubernetes.io/azure-load-balancer-resource-group" = data.azurerm_resource_group.ifrcgo.name
    }
  }

  depends_on = [
    azurerm_public_ip.bastion,
  ]

  spec {
    type = "LoadBalancer"
    # Open to the internet; access is gated by SSH public-key auth only (team members do not have static source IPs, so no loadBalancerSourceRanges).
    load_balancer_ip = azurerm_public_ip.bastion.ip_address

    selector = {
      app = "ssh-bastion"
    }

    port {
      port        = 2222
      target_port = 2222
    }
  }
}
