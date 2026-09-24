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

variable "prefect_address" {
  description = "The address of the Prefect server instance"
  type        = string
}

variable "tailscale" {
  description = "Tailscale configuration"
  type = object({
    tailnet = string
    domain  = string
    suffix  = string
    users   = optional(set(string), [])
    oauth = object({
      client_id     = string
      client_secret = string
    })
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

variable "infisical" {
  description = "Infisical configuration"
  sensitive   = true
  type = object({
    address       = string
    client_id     = string
    client_secret = string
  })
}

variable "cloudsql_proxy" {
  description = "Cloud SQL Proxy service-account credentials"
  sensitive   = true
  type = object({
    sa_key = string
  })
}

variable "airbyte" {
  description = "Airbyte external storage and database credentials"
  sensitive   = true
  type = object({
    gcs_sa_key = string
    database = object({
      username = string
      password = string
    })
  })
}

variable "datametrica" {
  description = "Datametrica MSSQL server configuration"
  type = object({
    host = string
    port = optional(number, 1433)
  })
}

variable "proxy_allowed_cidrs" {
  description = "CIDR ranges allowed to use the Tailscale proxy"
  type        = list(string)
  default     = ["100.64.0.0/10"]
}

variable "jwks_mirror_public_hostname" {
  description = "Intranet-only DNS hostname for the JWKS mirror's non-tailnet Ingress -- NOT internet-facing (must have an internal A/CNAME record pointing at the K3s cluster's intranet ingress IP; not managed by this repo, coordinate with whoever owns the DNS zone)"
  type        = string
}
