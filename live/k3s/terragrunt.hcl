locals {
  secrets   = jsondecode(sops_decrypt_file("${get_terragrunt_dir()}/terraform.tfvars.sops.json"))
  kube_host = get_env("KUBE_HOST")
}

terraform {
  source            = "../../terraform"
  exclude_from_copy = [".terraform", "*.plan", "*.tfplan"]
}

remote_state {
  backend = "gcs"

  config = {
    bucket = "iplanrio-terraform-state"
    prefix = "k3s"
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

inputs = local.secrets

generate "providers" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
provider "kubernetes" {
  host = "${local.kube_host}"
}

provider "helm" {
  kubernetes = {
    host = "${local.kube_host}"
  }
}

provider "kubectl" {
  host             = "${local.kube_host}"
  load_config_file = false
}
EOF
}
