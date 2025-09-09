resource "kubernetes_namespace" "prefect_server" {
  metadata {
    name = "prefect"
  }
}

resource "kubernetes_secret" "gh_registry_config" {
  metadata {
    name      = "gh-registry-config"
    namespace = kubernetes_namespace.prefect.metadata[0].name
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
  depends_on = [kubernetes_namespace.prefect]
  name       = "prefect-worker"
  repository = "https://prefecthq.github.io/prefect-helm"
  chart      = "prefect-worker"
  version    = "2025.9.5190948"
  namespace  = kubernetes_namespace.prefect.metadata[0].name
  values = [templatefile("${path.module}/yamls/prefect-worker-values.yaml", {
    prefect_server_url       = var.prefect_address
    prefect_work_pool        = "k3s-pool"
    image_pull_secret_name   = kubernetes_secret.gh_registry_config.metadata[0].name
    envs_secret_name         = "prefect-jobs-secrets-staging"
    prefect_worker_namespace = kubernetes_namespace.prefect.metadata[0].name
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

resource "kubectl_mainfest" "prefect_server_egress" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name = "ts-prefect"
      annotations = {
        "tailscale.com/tailnet-fqdn" = var.prefect_address
      }
    }
    spec = {
      type         = "ExternalName"
      externalName = "unused"
    }
  })
}

resource "kubectl_manifest" "infisical_secret_prefect_jobs" {
  depends_on = [helm_release.infisical_secrets_operator, kubernetes_namespace.prefect]
  yaml_body = templatefile("${path.module}/yamls/infisical-secret.yaml", {
    secret_name           = "prefect-jobs-secrets"
    project_slug          = "prefect-jobs-v-l3-v"
    env_slug              = "prod"
    namespace             = kubernetes_namespace.prefect.metadata[0].name
    auth_secret_name      = local.infisical_auth_secret_name
    auth_secret_namespace = helm_release.infisical_secrets_operator.namespace
  })
}

resource "kubectl_manifest" "infisical_secret_prefect_jobs_staging" {
  depends_on = [helm_release.infisical_secrets_operator, kubernetes_namespace.prefect]
  yaml_body = templatefile("${path.module}/yamls/infisical-secret.yaml", {
    secret_name           = "prefect-jobs-secrets-staging"
    project_slug          = "prefect-jobs-v-l3-v"
    env_slug              = "staging"
    namespace             = kubernetes_namespace.prefect.metadata[0].name
    auth_secret_name      = local.infisical_auth_secret_name
    auth_secret_namespace = helm_release.infisical_secrets_operator.namespace
  })
}
