# Drops the `ifrcgo-helm` release from Terraform's state without uninstalling it from the
# cluster's `default` namespace.
removed {
  from = helm_release.ifrcgo

  lifecycle {
    destroy = false
  }
}
