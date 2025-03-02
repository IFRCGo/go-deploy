# Deployment Configuration

The main components involved in setting up an application on the IFRCGo Kubernetes cluster are the following:
  1. ArgoCD for deployments
  2. Azure KeyVault for managing secrets
  3. Azure Workload Identities
  4. Application Resources Terraform Module
  5. Common Container Registry

## 1. ArgoCD
ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. It helps in automating the deployment and lifecycle management of applications.

We utilize the **Apps of Apps pattern** in our ArgoCD setup. Each environment has a `platform` and an `applications` folder:
- The `platform` folder manages tools with cluster-wide scope, such as:
  - **ArgoCD Image Updater**: Automatically updates application images to their latest versions.
  - **Stakater Reloader**: Dynamically reloads configuration changes without requiring manual intervention.
- The `applications` folder contains custom IFRC applications. For each application, we define ArgoCD Application resources that specify the Helm chart of the application along with various parameters it requires.

This structure ensures a modular and scalable approach to managing deployments across different environments. Updates are done, for example, by changing the helm chart version on the 'Application' resource of the respective application as can be seen in the example below:
```
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: alert-hub-frontend
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: ghcr.io/ifrcgo/alert-hub-web-app
    chart: ifrcgo-web-app-nginx-serve
    targetRevision: <specify-helm-chart-version-here>
```

### Accessing the ArgoCD UI
The ArgoCD UI can be accessed locally by using the following command:
```bash
kubectl -n argocd port-forward svc/argo-cd-argocd-server <host-port>:80
```
Within the ArgoCD UI you can inspect the sync-status and any possible errors in the applications managed by ArgoCD.

## 2. Azure KeyVault Managed Secrets

Azure Key Vault is used to securely store and manage sensitive information such as passwords, certificates, and keys. To integrate an AKS (Azure Kubernetes Service) cluster with Azure Key Vault, the **Azure Key Vault Provider for Secrets Store CSI Driver** is utilized. This driver allows secrets stored in Azure Key Vault to be mounted into pods as volumes or injected into the Kubernetes environment.

#### Integration Process:
1. **Enable the Azure Key Vault Provider for Secrets Store CSI Driver**:
   - Install the Secrets Store CSI Driver on your AKS cluster using Helm or by enabling it through the Azure CLI.
   - Ensure that the AKS cluster has the necessary permissions to access the Azure Key Vault.

2. **Create a `SecretProviderClass`**:
   - The `SecretProviderClass` is a custom resource that defines how secrets from Azure Key Vault are synchronized with Kubernetes. It specifies the Azure Key Vault configuration and the objects (secrets, certificates, etc.) to be synced.

3. **Mount Secrets into Pods**:
   - Use the `SecretProviderClass` to mount secrets as volumes in your pod manifests or inject them as environment variables.

#### Example of a `SecretProviderClass` Manifest:
Below is an example of a `SecretProviderClass` manifest that configures the integration (this is typically contained within the application's Helm Chart):

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-keyvault-secretprovider
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"                # Set to "true" if using pod-managed identity
    useVMManagedIdentity: "true"           # Set to "true" if using VM-managed identity
    userAssignedIdentityID: "<identity-id>" # Optional: Specify the user-assigned managed identity ID
    keyvaultName: "mykeyvault"             # Name of the Azure Key Vault
    cloudName: "azurepubliccloud"          # Cloud environment (e.g., azurepubliccloud, azurechinacloud)
    objects: |
      array:
        - |
          objectName: mysecret            # Name of the secret in Azure Key Vault
          objectType: secret              # Type of the object (secret, certificate, key)
          objectAlias: myapp/secret       # Alias for the object in Kubernetes
        - |
          objectName: mycertificate       # Name of the certificate in Azure Key Vault
          objectType: cert                # Type of the object (secret, certificate, key)
          objectAlias: myapp/certificate  # Alias for the object in Kubernetes
    tenantId: "<tenant-id>"               # Tenant ID of the Azure Active Directory
```

On the kubernetes `Deployment` you require this annotation to ensure that [Stakater Reloader](https://github.com/stakater/Reloader) automatically reloads the application whenever secrets are altered on the Azure Key Vault. This is possible because the integration periodically polls for secret changes on respective Azure Key Vaults.
This setup ensures that only Azure users with appropriate permissions on the respective application's keyvault are able to change application secrets (API Keys, DB Passwords etc.)

## 3. Workload Identities
Workload Identities allow Kubernetes workloads to authenticate with Azure services without the need for explicit credentials. This enhances security by minimizing the exposure of sensitive information. Through the use of Kubernetes service accounts we can grant individual pods the necessary permissions to access only their KeyVault and Storage account.

## 4. Application Resources Terraform Module
The Application Resources Terraform Module is used to define and provision the necessary infrastructure and resources for the application in a consistent and repeatable manner. The module creates the application's key-vault, any storage containers, a database on a specified server id as well as an Azure Workload Identity for the application with appropriate permissions on the aforementioned resources. Typical usage of the module would look like this:
```
module "some_application_resources" {
  source = "./app_resources"

  app_name            = "<application-name>"
  environment         = var.environment
  resource_group_name = module.resources.resource_group

  aks_config = {
    cluster_namespace       = "<namespace>"
    cluster_oidc_issuer_url = module.resources.cluster_oidc_issuer_url
    service_account_name    = "<service-account-name>"
  }

  database_config = {
    create_database = true
    database_name   = <db-name>
    server_id       = <azure-flexible-posgresql-server-id>
  }

  secrets = {
    DB_ADMIN_PASSWORD = module.resources.db_admin_password
  }

  storage_config = {
    container_refs = [
      {
        container_ref = "media"
        access_type   = "private"
      },
      {
        container_ref = "static"
        access_type   = "blob"
      }
    ]

    enabled              = true
    storage_account_id   = module.resources.storage_account_id
    storage_account_name = module.resources.storage_account_name
  }

  vault_admin_ids = [
    <azure-ad-id1>,
    <azure-ad-id2>
  ]
}
```

## 5. Common Container Registry
The Common Container Registry is a centralized repository for storing and managing Docker container images. It ensures that all necessary container images are readily available for deployment. Within the terraform code is contained the integration between the container registry and the AKS cluster's kubelets such that imagePullSecrets are not required in most cases.
