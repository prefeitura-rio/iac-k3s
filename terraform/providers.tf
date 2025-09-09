provider "incus" {
  generate_client_certificates = true
  accept_remote_certificate    = true

  remote {
    name    = "k3s"
    scheme  = "https"
    address = var.incus.host
    token   = var.incus.token
  }
}

