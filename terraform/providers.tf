provider "incus" {
  generate_client_certificates = true
  accept_remote_certificate    = true

  remote {
    name    = "k3s"
    address = "https://${var.cluster_name}:8443"
    token   = local.incus_token
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

