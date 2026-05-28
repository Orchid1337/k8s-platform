#!/bin/bash
# bootstrap the whole platform from scratch. idempotent, run it as many times as you want.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

info() { echo "[*] $1"; }
ok()   { echo "[+] $1"; }
warn() { echo "[!] $1"; }
err()  { echo "[-] $1"; }

check_command() {
    if ! command -v "$1" &> /dev/null; then
        err "$1 not found. Install it."
        return 1
    fi
}

# --- prereqs ---
info "Checking prerequisites..."

MISSING=0
for cmd in docker kubectl helm terraform argocd; do
    if ! check_command "$cmd"; then
        MISSING=1
    fi
done

if [ "$MISSING" -eq 1 ]; then
    err "Missing tools. Install them and try again."
    exit 1
fi

if ! docker info &> /dev/null; then
    err "Docker isn't running."
    exit 1
fi

# --- cluster ---
info "Creating cluster with terraform..."
cd "$PROJECT_DIR/terraform"
terraform init -input=false
terraform apply -auto-approve -input=false
export KUBECONFIG="$PROJECT_DIR/kubeconfig"
ok "Cluster up"

# --- wait for nodes ---
info "Waiting for nodes..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s
ok "Nodes ready"

# --- base resources ---
info "Applying namespaces and RBAC..."
kubectl apply -f "$PROJECT_DIR/kubernetes/namespaces/namespaces.yaml"
kubectl apply -f "$PROJECT_DIR/kubernetes/rbac/roles.yaml"
kubectl apply -f "$PROJECT_DIR/kubernetes/rbac/rolebindings.yaml"
ok "Base resources applied"

# --- cert-manager ---
info "Installing cert-manager..."
helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --set installCRDs=true \
    --wait --timeout 120s
ok "cert-manager done"

# --- ingress ---
info "Installing ingress-nginx..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.service.type=NodePort \
    --set controller.service.nodePorts.http=30080 \
    --set controller.service.nodePorts.https=30443 \
    --set controller.metrics.enabled=true \
    --wait --timeout 120s
ok "ingress-nginx done"

# --- argocd ---
info "Installing ArgoCD..."
kubectl apply -f "$PROJECT_DIR/argocd/install/argocd-install.yaml"
kubectl apply -n argocd \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.1/manifests/install.yaml
kubectl wait --namespace argocd \
    --for=condition=Available deployment/argocd-server \
    --timeout=300s
ok "ArgoCD done"

# --- app-of-apps ---
info "Bootstrapping app-of-apps..."
kubectl apply -f "$PROJECT_DIR/argocd/projects/platform.yaml"
kubectl apply -f "$PROJECT_DIR/argocd/apps/app-of-apps.yaml"
ok "App-of-apps applied"

# --- monitoring ---
info "Installing monitoring stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace \
    --set grafana.adminPassword=admin \
    --set grafana.sidecar.dashboards.enabled=true \
    --set prometheus.prometheusSpec.retention=7d \
    --wait --timeout 300s
kubectl apply -f "$PROJECT_DIR/monitoring/prometheus/alerting-rules.yaml"
kubectl apply -f "$PROJECT_DIR/monitoring/loki/loki-stack.yaml"
ok "Monitoring done"

# --- vault ---
info "Installing Vault..."
kubectl apply -f "$PROJECT_DIR/kubernetes/vault/vault-install.yaml"
kubectl wait --namespace vault \
    --for=condition=Ready pod/vault-0 \
    --timeout=120s 2>/dev/null || warn "Vault pod not ready yet (might need manual init)"
kubectl apply -f "$PROJECT_DIR/kubernetes/vault/vault-config.yaml" 2>/dev/null || true
ok "Vault done"

# --- done ---
echo ""
echo "Platform is ready."
echo ""
echo "  Run 'make port-forward' to access services:"
echo "    ArgoCD:     https://localhost:8080"
echo "    Grafana:    http://localhost:3000  (admin/admin)"
echo "    Prometheus: http://localhost:9090"
echo "    App:        http://localhost:8000"
echo "    Vault:      http://localhost:8200"
echo ""
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "not available yet")
echo "  ArgoCD login: admin / $ARGOCD_PASS"
