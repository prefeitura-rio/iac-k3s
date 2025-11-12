resource "helm_release" "kube_cleanup_operator" {
  name             = "kube-cleanup-operator"
  repository       = "http://charts.lwolf.org"
  chart            = "kube-cleanup-operator"
  namespace        = "kube-system"
  create_namespace = false

  set = [
    {
      name  = "resources.requests.memory"
      value = "256Mi"
    },
    {
      name  = "resources.limits.memory"
      value = "256Mi"
  }]

  set_list = [{
    name = "args"
    value = [
      "--legacy-mode=false",
      "--delete-successful-after=1h",
      "--delete-failed-after=24h",
      "--delete-evicted-pods-after=5m",
      "--delete-orphaned-pods-after=30m",
      "--delete-pending-pods-after=2h"
    ]
  }]
}

resource "kubernetes_cluster_role" "kube_cleanup_operator" {
  depends_on = [helm_release.kube_cleanup_operator]
  metadata {
    name = "kube-cleanup-operator"
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["get", "list", "watch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch", "delete"]
  }
}

resource "kubernetes_cluster_role_binding" "kube_cleanup_operator" {
  metadata {
    name = "kube-cleanup-operator"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.kube_cleanup_operator.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = helm_release.kube_cleanup_operator.name
    namespace = helm_release.kube_cleanup_operator.namespace
  }
}
