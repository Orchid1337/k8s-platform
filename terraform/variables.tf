# Input variables for the k8s-platform Terraform configuration

variable "cluster_name" {
  description = "Name of the kind Kubernetes cluster"
  type        = string
  default     = "k8s-platform"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.cluster_name))
    error_message = "Cluster name must start with a letter and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for the kind cluster nodes"
  type        = string
  default     = "v1.29.2"
}

variable "worker_count" {
  description = "Number of worker nodes in the cluster"
  type        = number
  default     = 2

  validation {
    condition     = var.worker_count >= 1 && var.worker_count <= 5
    error_message = "Worker count must be between 1 and 5 for local development."
  }
}
