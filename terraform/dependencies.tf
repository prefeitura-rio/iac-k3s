terraform {
  required_version = "~> 1.12"

  backend "gcs" {
    bucket = "iplanrio-terraform-state"
    prefix = "k3s"
  }

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}
