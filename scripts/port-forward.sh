#!/bin/bash
# port-forward everything to localhost
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
export KUBECONFIG="${PROJECT_DIR}/kubeconfig"

# kill existing forwards
pkill -f "kubectl port-forward" 2>/dev/null || true
sleep 1

echo "Starting port-forwards..."

kubectl port-forward svc/argocd-server -n argocd 8080:443 &>/dev/null &
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80 &>/dev/null &
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090 &>/dev/null &
kubectl port-forward svc/prometheus-kube-prometheus-alertmanager -n monitoring 9093:9093 &>/dev/null &
kubectl port-forward svc/sample-app -n app 8000:80 &>/dev/null &
kubectl port-forward svc/vault -n vault 8200:8200 &>/dev/null &

echo ""
echo "  ArgoCD:       https://localhost:8080"
echo "  Grafana:      http://localhost:3000   (admin/admin)"
echo "  Prometheus:   http://localhost:9090"
echo "  Alertmanager: http://localhost:9093"
echo "  App:          http://localhost:8000"
echo "  Vault:        http://localhost:8200   (token: root)"
echo ""

ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "check manually")
echo "  ArgoCD password: $ARGOCD_PASS"
echo ""
echo "  Ctrl+C to stop."

wait
