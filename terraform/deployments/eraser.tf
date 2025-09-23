resource "kubernetes_namespace" "eraser_system" {
  metadata {
    name = "eraser-system"
    labels = {
      "control-plane" = "controller-manager"
    }
  }
}

resource "kubectl_manifest" "imagejob_crd" {
  yaml_body = yamlencode({
    apiVersion = "apiextensions.k8s.io/v1"
    kind       = "CustomResourceDefinition"
    metadata = {
      name = "imagejobs.eraser.sh"
      annotations = {
        "controller-gen.kubebuilder.io/version" = "v0.9.0"
      }
    }
    spec = {
      group = "eraser.sh"
      names = {
        kind     = "ImageJob"
        listKind = "ImageJobList"
        plural   = "imagejobs"
        singular = "imagejob"
      }
      scope = "Cluster"
      versions = [
        {
          name = "v1"
          schema = {
            openAPIV3Schema = {
              description = "ImageJob is the Schema for the imagejobs API."
              type        = "object"
              properties = {
                apiVersion = {
                  description = "APIVersion defines the versioned schema of this representation of an object. Servers should convert recognized schemas to the latest internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources"
                  type        = "string"
                }
                kind = {
                  description = "Kind is a string value representing the REST resource this object represents. Servers may infer this from the endpoint the client submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds"
                  type        = "string"
                }
                metadata = {
                  type = "object"
                }
                status = {
                  description = "ImageJobStatus defines the observed state of ImageJob."
                  type        = "object"
                  required    = ["desired", "failed", "phase", "skipped", "succeeded"]
                  properties = {
                    deleteAfter = {
                      description = "Time to delay deletion until"
                      format      = "date-time"
                      type        = "string"
                    }
                    desired = {
                      description = "desired number of pods"
                      type        = "integer"
                    }
                    failed = {
                      description = "number of pods that failed"
                      type        = "integer"
                    }
                    phase = {
                      description = "job running, successfully completed, or failed"
                      type        = "string"
                    }
                    skipped = {
                      description = "number of nodes that were skipped e.g. because they are not a linux node"
                      type        = "integer"
                    }
                    succeeded = {
                      description = "number of pods that completed successfully"
                      type        = "integer"
                    }
                  }
                }
              }
            }
          }
          served  = true
          storage = true
          subresources = {
            status = {}
          }
        },
        {
          name               = "v1alpha1"
          deprecated         = true
          deprecationWarning = "v1alpha1 of the eraser API has been deprecated. Please migrate to v1."
          schema = {
            openAPIV3Schema = {
              description = "ImageJob is the Schema for the imagejobs API."
              type        = "object"
              properties = {
                apiVersion = {
                  description = "APIVersion defines the versioned schema of this representation of an object. Servers should convert recognized schemas to the latest internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources"
                  type        = "string"
                }
                kind = {
                  description = "Kind is a string value representing the REST resource this object represents. Servers may infer this from the endpoint the client submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds"
                  type        = "string"
                }
                metadata = {
                  type = "object"
                }
                status = {
                  description = "ImageJobStatus defines the observed state of ImageJob."
                  type        = "object"
                  required    = ["desired", "failed", "phase", "skipped", "succeeded"]
                  properties = {
                    deleteAfter = {
                      description = "Time to delay deletion until"
                      format      = "date-time"
                      type        = "string"
                    }
                    desired = {
                      description = "desired number of pods"
                      type        = "integer"
                    }
                    failed = {
                      description = "number of pods that failed"
                      type        = "integer"
                    }
                    phase = {
                      description = "job running, successfully completed, or failed"
                      type        = "string"
                    }
                    skipped = {
                      description = "number of nodes that were skipped e.g. because they are not a linux node"
                      type        = "integer"
                    }
                    succeeded = {
                      description = "number of pods that completed successfully"
                      type        = "integer"
                    }
                  }
                }
              }
            }
          }
          served  = true
          storage = false
          subresources = {
            status = {}
          }
        }
      ]
    }
  })
}

