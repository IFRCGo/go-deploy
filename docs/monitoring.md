# Monitoring

## Helm Charts
- [**kube-prometheus-stack**](https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/Chart.yaml):
    - [Grafana](https://grafana.com/)
    - [Prometheus](https://prometheus.io/)
    - [Prometheus Node Exporter](https://github.com/prometheus/node_exporter)
    - [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [**loki**](https://github.com/grafana/loki/blob/main/production/helm/loki/Chart.yaml):
    - [Loki](https://grafana.com/oss/loki/)
- [**promtail**](https://github.com/grafana/helm-charts/blob/main/charts/promtail/Chart.yaml):
    - [Promtail](https://grafana.com/docs/loki/latest/send-data/promtail/)

## Deployment
The monitoring stack is deployed using ArgoCD, with the configuration located at:

- **Staging**: [applications/argocd/staging/platform/monitoring/](https://github.com/IFRCGo/go-deploy/tree/develop/applications/argocd/staging/platform/monitoring)
- **Production**: [applications/argocd/production/platform/monitoring/](https://github.com/IFRCGo/go-deploy/tree/develop/applications/argocd/production/platform/monitoring)

> [!Important]
> All components are deployed to the `monitoring` namespace.

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
