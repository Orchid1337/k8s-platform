# Networking module — configures cluster networking prerequisites
# Applies after the cluster is created

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Wait for the cluster to be fully ready before applying networking
resource "null_resource" "wait_for_cluster" {
  provisioner "local-exec" {
    command = "kubectl wait --for=condition=Ready nodes --all --timeout=120s --kubeconfig=../kubeconfig"
  }
}

# Apply the MetalLB configuration for LoadBalancer services in kind
# This enables LoadBalancer-type services to get external IPs locally
resource "null_resource" "install_metallb" {
  depends_on = [null_resource.wait_for_cluster]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml --kubeconfig=../kubeconfig
      kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=120s --kubeconfig=../kubeconfig
    EOT
  }
}

# Configure MetalLB IP address pool
# Uses the Docker network subnet for kind
resource "null_resource" "configure_metallb" {
  depends_on = [null_resource.install_metallb]

  provisioner "local-exec" {
    command = <<-EOT
      cat <<EOF | kubectl apply --kubeconfig=../kubeconfig -f -
      apiVersion: metallb.io/v1beta1
      kind: IPAddressPool
      metadata:
        name: default-pool
        namespace: metallb-system
      spec:
        addresses:
          - 172.18.255.200-172.18.255.250
      ---
      apiVersion: metallb.io/v1beta1
      kind: L2Advertisement
      metadata:
        name: default
        namespace: metallb-system
      spec:
        ipAddressPools:
          - default-pool
      EOF
    EOT
  }
}
