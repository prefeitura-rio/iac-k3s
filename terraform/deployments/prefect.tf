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
  values = [yamlencode({
    worker = {
      autoscaling = {
        enabled                           = true
        minReplicas                       = 1
        maxReplicas                       = 5
        targetCPUUtilizationPercentage    = 80
        targetMemoryUtilizationPercentage = 80
      }
      config = {
        workPool        = "k3s-pool"
        limit           = 6
        prefetchSeconds = 30
        baseJobTemplate = {
          configuration = jsonencode({
            variables = {
              type = "object"
              properties = {
                env        = { type = "object", title = "Environment Variables", additionalProperties = { anyOf = [{ type = "string" }, { type = "null" }] } }
                secretName = { type = "string", title = "Secret Name", default = "prefect-jobs-secrets-staging" }
                name       = { anyOf = [{ type = "string" }, { type = "null" }], title = "Name", default = null }
                image      = { anyOf = [{ type = "string" }, { type = "null" }], title = "Image", default = null }
                labels     = { type = "object", title = "Labels", additionalProperties = { type = "string" } }
                command    = { anyOf = [{ type = "string" }, { type = "null" }], title = "Command", default = null }
                namespace  = { type = "string", title = "Namespace", default = kubernetes_namespace_v1.prefect.metadata[0].name }
                backoff_limit             = { type = "integer", title = "Backoff Limit", default = 0, minimum = 0 }
                stream_output             = { type = "boolean", title = "Stream Output", default = true }
                cluster_config            = { anyOf = [{ "$ref" = "#/definitions/KubernetesClusterConfig" }, { type = "null" }], default = null }
                finished_job_ttl          = { anyOf = [{ type = "integer" }, { type = "null" }], title = "Finished Job TTL", default = null }
                image_pull_policy         = { enum = ["IfNotPresent", "Always", "Never"], type = "string", default = "IfNotPresent" }
                service_account_name      = { anyOf = [{ type = "string" }, { type = "null" }], default = null }
                job_watch_timeout_seconds = { anyOf = [{ type = "integer" }, { type = "null" }], default = 1800 }
                pod_watch_timeout_seconds = { type = "integer", default = 300 }
              }
              definitions = {
                KubernetesClusterConfig = {
                  type     = "object"
                  required = ["config", "context_name"]
                  properties = {
                    config       = { type = "object", additionalProperties = true }
                    context_name = { type = "string" }
                  }
                }
              }
            }
            job_configuration = {
              env       = "{{ env }}"
              name      = "{{ name }}"
              labels    = "{{ labels }}"
              command   = "{{ command }}"
              namespace = "{{ namespace }}"
              job_manifest = {
                kind       = "Job"
                apiVersion = "batch/v1"
                metadata = {
                  labels       = "{{ labels }}"
                  namespace    = "{{ namespace }}"
                  generateName = "{{ name }}-"
                }
                spec = {
                  backoffLimit            = "{{ backoff_limit }}"
                  ttlSecondsAfterFinished = "{{ finished_job_ttl }}"
                  template = {
                    spec = {
                      completions        = 1
                      parallelism        = 1
                      restartPolicy      = "Never"
                      serviceAccountName = "{{ service_account_name }}"
                      containers = [{
                        name             = "prefect-job"
                        image            = "{{ image }}"
                        imagePullPolicy  = "{{ image_pull_policy }}"
                        args             = "{{ command }}"
                        env              = "{{ env }}"
                        envFrom          = [{ secretRef = { name = "{{ secretName }}" } }]
                        imagePullSecrets = [{ name = kubernetes_secret_v1.gh_registry_config.metadata[0].name }]
                      }]
                    }
                  }
                }
              }
              stream_output             = "{{ stream_output }}"
              cluster_config            = "{{ cluster_config }}"
              job_watch_timeout_seconds = "{{ job_watch_timeout_seconds }}"
              pod_watch_timeout_seconds = "{{ pod_watch_timeout_seconds }}"
            }
          })
        }
      }
      apiConfig                 = "selfHostedServer"
      selfHostedServerApiConfig = { apiUrl = "${var.prefect_address}/api" }
      replicaCount              = 1
      resources = {
        requests = { memory = "4Gi", cpu = "1000m" }
        limits   = { memory = "8Gi", cpu = "2000m" }
      }
      livenessProbe = { enabled = true }
    }
    role = {
      create = true
      extraPermissions = [
        { apiGroups = ["apiextensions.k8s.io"], resources = ["customresourcedefinitions"], verbs = ["get", "list", "watch"] },
        { apiGroups = [""], resources = ["namespaces"], verbs = ["get", "list", "watch"] },
      ]
    }
    rolebinding = { create = true }
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
