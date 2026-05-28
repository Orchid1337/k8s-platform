# Variables for the networking module

variable "cluster_name" {
  description = "Name of the kind cluster (used for Docker network discovery)"
  type        = string
}
