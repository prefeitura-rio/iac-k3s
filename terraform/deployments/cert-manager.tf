resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.18.2"
  namespace        = "cert-manager"
  create_namespace = true

  set = [
    {
      name  = "crds.enabled"
      value = "true"
    },
    {
      name  = "extraArgs[0]"
      value = "--enable-gateway-api"
    }
  ]
}

resource "kubectl_manifest" "selfsigned_issuer" {
  depends_on = [helm_release.cert_manager]
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "selfsigned-issuer"
    }
    spec = {
      selfSigned = {}
    }
  })
}

resource "kubectl_manifest" "internal_ca_root_certificate" {
  depends_on = [kubectl_manifest.selfsigned_issuer]
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "internal-ca-root"
      namespace = "cert-manager"
    }
    spec = {
      isCA       = true
      commonName = "k3s-internal-ca"
      secretName = "internal-ca-root-secret"
      duration   = "87600h"
      privateKey = {
        algorithm = "ECDSA"
        size      = 256
      }
      issuerRef = {
        name  = kubectl_manifest.selfsigned_issuer.name
        kind  = "ClusterIssuer"
        group = "cert-manager.io"
      }
    }
  })
}

resource "kubectl_manifest" "internal_ca_issuer" {
  depends_on = [kubectl_manifest.internal_ca_root_certificate]
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "internal-ca-issuer"
    }
    spec = {
      ca = {
        secretName = "internal-ca-root-secret"
      }
    }
  })
}
