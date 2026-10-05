locals {
  suptm_environments = {
    staging = {
      namespace             = "suptm-staging"
      branch                = "staging"
      backend_release_name  = "app-suptm-backend-staging"
      frontend_release_name = "app-suptm-frontend-staging"
      intranet_hostname     = "suptm.staging.iplan.dados.rio"
    }
    prod = {
      namespace             = "suptm"
      branch                = "master"
      backend_release_name  = "app-suptm-backend"
      frontend_release_name = "app-suptm-frontend"
      intranet_hostname     = "suptm.iplan.dados.rio"
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
      name      = "${each.value.frontend_release_name}-intranet"
      namespace = each.value.namespace
    }
    spec = {
      parentRefs = [{
        name        = "intranet"
        namespace   = helm_release.nginx_gateway_fabric.namespace
        sectionName = "https"
      }]
      hostnames = [each.value.intranet_hostname]
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

resource "kubectl_manifest" "suptm_frontend_tailscale_ingress" {
  for_each   = local.suptm_environments
  depends_on = [helm_release.tailscale_operator, kubectl_manifest.suptm_frontend_kustomization]

  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "${each.key == "staging" ? "suptm-staging" : "suptm"}-${var.tailscale.suffix}"
      namespace = each.value.namespace
      annotations = {
        "tailscale.com/tags"     = "tag:k8s-${var.tailscale.suffix}"
        "tailscale.com/hostname" = "${each.key == "staging" ? "suptm-staging" : "suptm"}-${var.tailscale.suffix}"
      }
    }

    spec = {
      ingressClassName = "tailscale"
      defaultBackend = {
        service = {
          name = each.value.frontend_release_name
          port = {
            number = 80
          }
        }
      }
      tls = [{
        hosts = [
          "${each.key == "staging" ? "suptm-staging" : "suptm"}-${var.tailscale.suffix}.${var.tailscale.domain}"
        ]
      }]
    }
  })
}

resource "kubectl_manifest" "suptm_backend_infisical_secret" {
  for_each   = local.suptm_environments
  depends_on = [helm_release.infisical_secrets_operator, kubernetes_namespace_v1.suptm]

  yaml_body = yamlencode({
    apiVersion = "secrets.infisical.com/v1alpha1"
    kind       = "InfisicalSecret"
    metadata = {
      name      = "app-suptm-backend-secrets"
      namespace = each.value.namespace
    }
    spec = {
      authentication = {
        universalAuth = {
          secretsScope = {
            projectSlug = "app-suptm-backend-sn-k7"
            envSlug     = each.key
            secretsPath = "/"
            recursive   = true
          }
          credentialsRef = {
            secretName      = local.infisical_auth_secret_name
            secretNamespace = helm_release.infisical_secrets_operator.namespace
          }
        }
      }
      managedKubeSecretReferences = [{
        secretName      = "app-suptm-backend-secrets"
        secretNamespace = each.value.namespace
        creationPolicy  = "Orphan"
        template        = { includeAllSecrets = true }
      }]
    }
  })
}

resource "kubectl_manifest" "suptm_frontend_infisical_secret" {
  for_each   = local.suptm_environments
  depends_on = [helm_release.infisical_secrets_operator, kubernetes_namespace_v1.suptm]

  yaml_body = yamlencode({
    apiVersion = "secrets.infisical.com/v1alpha1"
    kind       = "InfisicalSecret"
    metadata = {
      name      = "app-suptm-frontend-secrets"
      namespace = each.value.namespace
    }
    spec = {
      authentication = {
        universalAuth = {
          secretsScope = {
            projectSlug = "app-suptm-frontend-mkmv"
            envSlug     = each.key
            secretsPath = "/"
            recursive   = true
          }
          credentialsRef = {
            secretName      = local.infisical_auth_secret_name
            secretNamespace = helm_release.infisical_secrets_operator.namespace
          }
        }
      }
      managedKubeSecretReferences = [{
        secretName      = "app-suptm-frontend-secrets"
        secretNamespace = each.value.namespace
        creationPolicy  = "Orphan"
        template        = { includeAllSecrets = true }
      }]
    }
  })
}
