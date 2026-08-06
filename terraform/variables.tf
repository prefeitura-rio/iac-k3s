variable "k3s" {
  description = "K3s cluster configuration"
  type = object({
    cluster_name           = optional(string, "k3s")
    control_plane_hostname = optional(string, "srv001070")
    nodes = object({
      control_plane = object({ ipv4_address = string })
      workers       = list(object({ name = string, ipv4_address = string }))
    })
  })
}

variable "kubeconfig_path" {
  description = "Path to the decrypted kubeconfig file (injected at runtime by sops exec-file)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "prefect_address" {
  description = "The address of the Prefect server instance"
  type        = string
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
    domain  = string
    suffix  = string
    tailnet = string
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

variable "datametrica" {
  description = "Datametrica MSSQL server configuration"
  type = object({
    host = string
    port = optional(number, 1433)
  })
}

variable "cloudsql_proxies" {
  description = "CloudSQL proxy configurations"
  type = map(object({
    instance_name   = string
    instance_region = string
    project_id      = string
    sa_key          = string
    port            = string
    private         = optional(bool, false)
  }))
}

variable "jwks_mirror_public_hostname" {
  description = "Intranet DNS hostname for the JWKS mirror Traefik Ingress (not internet-facing)"
  type        = string
}
