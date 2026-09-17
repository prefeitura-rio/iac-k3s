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
  default = {
    cluster_name           = "k3s"
    control_plane_hostname = "srv001070"
    nodes = {
      control_plane = { ipv4_address = "10.2.230.10" }
      workers = [
        { name = "srv001071", ipv4_address = "10.2.230.11" },
        { name = "srv001072", ipv4_address = "10.2.230.12" },
        { name = "srv001073", ipv4_address = "10.2.230.13" },
      ]
    }
  }
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

variable "jwks_mirror_public_hostname" {
  description = "Intranet DNS hostname for the JWKS mirror Traefik Ingress (not internet-facing)"
  type        = string
}
