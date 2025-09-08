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

variable "incus_token" {
  description = "The Incus remote token for the k3s remote"
  type        = string
  sensitive   = true
}

variable "incus_host" {
  description = "The hostname or IP of the Incus server"
  type        = string
  default     = "k3s.squirrel-regulus.ts.net"
}
