resource "kubernetes_namespace" "default" {
  metadata {
    name = "default"
  }
}

