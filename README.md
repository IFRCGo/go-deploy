# IFRC GO Deployment

This repository hosts the configuration files and scripts required for deploying Kubernetes clusters for the IFRC GO ecosystem, as well as for deploying IFRC GO ecosystem applications onto these clusters.

## Structure

The repository is structured as follows:

- `base-infrastructure`: Contains the Terraform configuration files for deploying the Kubernetes clusters and other infrastructure components like managed databases, object storage etc on Azure.

- `applications`: Contains the deployment scripts and Helm configurations for deploying Helm charts of IFRC GO ecosystem applications onto the Kubernetes clusters.
