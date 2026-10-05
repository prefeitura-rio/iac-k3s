locals {
  suptm_environments = {
    staging = {
      namespace             = "suptm-staging"
      branch                = "staging"
      backend_release_name  = "app-suptm-backend-staging"
      frontend_release_name = "app-suptm-frontend-staging"
      hostname              = "suptm.staging.squirrel-regulus.ts.net"
    }
    prod = {
      namespace             = "suptm"
      branch                = "master"
      backend_release_name  = "app-suptm-backend"
      frontend_release_name = "app-suptm-frontend"
      hostname              = "suptm.squirrel-regulus.ts.net"
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

resource "kubectl_manifest" "suptm_frontend_httproute" {
  for_each   = local.suptm_environments
  depends_on = [kubectl_manifest.intranet_gateway, kubectl_manifest.suptm_frontend_kustomization]

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = each.value.frontend_release_name
      namespace = each.value.namespace
    }
    spec = {
      parentRefs = [{
        name        = "intranet"
        namespace   = helm_release.nginx_gateway_fabric.namespace
        sectionName = "https"
      }]
      hostnames = [each.value.hostname]
      rules = [{
        matches = [{
          path = { type = "PathPrefix", value = "/" }
        }]
        backendRefs = [{
          name = each.value.frontend_release_name
          port = 80
        }]
      }]
    }
  })
}
