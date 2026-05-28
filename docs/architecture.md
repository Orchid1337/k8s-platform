# Architecture

## How it fits together

```
Developer → push to GitHub → CI runs (lint, test, build, scan)
                                ↓
                          Image pushed to GHCR
                                ↓
                    Deploy pipeline updates helm values
                                ↓
                    ArgoCD detects change, syncs to cluster
                                ↓
                    Rolling update, zero downtime
                                ↓
                    Prometheus scrapes metrics
                    Loki collects logs
                    Alertmanager fires if something's wrong
```

## Cluster layout

| Namespace      | What's in it                | Pod Security |
|---------------|----------------------------|--------------|
| app           | Sample app (FastAPI)        | restricted   |
| monitoring    | Prometheus, Grafana, Loki   | baseline     |
| argocd        | ArgoCD server + controllers | baseline     |
| ingress-nginx | Ingress controller          | baseline     |
| vault         | HashiCorp Vault (dev mode)  | baseline     |
| cert-manager  | TLS cert automation         | baseline     |

## Network model

Zero-trust in the app namespace:

1. Default deny all ingress + egress
2. Explicit allow: ingress from ingress-nginx on port 8000
3. Explicit allow: egress to kube-dns (port 53)
4. Explicit allow: ingress from monitoring (prometheus scrape)

Everything else is blocked. If the app needs to talk to an external service, you add a NetworkPolicy for it.

## Observability

- **Metrics**: Prometheus scrapes `/metrics` from the app (via pod annotations). kube-state-metrics and node-exporter provide cluster-level metrics.
- **Dashboards**: Grafana with two custom dashboards — cluster overview and app metrics. Auto-discovered via sidecar.
- **Logs**: Promtail DaemonSet ships pod logs to Loki. JSON format so you can filter by level, namespace, pod.
- **Alerts**: PrometheusRules → Alertmanager → Slack (webhook placeholder). Grouped by severity.

## Why kind and not minikube/k3d

Kind uses actual kubeadm under the hood, so the cluster behaves more like a real one. Multi-node support is straightforward. Port mappings are a bit annoying (only work on control-plane) but it's the closest to production you'll get locally.

For a k3s-based alternative, the ansible playbooks are there — just point them at real VMs.
