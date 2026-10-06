# Providers read KUBE_CONFIG_PATH at run time. A saved plan keeps
# var.kubeconfig_path, which points to a deleted temporary file at apply time.
provider "kubernetes" {}

provider "helm" {}

provider "kubectl" {
  load_config_file = var.kubeconfig_path != ""
}
