# Agent instructions

## Azure resource tags

Terraform root: `base-infrastructure/terraform`.

- Base tags are defined once in `base-infrastructure/terraform/tags.tf` as `local.base_tags` (`DeployedBy`, `Owner`, `Contact`, `Service`, `Ticket`, and `Environment` from `var.environment`). Change tag values only in `tags.tf`.
- Each module (`resources`, `app_resources`, `registry`) has a required `tags` input. Each module call in the root passes `tags = local.base_tags`.
- Each new Azure resource that supports `tags` must set `tags = var.tags`, or `merge(var.tags, {...})` for extra keys (AKS uses `local.aks_tags`). azurerm has no provider-level default tags, so a resource without a `tags` argument is untagged.
- A new module takes the same required `tags` variable, and the root passes `local.base_tags`.
- The CI principal has no rights on the AKS node resource group (`MC_*`). Terraform must not create or update anything there, or update anything that links to it: `azurerm_virtual_network` ignores `tags` because its update is checked against the AKS route table in `MC_*`.
- In the node resource group, AKS copies the cluster tags to the resource group and the node pool tags to the VMSS. Resources Kubernetes creates at runtime (PVC disks, load balancer IPs) are tagged by hand.
- Resources this Terraform does not tag are tagged by hand with `az tag update --operation Merge`: resource groups, the shared ACR, the go-api DB and storage, the Terraform state storage, the cluster vnet, `azurerm_public_ip.ifrcgo` (`ignore_changes = all`), and runtime resources in the node resource group.
