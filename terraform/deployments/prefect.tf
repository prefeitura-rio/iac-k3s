resource "kubernetes_namespace_v1" "prefect" {
  metadata {
    name = "prefect"
  }
}

resource "kubernetes_secret_v1" "gh_registry_config" {
  metadata {
    name      = "gh-registry-config"
    namespace = kubernetes_namespace_v1.prefect.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      "auths" = {
        "ghcr.io" = {
          "username" = var.github.username
          "password" = var.github.password
          "email"    = var.github.email
          "auth"     = base64encode("${var.github.username}:${var.github.password}")
        }
      }
    })
  }
}

resource "helm_release" "prefect_worker" {
  depends_on = [kubernetes_namespace_v1.prefect]
  name       = "prefect-worker"
  repository = "https://prefecthq.github.io/prefect-helm"
  chart      = "prefect-worker"
  version    = "2025.12.31221620"
  namespace  = kubernetes_namespace_v1.prefect.metadata[0].name
  values = [templatefile("${path.module}/yamls/prefect-worker-values.yaml", {
    prefect_server_url       = "${var.prefect_address}/api"
    prefect_work_pool        = "k3s-pool"
    image_pull_secret_name   = kubernetes_secret_v1.gh_registry_config.metadata[0].name
    envs_secret_name         = "prefect-jobs-secrets-staging"
    prefect_worker_namespace = kubernetes_namespace_v1.prefect.metadata[0].name
  })]
}

resource "kubectl_manifest" "prefect_worker_cluster_role" {
  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRole"
    metadata = {
      name = "prefect-worker-crd-ns-list"
    }
    rules = [
      {
        apiGroups = ["apiextensions.k8s.io"]
        resources = ["customresourcedefinitions"]
        verbs     = ["list", "get", "watch"]
      },
      {
        apiGroups = [""]
        resources = ["namespaces"]
        verbs     = ["list", "get", "watch"]
      },
      {
        apiGroups = ["batch"]
        resources = ["jobs"]
        verbs     = ["create", "get", "list", "watch", "delete"]
      }
    ]
  })
}

resource "kubectl_manifest" "prefect_worker_cluster_role_binding" {
  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"
    metadata = {
      name = "prefect-worker-crd-ns-list"
    }
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "ClusterRole"
      name     = "prefect-worker-crd-ns-list"
    }
    subjects = [
      {
        kind      = "ServiceAccount"
        name      = "prefect-worker"
        namespace = helm_release.prefect_worker.namespace
      }
    ]
  })
}

resource "kubectl_manifest" "prefect_egress_service" {
  depends_on = [kubectl_manifest.tailscale_egress_proxyclass]
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "worker-k3s"
      namespace = "prefect"
      annotations = {
        "tailscale.com/proxy-class"  = "egress"
        "tailscale.com/tags"         = "tag:k8s-${var.tailscale.suffix},tag:prefect-worker"
        "tailscale.com/tailnet-fqdn" = "prefect.${var.tailscale.domain}"
      }
    }
    spec = {
      type         = "ExternalName"
      externalName = "placeholder"
    }
  })
}

locals {
  prefect_infisical_secrets = {
    prod = {
      secret_name  = "prefect-jobs-secrets"
      project_slug = "prefect-jobs-v-l3-v"
      env_slug     = "prod"
    }
    staging = {
      secret_name  = "prefect-jobs-secrets-staging"
      project_slug = "prefect-jobs-v-l3-v"
      env_slug     = "staging"
    }
  }
}

resource "kubectl_manifest" "infisical_secret_prefect_jobs" {
  for_each   = local.prefect_infisical_secrets
  depends_on = [helm_release.infisical_secrets_operator, kubernetes_namespace_v1.prefect]

  yaml_body = yamlencode({
    apiVersion = "secrets.infisical.com/v1alpha1"
    kind       = "InfisicalSecret"
    metadata = {
      name      = each.value.secret_name
      namespace = kubernetes_namespace_v1.prefect.metadata[0].name
    }
    spec = {
      authentication = {
        universalAuth = {
          secretsScope = {
            projectSlug = each.value.project_slug
            envSlug     = each.value.env_slug
            secretsPath = "/"
            recursive   = true
          }
          credentialsRef = {
            secretName      = local.infisical_auth_secret_name
            secretNamespace = helm_release.infisical_secrets_operator.namespace
          }
        }
      }
      managedKubeSecretReferences = [
        {
          secretName      = each.value.secret_name
          secretNamespace = kubernetes_namespace_v1.prefect.metadata[0].name
          creationPolicy  = "Orphan"
          template = {
            includeAllSecrets = true
          }
        }
      ]
    }
  })
}
