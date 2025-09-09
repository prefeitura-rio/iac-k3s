provider "kubernetes" {
  config_path = fileexists(var.kubeconfig_path) ? var.kubeconfig_path : null
}

provider "helm" {
  kubernetes = {
    config_path = fileexists(var.kubeconfig_path) ? var.kubeconfig_path : null
  }
}

provider "kubectl" {
  config_path = fileexists(var.kubeconfig_path) ? var.kubeconfig_path : null
}

