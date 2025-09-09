variable "cluster_name" {
  description = "Name of the K3s cluster"
  type        = string
  default     = "k3s-cluster"
}

variable "worker_count" {
  description = "Number of K3s worker nodes"
  type        = number
  default     = 3
}

variable "container_image" {
  description = "Container image to use for instances"
  type        = string
  default     = "images:debian/13/cloud"
}

variable "cpu_limit" {
  description = "CPU limit for containers"
  type        = string
  default     = "2"
}

variable "memory_limit" {
  description = "Memory limit for containers"
  type        = string
  default     = "6GB"
}

variable "disk_size" {
  description = "Disk size for containers"
  type        = string
  default     = "30GB"
}

variable "network_cidr" {
  description = "Network CIDR for the cluster"
  type        = string
  default     = "10.0.100.1/24"
}

variable "prefect_address" {
  description = "The address of the Prefect server instance"
  type        = string
}

variable "incus" {
  description = "The Incus remote configuration"
  type = object({
    host  = string
    token = string
  })
}

variable "github" {
  description = "GitHub credentials for accessing private container registry"
  sensitive   = true
  type = object({
    username = string
    password = string
    email    = string
  })
}

variable "tailscale" {
  description = "Tailscale configuration"
  sensitive   = true
  type = object({
    tailnet = string
    domain  = string
    suffix  = string
    oauth = object({
      client_id     = string
      client_secret = string
    })
  })
}

variable "infisical" {
  description = "Infisical configuration"
  sensitive   = true
  type = object({
    address       = string
    client_id     = string
    client_secret = string
  })
}
