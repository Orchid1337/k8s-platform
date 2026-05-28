# Variables for the cluster module

variable "cluster_name" {
  description = "Name of the kind cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for cluster nodes"
  type        = string
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
}
