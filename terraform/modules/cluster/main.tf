terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.4.0"
    }
  }
}

resource "kind_cluster" "platform" {
  name           = var.cluster_name
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role  = "control-plane"
      image = "kindest/node:${var.kubernetes_version}"

      # NOTE: port mappings only work on control-plane in kind
      extra_port_mappings {
        container_port = 80
        host_port      = 80
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = 443
        host_port      = 443
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = 30000
        host_port      = 30000
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = 30001
        host_port      = 30001
        protocol       = "TCP"
      }

      kubeadm_config_patches = [
        <<-PATCH
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
        PATCH
      ]
    }

    dynamic "node" {
      for_each = range(var.worker_count)
      content {
        role  = "worker"
        image = "kindest/node:${var.kubernetes_version}"
      }
    }

    networking {
      disable_default_cni = false
      pod_subnet          = "10.244.0.0/16"
      service_subnet      = "10.96.0.0/16"
    }
  }
}

resource "local_file" "kubeconfig" {
  content         = kind_cluster.platform.kubeconfig
  filename        = "${path.root}/../kubeconfig"
  file_permission = "0600"
}
