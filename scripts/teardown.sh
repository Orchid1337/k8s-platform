#!/bin/bash
# tear it all down
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

info() { echo "[*] $1"; }
ok()   { echo "[+] $1"; }
warn() { echo "[!] $1"; }

# kill port-forwards
info "Killing port-forwards..."
pkill -f "kubectl port-forward" 2>/dev/null || true

# terraform destroy
info "Destroying cluster..."
cd "$PROJECT_DIR/terraform"
if [ -f "terraform.tfstate" ]; then
    terraform destroy -auto-approve -input=false
    ok "Cluster destroyed"
else
    warn "No terraform state found, trying kind directly"
    kind delete cluster --name k8s-platform 2>/dev/null || true
fi

# cleanup
info "Cleaning up kubeconfig..."
rm -f "$PROJECT_DIR/kubeconfig"
kubectl config delete-context kind-k8s-platform 2>/dev/null || true
kubectl config delete-cluster kind-k8s-platform 2>/dev/null || true
kubectl config delete-user kind-k8s-platform 2>/dev/null || true

docker image prune -f 2>/dev/null || true

ok "Done. Run 'make bootstrap' to recreate."
