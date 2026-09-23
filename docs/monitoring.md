# Monitoring

## Helm Charts
- [**kube-prometheus-stack**](https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/Chart.yaml):
    - [Grafana](https://grafana.com/)
    - [Prometheus](https://prometheus.io/)
    - [Prometheus Node Exporter](https://github.com/prometheus/node_exporter)
    - [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [**loki**](https://github.com/grafana/loki/blob/main/production/helm/loki/Chart.yaml):
    - [Loki](https://grafana.com/oss/loki/)
- [**alloy**](https://github.com/grafana/alloy/blob/main/operations/helm/charts/alloy/Chart.yaml):
    - [Grafana Alloy](https://grafana.com/docs/alloy/latest/) - runs as a DaemonSet, tails pod logs from
      `/var/log/pods` and pushes them to Loki

## Deployment
The monitoring stack is deployed using ArgoCD, with the configuration located at:

- **Staging**: [applications/argocd/staging/platform/monitoring/](https://github.com/IFRCGo/go-deploy/tree/develop/applications/argocd/staging/platform/monitoring)
- **Production**: [applications/argocd/production/platform/monitoring/](https://github.com/IFRCGo/go-deploy/tree/develop/applications/argocd/production/platform/monitoring)

> [!Important]
> All components are deployed to the `monitoring` namespace.

## Loki storage

> [!Note]
> Staging only. Production Loki still runs on the in-cluster MinIO backend.

On staging, Loki keeps its chunks and tsdb index in Azure Blob Storage rather than on
a cluster PVC, so the retention period costs blob storage instead of disk. The
statefulset keeps one small volume for the write-ahead log and the compactor's working
directory. Retention is 4380h, about six months.

The backend is Loki's [thanos object store client](https://grafana.com/docs/loki/latest/configure/)
(`loki.storage.use_thanos_objstore`). It authenticates through
`DefaultAzureCredential`, which picks up the workload identity token projected into
the pod, so no storage account key is stored anywhere.

Terraform owns the storage account, the two containers and the identity, in
[`base-infrastructure/terraform/resources/monitoring.tf`](https://github.com/IFRCGo/go-deploy/blob/develop/base-infrastructure/terraform/resources/monitoring.tf).
A blob lifecycle rule tiers chunks Hot to Cool at 30 days and Cool to Cold at 90. Both
tiers stay online, so queries over old logs need no rehydration, but they do carry a
per-GB retrieval charge that Hot does not. `max_query_lookback` spans the full
retention period, so a careless dashboard range can reach into Cold.

The thresholds are coupled to the retention period, and the terraform comment explains
the arithmetic. Changing one without the other buys early-deletion penalties.

### Cutting a cluster over

The storage account name and the identity's client id are both hardcoded in the ArgoCD
application, so `terraform apply` has to land first. Read the values back with:

```bash
cd base-infrastructure/terraform
sed -i "s/ENVIRONMENT_TO_REPLACE/$TF_VAR_environment/g" main.tf   # as apply-infra.sh does
terraform init
terraform output -json resources \
  | jq -r '{account: .monitoring_storage_account_name, clientId: .loki_workload_identity_client_id}'
```

Then set `loki.storage.object_store.azure.account_name` and
`serviceAccount.annotations."azure.workload.identity/client-id"` in
`monitoring/loki.yaml`, and only then let ArgoCD sync. Syncing with the placeholder
still in place leaves Loki authenticating as nothing and dropping every write.

Two things the cutover does not clean up:

- Logs written before the switch stay in MinIO and become unqueryable.
- The MinIO PVCs (`export-0` and `export-1`, 32Gi each) come from a statefulset
  `volumeClaimTemplate`, so ArgoCD does not prune them. Delete them by hand or they
  keep billing.

## Usage

### Retrieve Grafana Credentials
To retrieve the Grafana credentials, run the following command:

```bash
kubectl get secret -n monitoring monitoring-kube-prometheus-stack-grafana -o json \
  | jq -r '.data | {user: .["admin-user"] | @base64d, password: .["admin-password"] | @base64d}'
```

This command will decode and display the Grafana username and password.

### Forward Grafana to Localhost
To forward the Grafana service to your local machine, use the following command:

```bash
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-stack-grafana 8080:80
```

> [!Important]
> The Grafana dashboard will be accessible at [http://localhost:8080](http://localhost:8080).
