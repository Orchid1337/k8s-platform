# k8s-platform

Production-grade Kubernetes platform running locally. One command sets up a full environment with GitOps, monitoring, security, and a deployed application — no cloud account needed.

![Kubernetes](https://img.shields.io/badge/Kubernetes-1.29-326CE5?logo=kubernetes&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-1.5+-7B42BC?logo=terraform&logoColor=white)
![ArgoCD](https://img.shields.io/badge/ArgoCD-2.10-EF7B4D?logo=argo&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-2.49-E6522C?logo=prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-10.3-F46800?logo=grafana&logoColor=white)
![Vault](https://img.shields.io/badge/Vault-1.15-FFEC6E?logo=vault&logoColor=black)

---

## What is this?

This project simulates a real company's production infrastructure on your laptop. In companies like Netflix, Spotify, or any serious startup, applications run on Kubernetes with:

- Automated deployments triggered by git push
- Dashboards showing CPU, memory, request rates, error rates
- Alerts that fire when something breaks
- Network security blocking unauthorized traffic
- Secrets stored securely (not in plain text)
- CI/CD pipelines that test and scan code before deploying

This project does all of that locally in Docker. Useful as a portfolio piece, learning environment, or reference for real projects.

---

## What you get

After running `make bootstrap` (~10 min on first run):

```
┌─────────────────────────────────────────────────────────────┐
│  3-node Kubernetes cluster (kind)                           │
│                                                             │
│  ├── Sample App (FastAPI, 2 replicas, health checks)        │
│  ├── ArgoCD (auto-deploys when you push to git)             │
│  ├── Grafana (dashboards with live metrics)                 │
│  ├── Prometheus (collects metrics from everything)          │
│  ├── Alertmanager (sends alerts when things break)          │
│  ├── Vault (secrets management)                             │
│  ├── cert-manager (TLS certificates)                        │
│  ├── ingress-nginx (routes traffic)                         │
│  └── Network policies (zero-trust, deny by default)         │
└─────────────────────────────────────────────────────────────┘
```

---

## Quick start

### 1. Install prerequisites

| Tool | Windows | Mac |
|------|---------|-----|
| Docker | [Docker Desktop](https://docs.docker.com/desktop/install/windows-install/) | `brew install --cask docker` |
| kubectl | `winget install Kubernetes.kubectl` | `brew install kubectl` |
| Helm | `winget install Helm.Helm` | `brew install helm` |
| Terraform | `winget install Hashicorp.Terraform` | `brew install terraform` |
| kind | `winget install Kubernetes.kind` | `brew install kind` |
| ArgoCD CLI | [GitHub releases](https://github.com/argoproj/argo-cd/releases) | `brew install argocd` |

### 2. Start the platform

```bash
git clone https://github.com/Orchid1337/k8s-platform
cd k8s-platform
make bootstrap
```

### 3. Access services

```bash
make port-forward
```

Then open in your browser:

| Service | URL | Login |
|---------|-----|-------|
| **App** | http://localhost:8000 | — |
| **Grafana** | http://localhost:3000 | admin / admin |
| **ArgoCD** | https://localhost:8080 | admin / (shown in terminal) |
| **Prometheus** | http://localhost:9090 | — |
| **Vault** | http://localhost:8200 | token: root |

> ArgoCD uses a self-signed cert — click "Advanced → Proceed" if your browser warns you.

### 4. What to try

- **Grafana**: Click the ☰ menu (top-left) → Dashboards → pick "Kubernetes / Compute Resources / Cluster" — live graphs
- **Prometheus**: Type `up` in the query box → Execute — shows all monitored targets
- **App**: Returns `{"status": "ok", "version": "1.0.0"}`
- **Vault**: Secrets Engines → secret → create a secret

### 5. Tear it down

```bash
make teardown
```

---

## How it works

```
You push code
     ↓
GitHub Actions: lint → test → build → scan
     ↓
Docker image pushed to registry
     ↓
Deploy pipeline updates Helm values with new image tag
     ↓
ArgoCD detects change in git → syncs to cluster
     ↓
Rolling update (zero downtime)
     ↓
Prometheus scrapes metrics from new pods
     ↓
Grafana shows it on dashboards
     ↓
If error rate spikes → Alertmanager sends notification
```

**Self-healing**: If someone manually changes something on the cluster, ArgoCD reverts it.

**Auto-prune**: If you delete a resource from git, ArgoCD deletes it from the cluster.

---

## Tech stack

| Tool | Version | What it does |
|------|---------|--------------|
| Kubernetes (kind) | 1.29 | Runs containers, manages workloads |
| Terraform | 1.5+ | Creates the cluster (Infrastructure as Code) |
| Helm | 3.14+ | Packages and deploys the application |
| ArgoCD | 2.10 | GitOps — auto-deploys from git |
| Prometheus | 2.49+ | Collects metrics (CPU, memory, requests) |
| Grafana | 10.3+ | Visualizes metrics as dashboards |
| Alertmanager | 0.27+ | Routes alerts (e.g. to Slack) |
| Loki | 2.9 | Aggregates logs from all pods |
| Vault | 1.15 | Manages secrets securely |
| Trivy | 0.49+ | Scans images for vulnerabilities |
| cert-manager | 1.14 | Automates TLS certificates |
| ingress-nginx | 4.9 | Routes external traffic to services |
| FastAPI | 0.109 | Sample application framework |

---

## Security

| Layer | What's enforced |
|-------|----------------|
| **Network** | Default-deny in app namespace, only ingress + DNS allowed |
| **Pods** | Non-root, read-only filesystem, no privilege escalation, drop all capabilities |
| **Namespace** | Restricted Pod Security Standards on app namespace |
| **Secrets** | Vault with Kubernetes auth (no secrets in git) |
| **CI/CD** | Trivy image scan, Checkov IaC scan, Gitleaks secret detection |
| **TLS** | cert-manager with auto-renewal |
| **RBAC** | Least-privilege roles per team |

---

## CI/CD pipelines

**On every push** (`ci.yml`):
```
lint (hadolint, yamllint, flake8) → test (pytest) → build (multi-arch) → scan (trivy) → sonarqube
```

**On push to main** (`deploy.yml`):
```
build image with git SHA → push to GHCR → update helm values → ArgoCD syncs → smoke test
```

**Weekly + on PRs** (`security-scan.yml`):
```
trivy filesystem scan → trivy k8s manifest scan → checkov IaC scan → gitleaks secret scan
```

---

## Commands

```bash
make bootstrap      # set up everything from scratch
make teardown       # destroy the cluster
make port-forward   # access services in browser
make status         # show cluster health
make lint           # run all linters
make test           # run unit tests
make build          # build docker images
make scan           # trivy vulnerability scan
make sync           # force ArgoCD sync
make rollback       # rollback to previous version
make logs           # tail application logs
make clean          # remove generated files
```

---

## Project structure

```
k8s-platform/
├── app/                    # Sample application (FastAPI + nginx)
│   ├── api/                #   Python API with health checks + metrics
│   └── frontend/           #   Static frontend served by nginx
├── terraform/              # Cluster provisioning (kind via Terraform)
├── helm/                   # Helm charts
│   ├── app/                #   Application chart (deployment, service, hpa, netpol...)
│   └── monitoring/         #   Custom PrometheusRules + Grafana dashboards
├── argocd/                 # GitOps configuration
│   ├── apps/               #   Application definitions (app-of-apps pattern)
│   └── projects/           #   AppProject with namespace restrictions
├── kubernetes/             # Base cluster resources
│   ├── namespaces/         #   Namespaces + ResourceQuotas + LimitRanges
│   ├── rbac/               #   Roles and bindings
│   ├── network-policies/   #   Default-deny + allow rules
│   ├── pod-security/       #   Pod Security Standards
│   └── vault/              #   Vault installation
├── monitoring/             # Observability
│   ├── prometheus/         #   Alerting rules
│   ├── grafana/dashboards/ #   Dashboard JSON files
│   ├── loki/               #   Log aggregation
│   └── alertmanager/       #   Alert routing config
├── ansible/                # Configuration management (k3s alternative)
├── .github/workflows/      # CI/CD pipelines
├── scripts/                # Bootstrap, teardown, port-forward
├── docs/                   # Architecture, deployment guide, lessons learned
└── Makefile                # All commands in one place
```

---

## Lessons learned

Real problems I hit while building this and how I fixed them:

1. **Kind port mappings only work on control-plane nodes** — workers don't get Docker port mappings
2. **ArgoCD needs both prune AND selfHeal** — one without the other leaves zombie resources
3. **Trivy `--ignore-unfixed` is mandatory** — base images have CVEs nobody has patched yet
4. **ReadOnlyRootFilesystem breaks Python** — need a writable /tmp via emptyDir
5. **HPA fights GitOps replica counts** — use `ignoreDifferences` in ArgoCD
6. **Default-deny NetworkPolicy breaks DNS** — always pair with explicit DNS egress allow
7. **Prometheus rules need `release: prometheus` label** — or they're invisible to the operator
8. **Never check dependencies in liveness probes** — causes cascading restarts
9. **PDB is non-negotiable** — without it, node drains kill all pods at once
10. **CI commits need `[skip ci]`** — or you get infinite pipeline loops

Detailed write-up: [docs/lessons-learned.md](docs/lessons-learned.md)

---

## License

MIT
