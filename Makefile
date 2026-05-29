.PHONY: help bootstrap teardown port-forward lint test build scan sync rollback status logs verify clean

SHELL := /bin/bash
.DEFAULT_GOAL := help

PROJECT_NAME := k8s-platform
KUBECONFIG := $(shell pwd)/kubeconfig
ARGOCD_APP := sample-app
API_IMAGE := ghcr.io/Orchid1337/k8s-platform-api
FRONTEND_IMAGE := ghcr.io/Orchid1337/k8s-platform-frontend

export KUBECONFIG

help: ## show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

bootstrap: ## stand up the full platform
	@chmod +x scripts/bootstrap.sh
	@./scripts/bootstrap.sh

teardown: ## destroy everything
	@chmod +x scripts/teardown.sh
	@./scripts/teardown.sh

port-forward: ## forward all services to localhost
	@chmod +x scripts/port-forward.sh
	@./scripts/port-forward.sh

lint: ## run linters
	@echo "yamllint..."
	yamllint -d relaxed kubernetes/ argocd/ monitoring/ ansible/ helm/app/Chart.yaml helm/app/values.yaml helm/app/values-production.yaml helm/monitoring/Chart.yaml helm/monitoring/values.yaml
	@echo "hadolint..."
	hadolint app/api/Dockerfile
	hadolint app/frontend/Dockerfile
	@echo "flake8..."
	cd app/api && flake8 . --max-line-length=120 --exclude=__pycache__,tests
	@echo "ok"

test: ## run tests
	cd app/api && python -m pytest tests/ -v --tb=short

build: ## build docker images
	docker build -t $(API_IMAGE):latest app/api/
	docker build -t $(FRONTEND_IMAGE):latest app/frontend/

scan: ## trivy scan images
	trivy image --severity HIGH,CRITICAL --ignore-unfixed $(API_IMAGE):latest
	trivy image --severity HIGH,CRITICAL --ignore-unfixed $(FRONTEND_IMAGE):latest

sync: ## force argocd sync
	argocd app sync $(ARGOCD_APP) --force --prune
	argocd app sync monitoring --force --prune

rollback: ## rollback sample-app
	argocd app rollback $(ARGOCD_APP)

status: ## cluster status
	@echo "--- nodes ---"
	@kubectl get nodes -o wide 2>/dev/null || echo "cluster not reachable"
	@echo ""
	@echo "--- pods ---"
	@kubectl get pods -A --sort-by=.metadata.namespace 2>/dev/null || echo "cluster not reachable"
	@echo ""
	@echo "--- argocd apps ---"
	@kubectl get applications -n argocd 2>/dev/null || echo "argocd not installed"
	@echo ""
	@echo "--- hpa ---"
	@kubectl get hpa -n app 2>/dev/null || echo "no hpa"

logs: ## tail app logs
	kubectl logs -n app -l app.kubernetes.io/name=sample-app --tail=100 -f

verify: ## run smoke tests against running cluster
	@echo "--- smoke tests ---"
	@kubectl get nodes --no-headers | wc -l | xargs -I{} bash -c '[ {} -ge 3 ] && echo "[+] Nodes: {}" || echo "[-] Expected 3 nodes, got {}"'
	@kubectl get deployment argocd-server -n argocd &>/dev/null && echo "[+] ArgoCD running" || echo "[-] ArgoCD missing"
	@kubectl get deployment prometheus-grafana -n monitoring &>/dev/null && echo "[+] Grafana running" || echo "[-] Grafana missing"
	@kubectl get deployment ingress-nginx-controller -n ingress-nginx &>/dev/null && echo "[+] Ingress running" || echo "[-] Ingress missing"
	@kubectl get pod vault-0 -n vault &>/dev/null && echo "[+] Vault running" || echo "[-] Vault missing"
	@kubectl get statefulset prometheus-prometheus-kube-prometheus-prometheus -n monitoring &>/dev/null && echo "[+] Prometheus running" || echo "[-] Prometheus missing"
	@echo "--- done ---"

clean: ## remove generated files
	rm -rf kubeconfig .certs/
	rm -rf terraform/.terraform terraform/terraform.tfstate*
	rm -rf app/api/__pycache__ app/api/.pytest_cache
