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
    }
  ]
}

# Internal-only CA, not Let's Encrypt: everything issued off this cluster's
# public Ingress is intranet-reachable only (that's the whole point of the
# JWKS mirror -- serving apps that can't reach the internet). Let's Encrypt's
# HTTP-01/DNS-01 validation both require the ACME server itself (on the
# public internet) to be able to verify the domain, which is impossible for
# a host that's deliberately never internet-routable. A self-signed root CA
# + a CA-backed ClusterIssuer is the standard cert-manager bootstrap pattern
# for private PKI (see https://cert-manager.io/docs/configuration/selfsigned/
# #bootstrapping-ca-issuers) and needs no external validation at all.
#
# Consumers of certs issued by "internal-ca-issuer" must trust this root CA
# explicitly (it's not in any public trust store) -- the CA certificate
# itself is public (not sensitive, same reasoning as JWKS), retrieve it with:
#   kubectl get secret internal-ca-root-secret -n cert-manager -o jsonpath='{.data.ca\.crt}' | base64 -d
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
      duration   = "87600h" # 10 years -- root CA, renewed manually/rarely
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
