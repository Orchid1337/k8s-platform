# Outputs from the cluster module

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = kind_cluster.platform.endpoint
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file"
  value       = local_file.kubeconfig.filename
}

output "cluster_name" {
  description = "Name of the kind cluster"
  value       = kind_cluster.platform.name
}
