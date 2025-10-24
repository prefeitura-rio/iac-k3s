terraform {
  required_version = ">= 1.12.0"

  backend "gcs" {
    bucket = "iplanrio-dia-terraform"
    prefix = "tf-k3s"
  }

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.38.0 "
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.1.3"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.7.2"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.4"
    }
    incus = {
      source  = "lxc/incus"
      version = ">= 1.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.3"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.12.1"
    }
  }
}
