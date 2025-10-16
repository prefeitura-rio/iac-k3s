terraform {
  required_version = ">= 1.12.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.38.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.2"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.1.3"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.4"
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
