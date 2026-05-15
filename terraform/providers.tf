provider "incus" {
  generate_client_certificates = true
  accept_remote_certificate    = true

  remote {
    name    = "k3s"
    address = "https://${var.cluster_name}:8443"
    token   = var.incus_token
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes = {
    config_path = var.kubeconfig_path
  }
}

provider "kubectl" {
  config_path      = var.kubeconfig_path
  load_config_file = var.kubeconfig_path != ""
}

