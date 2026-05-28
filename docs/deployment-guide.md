# Deployment Guide

## Prerequisites

| Tool       | Min version | Why                    |
|-----------|-------------|------------------------|
| Docker    | 24.0+       | runs the kind cluster  |
| kubectl   | 1.28+       | cluster interaction    |
| Helm      | 3.14+       | chart installs         |
| Terraform | 1.5+        | cluster provisioning   |
| ArgoCD CLI| 2.10+       | sync/rollback commands |

## One-command setup

```bash
git clone https://github.com/Orchid1337/k8s-platform
cd k8s-platform
make bootstrap
```

Takes about 5-10 minutes depending on your internet. Downloads container images, installs everything.

## What bootstrap does (in order)

1. Checks you have all the tools installed
2. `terraform apply` — creates kind cluster (1 cp + 2 workers)
3. Waits for nodes to be Ready
4. Applies namespaces, RBAC, network policies
5. Installs cert-manager via helm
6. Installs ingress-nginx via helm
7. Installs ArgoCD from official manifests
8. Applies the app-of-apps (which triggers everything else)
9. Installs kube-prometheus-stack via helm
10. Installs Vault in dev mode

## Accessing services

```bash
make port-forward
```

Then open your browser. Grafana is at :3000, ArgoCD at :8080, app at :8000.

## Deploying updates

### The GitOps way (recommended)

1. Change code in `app/`
2. Push to a branch, CI runs
3. Merge to main
4. Deploy pipeline builds image, updates `helm/app/values.yaml` with new tag
5. ArgoCD picks it up and syncs

### Manual

```bash
docker build -t ghcr.io/Orchid1337/k8s-platform-api:mytag app/api/
# update helm/app/values.yaml image.tag
argocd app sync sample-app
```

## Rollback

```bash
make rollback
# or
argocd app rollback sample-app
# or use the ArgoCD UI: History tab → pick a revision → Rollback
```

## Troubleshooting

**Pods not starting:**
```bash
kubectl describe pod -n app -l app.kubernetes.io/name=sample-app
kubectl logs -n app -l app.kubernetes.io/name=sample-app --previous
```

**ArgoCD out of sync:**
```bash
argocd app get sample-app
argocd app diff sample-app
```

**Network issues:**
```bash
# spin up a debug pod and test connectivity
kubectl run debug --image=busybox --rm -it --restart=Never -- wget -qO- http://sample-app.app.svc.cluster.local/health
```

**Everything is broken:**
```bash
make teardown
make bootstrap  # start fresh
```
