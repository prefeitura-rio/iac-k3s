terraform {
  required_version = "~> 1.12"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
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
