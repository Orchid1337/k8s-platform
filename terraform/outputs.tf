# Outputs from the k8s-platform Terraform configuration

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = module.cluster.cluster_endpoint
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file"
  value       = module.cluster.kubeconfig_path
}

output "cluster_name" {
  description = "Name of the created kind cluster"
  value       = module.cluster.cluster_name
}