resource "kubectl_manifest" "imagelist_crd" {
  yaml_body = yamlencode({
    apiVersion = "apiextensions.k8s.io/v1"
    kind       = "CustomResourceDefinition"
    metadata = {
      name = "imagelists.eraser.sh"
      annotations = {
        "controller-gen.kubebuilder.io/version" = "v0.9.0"
      }
    }
    spec = {
      group = "eraser.sh"
      names = {
        kind     = "ImageList"
        listKind = "ImageListList"
        plural   = "imagelists"
        singular = "imagelist"
      }
      scope = "Cluster"
      versions = [
        {
          name = "v1"
          schema = {
            openAPIV3Schema = {
              description = "ImageList is the Schema for the imagelists API."
              type        = "object"
              properties = {
                apiVersion = {
                  description = "APIVersion defines the versioned schema of this representation of an object. Servers should convert recognized schemas to the latest internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources"
                  type        = "string"
                }
                kind = {
                  description = "Kind is a string value representing the REST resource this object represents. Servers may infer this from the endpoint the client submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds"
                  type        = "string"
                }
                metadata = {
                  type = "object"
                }
                spec = {
                  description = "ImageListSpec defines the desired state of ImageList."
                  type        = "object"
                  required    = ["images"]
                  properties = {
                    images = {
                      description = "The list of non-compliant images to delete if non-running."
                      type        = "array"
                      items = {
                        type = "string"
                      }
                    }
                  }
                }
                status = {
                  description = "ImageListStatus defines the observed state of ImageList."
                  type        = "object"
                  required    = ["failed", "skipped", "success", "timestamp"]
                  properties = {
                    failed = {
                      description = "Number of nodes that failed to run the job"
                      format      = "int64"
                      type        = "integer"
                    }
                    skipped = {
                      description = "Number of nodes that were skipped due to a skip selector"
                      format      = "int64"
                      type        = "integer"
                    }
                    success = {
                      description = "Number of nodes that successfully ran the job"
                      format      = "int64"
                      type        = "integer"
                    }
                    timestamp = {
                      description = "Information when the job was completed."
                      format      = "date-time"
                      type        = "string"
                    }
                  }
                }
              }
            }
          }
          served  = true
          storage = true
          subresources = {
            status = {}
          }
        },
        {
          name               = "v1alpha1"
          deprecated         = true
          deprecationWarning = "v1alpha1 of the eraser API has been deprecated. Please migrate to v1."
          schema = {
            openAPIV3Schema = {
              description = "ImageList is the Schema for the imagelists API."
              type        = "object"
              properties = {
                apiVersion = {
                  description = "APIVersion defines the versioned schema of this representation of an object. Servers should convert recognized schemas to the latest internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources"
                  type        = "string"
                }
                kind = {
                  description = "Kind is a string value representing the REST resource this object represents. Servers may infer this from the endpoint the client submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds"
                  type        = "string"
                }
                metadata = {
                  type = "object"
                }
                spec = {
                  description = "ImageListSpec defines the desired state of ImageList."
                  type        = "object"
                  required    = ["images"]
                  properties = {
                    images = {
                      description = "The list of non-compliant images to delete if non-running."
                      type        = "array"
                      items = {
                        type = "string"
                      }
                    }
                  }
                }
                status = {
                  description = "ImageListStatus defines the observed state of ImageList."
                  type        = "object"
                  required    = ["failed", "skipped", "success", "timestamp"]
                  properties = {
                    failed = {
                      description = "Number of nodes that failed to run the job"
                      format      = "int64"
                      type        = "integer"
                    }
                    skipped = {
                      description = "Number of nodes that were skipped due to a skip selector"
                      format      = "int64"
                      type        = "integer"
                    }
                    success = {
                      description = "Number of nodes that successfully ran the job"
                      format      = "int64"
                      type        = "integer"
                    }
                    timestamp = {
                      description = "Information when the job was completed."
                      format      = "date-time"
                      type        = "string"
                    }
                  }
                }
              }
            }
          }
          served  = true
          storage = false
          subresources = {
            status = {}
          }
        }
      ]
    }
  })
}

resource "kubernetes_service_account" "eraser_controller_manager" {
  metadata {
    name      = "eraser-controller-manager"
    namespace = kubernetes_namespace.eraser_system.metadata[0].name
  }
}

resource "kubernetes_service_account" "eraser_imagejob_pods" {
  metadata {
    name      = "eraser-imagejob-pods"
    namespace = kubernetes_namespace.eraser_system.metadata[0].name
  }
}

resource "kubernetes_cluster_role" "eraser_imagejob_pods_cluster_role" {
  metadata {
    name = "eraser-imagejob-pods-cluster-role"
  }

  depends_on = [
    kubectl_manifest.imagejob_crd,
    kubectl_manifest.imagelist_crd
  ]
}

