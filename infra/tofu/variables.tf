variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "vpc_uuid" {
  description = "UUID of the existing VPC (run: doctl vpcs list)"
  type        = string
  default     = "9190e0e9-f6dd-41e1-aa57-8d8fb2269ba4"
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "sfo3"
}

variable "k8s_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.36.0-do.3"
}

variable "node_size" {
  description = "Droplet size for nodes"
  type        = string
  default     = "s-2vcpu-4gb"
}