# IFRC GO Deployment (Work in Progress)

> [!Note]
> This repository is still work in progress and not being used to manage GO deployments yet.

This repository hosts the configuration files and scripts required for deploying Kubernetes clusters for the IFRC GO ecosystem, as well as for deploying IFRC GO ecosystem applications onto these clusters.

## Structure

The repository is structured as follows:

- `base-infrastructure`: Contains the Terraform configuration files for deploying the Kubernetes clusters and other infrastructure components like managed databases, object storage etc on Azure.

- `applications/go-api`: Contains the deployment scripts and Helm configurations for deploying Helm charts of IFRC GO ecosystem applications onto the Kubernetes clusters.
- `applications/argocd`: Contains the definitions of kubernetes resoures for managing applications whose deployment is managed by [ArgoCD](https://argo-cd.readthedocs.io/en/stable/). 


## Monitoring
Detail here [./docs/monitoring.md](./docs/monitoring.md)


## Pre-commit (locally)

- Install tenv (version manager for terraform): https://github.com/tofuutils/tenv#installation
- Install tflint: https://github.com/terraform-linters/tflint?tab=readme-ov-file#installation

```bash
pre-commit run --color=always --all-files
```