resource "kubernetes_cluster_role" "eraser_manager_role" {
  metadata {
    name = "eraser-manager-role"
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["create", "delete", "get", "list", "update", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["podtemplates"]
    verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
  }

  rule {
    api_groups = ["eraser.sh"]
    resources  = ["imagejobs"]
    verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
  }

  rule {
    api_groups = ["eraser.sh"]
    resources  = ["imagejobs/status"]
    verbs      = ["get", "patch", "update"]
  }

  rule {
    api_groups = ["eraser.sh"]
    resources  = ["imagelists"]
    verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
  }

  rule {
    api_groups = ["eraser.sh"]
    resources  = ["imagelists/status"]
    verbs      = ["get", "patch", "update"]
  }

  depends_on = [
    kubectl_manifest.imagejob_crd,
    kubectl_manifest.imagelist_crd
  ]
}

resource "kubernetes_config_map" "eraser_manager_config" {
  metadata {
    name      = "eraser-manager-config"
    namespace = kubernetes_namespace.eraser_system.metadata[0].name
  }

  data = {
    "controller_manager_config.yaml" = <<-EOT
      apiVersion: eraser.sh/v1alpha3
      kind: EraserConfig
      manager:
        runtime:
          name: containerd
          address: unix:///run/containerd/containerd.sock
        otlpEndpoint: ""
        logLevel: info
        scheduling:
          repeatInterval: 24h
          beginImmediately: true
        profile:
          enabled: false
          port: 6060
        imageJob:
          successRatio: 1.0
          cleanup:
            delayOnSuccess: 0s
            delayOnFailure: 24h
        pullSecrets: [] # image pull secrets for collector/scanner/eraser
        priorityClassName: "" # priority class name for collector/scanner/eraser
        nodeFilter:
          type: exclude # must be either exclude|include
          selectors:
            - eraser.sh/cleanup.filter
            - kubernetes.io/os=windows
      components:
        collector:
          enabled: true
          image:
            repo: ghcr.io/eraser-dev/collector
            tag: v1.4.0-beta.0
          request:
            mem: 25Mi
            cpu: 7m
          limit:
            mem: 500Mi
            # https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#how-pods-with-resource-limits-are-run
            cpu: 0
        scanner:
          enabled: true
          image:
            repo: ghcr.io/eraser-dev/eraser-trivy-scanner # supply custom image for custom scanner
            tag: v1.4.0-beta.0
          request:
            mem: 500Mi
            cpu: 1000m
          limit:
            mem: 2Gi
            # https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#how-pods-with-resource-limits-are-run
            cpu: 0
          # The config needs to be passed through to the scanner as yaml, as a
          # single string. Because we allow custom scanner images, the scanner is
          # responsible for defining a schema, parsing, and validating.
          config: |
            # this is the schema for the provided 'trivy-scanner'. custom scanners
            # will define their own configuration.
            cacheDir: /var/lib/trivy
            dbRepo: ghcr.io/aquasecurity/trivy-db
            deleteFailedImages: true
            deleteEOLImages: true
            vulnerabilities:
              ignoreUnfixed: true
              types:
                - os
                - library
              securityChecks:
                - vuln
              severities:
                - CRITICAL
                - HIGH
                - MEDIUM
                - LOW
              ignoredStatuses:
            timeout:
              total: 23h
              perImage: 1h
        remover:
          image:
            repo: ghcr.io/eraser-dev/remover
            tag: v1.4.0-beta.0
          request:
            mem: 25Mi
            # https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#how-pods-with-resource-limits-are-run
            cpu: 0
          limit:
            mem: 30Mi
            cpu: 0
    EOT
  }
}

resource "kubernetes_cluster_role_binding" "eraser_imagejob_pods_cluster_rolebinding" {
  metadata {
    name = "eraser-imagejob-pods-cluster-rolebinding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.eraser_imagejob_pods_cluster_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.eraser_imagejob_pods.metadata[0].name
    namespace = kubernetes_namespace.eraser_system.metadata[0].name
  }
}

resource "kubernetes_cluster_role_binding" "eraser_manager_rolebinding" {
  metadata {
    name = "eraser-manager-rolebinding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.eraser_manager_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.eraser_controller_manager.metadata[0].name
    namespace = kubernetes_namespace.eraser_system.metadata[0].name
  }
}

resource "kubernetes_deployment" "eraser_controller_manager" {
  metadata {
    name      = "eraser-controller-manager"
    namespace = kubernetes_namespace.eraser_system.metadata[0].name
    labels = {
      "control-plane" = "controller-manager"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "control-plane" = "controller-manager"
      }
    }

    template {
      metadata {
        labels = {
          "control-plane" = "controller-manager"
        }
      }

      spec {
        service_account_name             = kubernetes_service_account.eraser_controller_manager.metadata[0].name
        termination_grace_period_seconds = 10

        node_selector = {
          "kubernetes.io/os" = "linux"
        }

        container {
          name    = "manager"
          image   = "ghcr.io/eraser-dev/eraser-manager:v1.4.0-beta.0"
          command = ["/manager"]
          args    = ["--config=/config/controller_manager_config.yaml"]

          env {
            name = "POD_NAMESPACE"
            value_from {
              field_ref {
                api_version = "v1"
                field_path  = "metadata.namespace"
              }
            }
          }

          env {
            name  = "OTEL_SERVICE_NAME"
            value = "eraser-manager"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "20Mi"
            }
            limits = {
              memory = "30Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
            read_only_root_filesystem = true
            run_as_group              = 65532
            run_as_non_root           = true
            run_as_user               = 65532
            seccomp_profile {
              type = "RuntimeDefault"
            }
          }

          volume_mount {
            mount_path = "/config"
            name       = "manager-config"
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 8081
            }
            initial_delay_seconds = 15
            period_seconds        = 20
          }

          readiness_probe {
            http_get {
              path = "/readyz"
              port = 8081
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }

        volume {
          name = "manager-config"
          config_map {
            name = kubernetes_config_map.eraser_manager_config.metadata[0].name
          }
        }
      }
    }
  }
}

