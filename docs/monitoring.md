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
- [**thanos**](https://github.com/stevehipwell/helm-charts/tree/main/charts/thanos) (repo `https://stevehipwell.github.io/helm-charts/`):
    - [Thanos](https://thanos.io/) - query, store gateway and compactor over the Prometheus
      blocks in blob storage

## Deployment
The monitoring stack is deployed using ArgoCD, with the configuration located at:

- **Staging**: [applications/argocd/staging/platform/monitoring/](https://github.com/IFRCGo/go-deploy/tree/develop/applications/argocd/staging/platform/monitoring)
- **Production**: [applications/argocd/production/platform/monitoring/](https://github.com/IFRCGo/go-deploy/tree/develop/applications/argocd/production/platform/monitoring)

> [!Important]
> All components are deployed to the `monitoring` namespace.

## Loki storage

Loki keeps its chunks and tsdb index in Azure Blob Storage rather than on
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

## Prometheus storage

A thanos sidecar in the Prometheus pod uploads each 2h TSDB block to the
`thanos-metrics` container, in the same `<prefix>aksmonitoring` storage account Loki
uses. The bucket config is the thanos objstore `AZURE` type with no key. It
authenticates through `DefaultAzureCredential` and workload identity: the pod carries
the `azure.workload.identity/use` label and its service account carries the
`azure.workload.identity/client-id` annotation. `user_assigned_id` stays unset, because
setting it switches the client to the IMDS managed identity.

The `monitoring-thanos` ArgoCD application (`monitoring/thanos.yaml`) runs thanos
query, the store gateway and the compactor. Grafana's default `Prometheus` datasource
points at thanos query, so one dashboard query reads recent data from the sidecar and
older data from the store gateway.

Retention is set on the compactor: raw blocks for 30d, 5m and 1h downsampled blocks for
4380h (about six months), matching Loki's `retention_period`. Query runs with
`--query.auto-downsampling`, so ranges older than 30d read the downsampled data.
Prometheus keeps 3d locally, enough to serve recent queries and to ride out a blob outage
without losing blocks.

Terraform owns the container, the `Thanos<Env>WorkloadIdentity` user-assigned identity,
a Storage Blob Data Contributor role on the container and one federated credential per
service account, in
[`base-infrastructure/terraform/resources/monitoring.tf`](https://github.com/IFRCGo/go-deploy/blob/develop/base-infrastructure/terraform/resources/monitoring.tf).
The federated credentials pin `monitoring-kube-prometheus-prometheus`,
`monitoring-thanos-store` and `monitoring-thanos-compactor`. Renaming any of these
service accounts breaks blob auth.

`thanos-metrics` has no lifecycle tiering. The compactor deletes raw blocks at around
30 days and deletes source blocks once it has compacted them, so Cool would bill early
deletion on most blocks.

### Cutting a cluster over

The identity's client id is hardcoded in the ArgoCD applications, so `terraform apply`
has to land first. After the same `init` as for Loki, read the values back with:

```bash
terraform output -json resources \
  | jq -r '{account: .monitoring_storage_account_name, container: .thanos_storage_container, clientId: .thanos_workload_identity_client_id}'
```

Set the client id in:

- `monitoring/kube-prometheus-stack.yaml`: the `prometheus.serviceAccount` annotation
- `monitoring/thanos.yaml`: the store gateway and compactor service account annotations

Then cut over in two syncs:

1. The first sync adds the sidecar with `shipper.upload-compacted`, which backfills the
   blocks already on the Prometheus disk, and starts the `monitoring-thanos`
   application. Grafana still reads Prometheus directly, and Prometheus keeps its
   previous local retention. Adding the sidecar restarts Prometheus, which leaves a
   short scrape gap.
2. Once the sidecar reports `thanos_shipper_upload_compacted_done == 1` and thanos
   query answers for ranges older than the cutover, point Grafana's default datasource
   at thanos query (`grafana.sidecar.datasources.url: http://monitoring-thanos-query:10902`),
   remove `upload-compacted` and set Prometheus `retention: 3d`. Local retention keeps
   deleting old blocks during step 1 whether or not they uploaded, so don't stretch
   the gap between the two syncs.

The Prometheus PVC keeps its size, since PVCs cannot shrink.

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
