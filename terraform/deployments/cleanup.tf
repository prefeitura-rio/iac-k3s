resource "helm_release" "kube_cleanup_operator" {
  name             = "kube-cleanup-operator"
  repository       = "http://charts.lwolf.org"
  chart            = "kube-cleanup-operator"
  version          = "1.0.4"
  namespace        = "kube-system"
  create_namespace = false

  set_list = [
    {
      name = "args"
      value = [
        "--legacy-mode=false",
        "--delete-successful-after=1h",
        "--delete-failed-after=24h",
        "--delete-evicted-pods-after=5m",
        "--delete-orphaned-pods-after=30m",
        "--delete-pending-pods-after=2h"
      ]
    }
  ]
}
