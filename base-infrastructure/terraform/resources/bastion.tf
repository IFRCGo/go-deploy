# SSH bastion — cluster-wide access jump host.
# This is cluster access infrastructure (not tied to any single application), so it lives here in base-infrastructure rather than in an application Helm chart.

# TODO: An older copy of this bastion is still shipped by the go-api Helm chart (deploy/helm/ifrcgo-helm/templates/bastion.yaml) and runs in the `default` namespace.
# Both run in parallel for now; users should migrate to the new IP exposed by this resource. The go-api copy will be removed in the upcoming go-api updates.

locals {
  # renovate: datasource=docker depName=lscr.io/linuxserver/openssh-server versioning=regex:^version-(?<major>\d+)\.(?<minor>\d+)_p(?<patch>\d+)-r(?<build>\d+)$
  bastion_image = "lscr.io/linuxserver/openssh-server:version-10.3_p1-r0"

  # Single source of truth for the login user: the image creates this account
  # (USER_NAME) and sshd only permits it (AllowUsers). Keep the two in lockstep.
  bastion_user = "user"

  # Idle SSH jump host — kept small, tuned per environment, NOTE: matches the sizing the go-api chart overrides used previously
  bastion_resources = {
    requests = {
      cpu    = var.environment == "staging" ? "0.2" : "0.1"
      memory = "0.05Gi"
    }
    limits = { cpu = "1", memory = "0.2Gi" }
  }

  # sshd drop-in. NOTE on how this actually takes effect with linuxserver/openssh-server:
  # its init script runs `sshd -f /config/sshd/sshd_config`, comments out the stock
  # `Include /etc/ssh/sshd_config.d/*.conf`, and re-enables an include pointing at
  # /config/sshd/sshd_config.d/ *only if that directory exists*. So this file MUST be
  # mounted under /config/sshd/sshd_config.d/ (see volume_mount below) — a drop-in in the
  # stock /etc/ssh/sshd_config.d/ is silently ignored. Directives here are obtained before
  # the base config's, so first-value-wins settings (AllowTcpForwarding, AuthorizedKeysFile)
  # override the image defaults.
  #
  # Agent forwarding is intentionally NOT enabled: this box is used for port-forwarding /
  # ProxyJump, which only needs TCP forwarding, and agent forwarding is a security downgrade.
  bastion_sshd_config = <<-EOT
    # Jump host for port-forwarding / ProxyJump. Key-only auth (PasswordAuthentication
    # no, GatewayPorts no, X11Forwarding no are already set by the image defaults).
    AllowTcpForwarding yes

    # Authoritative, declarative authorized_keys (mounted read-only, see below). Using a
    # single fixed file instead of the image's PUBLIC_KEY_DIR (which only ever *appends*
    # to a persistent file) so that removing a key here actually revokes access.
    AuthorizedKeysFile /etc/ssh/authorized_keys

    # Auth hardening (internet-exposed LoadBalancer)
    PermitRootLogin no
    KbdInteractiveAuthentication no
    MaxAuthTries 3
    LoginGraceTime 30
    AllowUsers ${local.bastion_user}

    # Audit trail (log key fingerprint per login) + reap dead sessions/tunnels
    LogLevel VERBOSE
    ClientAliveInterval 300
    ClientAliveCountMax 2
  EOT

  # Authorized SSH *public* keys (filename => key). Concatenated into a single, fully
  # declarative authorized_keys file (see bastion_sshd_config / the config map below).
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

# Authoritative authorized_keys (all public keys concatenated into one file), mounted at
# the sshd AuthorizedKeysFile path. Declarative: removing a key here revokes access.
resource "kubernetes_config_map" "bastion_authorized_keys" {
  metadata {
    name      = "ssh-bastion-authorized-keys"
    namespace = kubernetes_namespace.bastion.metadata[0].name
  }
  data = {
    "authorized_keys" = "${join("\n", values(local.bastion_keys))}\n"
  }
}

# sshd drop-in (see local.bastion_sshd_config for the content and the notes on how the
# linuxserver image consumes it).
resource "kubernetes_config_map" "bastion_fix_sshd_config" {
  metadata {
    name      = "ssh-bastion-fix-sshd-config"
    namespace = kubernetes_namespace.bastion.metadata[0].name
  }
  data = {
    "100-ifrc-forwarding.conf" = local.bastion_sshd_config
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
        # Roll the pod when keys or sshd config change (the container ingests both only at
        # start; without this a ConfigMap edit applies but the running pod keeps the old
        # values, so added keys never work and — combined with the fixes above — nothing
        # picks up config changes).
        annotations = {
          "checksum/authorized-keys" = sha256(jsonencode(local.bastion_keys))
          "checksum/sshd-config"     = sha256(local.bastion_sshd_config)
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
            value = local.bastion_user
          }
          env {
            name  = "PASSWORD_ACCESS"
            value = "false"
          }
          env {
            name  = "SUDO_ACCESS"
            value = "false"
          }

          # Authoritative authorized_keys — sshd reads it via AuthorizedKeysFile (see the
          # drop-in). root-owned read-only file, which satisfies sshd's ownership checks.
          volume_mount {
            name       = "ssh-authorized-keys"
            mount_path = "/etc/ssh/authorized_keys"
            sub_path   = "authorized_keys"
            read_only  = true
          }
          volume_mount {
            name       = "config-volume"
            mount_path = "/config"
          }
          # Must live under /config/sshd/sshd_config.d/ for the image to include it; the
          # stock /etc/ssh/sshd_config.d/ is not read (see local.bastion_sshd_config).
          volume_mount {
            name       = "fix-sshd-config"
            mount_path = "/config/sshd/sshd_config.d/100-ifrc-forwarding.conf"
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
        # Pin the class instead of relying on a cluster default (an unset/RWX default would
        # leave the PVC Pending and the pod never starts). managed-csi is the AKS built-in
        # RWO managed-disk class.
        storage_class_name = "managed-csi"
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
    # Preserve the real client source IP (otherwise SNAT'd to a node IP), so the VERBOSE
    # sshd audit log records who connected. Matches the traefik service.
    external_traffic_policy = "Local"

    selector = {
      app = "ssh-bastion"
    }

    port {
      port        = 2222
      target_port = 2222
    }
  }
}
