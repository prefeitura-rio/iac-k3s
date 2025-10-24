provider "incus" {
  generate_client_certificates = true
  accept_remote_certificate    = true

  remote {
    name    = "k3s"
    address = var.incus.host
    token   = var.incus.token
  }
}

provider "kubernetes" {
  config_path = fileexists(local.kubeconfig_path) ? local.kubeconfig_path : null
}

provider "helm" {
  kubernetes = {
    config_path = fileexists(local.kubeconfig_path) ? local.kubeconfig_path : null
  }
}

provider "kubectl" {
  config_path = fileexists(local.kubeconfig_path) ? local.kubeconfig_path : null
}

