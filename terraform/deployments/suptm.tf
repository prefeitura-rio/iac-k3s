locals {
  suptm_environments = {
    staging = {
      namespace             = "suptm-staging"
      branch                = "staging"
      backend_release_name  = "app-suptm-backend-staging"
      frontend_release_name = "app-suptm-frontend-staging"
    }
    prod = {
      namespace             = "suptm"
      branch                = "master"
      backend_release_name  = "app-suptm-backend"
      frontend_release_name = "app-suptm-frontend"
    }
  }
}

resource "kubernetes_namespace_v1" "suptm" {
  for_each = local.suptm_environments

  metadata {
    name = each.value.namespace
  }
}

resource "kubectl_manifest" "suptm_gitrepo" {
  for_each   = local.suptm_environments
  depends_on = [kubernetes_namespace_v1.suptm, helm_release.flux_instance, kubernetes_secret_v1.flux_git_auth]

  yaml_body = yamlencode({
    apiVersion = "source.toolkit.fluxcd.io/v1"
    kind       = "GitRepository"
    metadata = {
      name      = each.value.namespace
      namespace = each.value.namespace
    }
    spec = {
      interval = "1m"
      url      = "https://github.com/prefeitura-rio/app-suptm.git"
      ref = {
        branch = each.value.branch
      }
      secretRef = {
        name = "flux-git-auth"
      }
    }
  })
}

resource "kubectl_manifest" "suptm_backend_kustomization" {
  for_each   = local.suptm_environments
  depends_on = [kubernetes_namespace_v1.suptm, kubectl_manifest.suptm_gitrepo]

  yaml_body = yamlencode({
    apiVersion = "kustomize.toolkit.fluxcd.io/v1"
    kind       = "Kustomization"
    metadata = {
      name      = each.value.backend_release_name
      namespace = each.value.namespace
    }
    spec = {
      interval = "1m"
      prune    = true
      sourceRef = {
        kind = "GitRepository"
        name = each.value.namespace
      }
      path = "./backend/k8s/${each.key}"
    }
  })
}

resource "kubectl_manifest" "suptm_frontend_kustomization" {
  for_each   = local.suptm_environments
  depends_on = [kubernetes_namespace_v1.suptm, kubectl_manifest.suptm_gitrepo]

  yaml_body = yamlencode({
    apiVersion = "kustomize.toolkit.fluxcd.io/v1"
    kind       = "Kustomization"
    metadata = {
      name      = each.value.frontend_release_name
      namespace = each.value.namespace
    }
    spec = {
      interval = "1m"
      prune    = true
      sourceRef = {
        kind = "GitRepository"
        name = each.value.namespace
      }
      path = "./frontend/k8s/${each.key}"
    }
  })
}
