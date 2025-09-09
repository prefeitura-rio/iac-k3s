locals {
  nameserver_ip = trimspace(data.local_file.nameserver_ip.content)
}

resource "helm_release" "tailscale_operator" {
  name             = "tailscale-operator"
  repository       = "https://pkgs.tailscale.com/helmcharts"
  chart            = "tailscale-operator"
  version          = "1.84.5"
  namespace        = "tailscale"
  create_namespace = true

  set = [
    {
      name  = "operatorConfig.hostname"
      value = "tailscale-operator-${var.tailscale.suffix}"
    },
    {
      name  = "oauth.clientId"
      value = var.tailscale.oauth.client_id
    },
    {
      name  = "oauth.clientSecret"
      value = var.tailscale.oauth.client_secret
    }
  ]
}

resource "kubectl_manifest" "tailscale_operator_config" {
  depends_on = [helm_release.tailscale_operator]
  yaml_body = yamlencode({
    apiVersion = "tailscale.com/v1alpha1"
    kind       = "DNSConfig"
    metadata = {
      name = "ts-dns"
    }
    spec = {
      nameserver = {
        image = {
          repo = "tailscale/k8s-nameserver"
          tag  = "unstable"
        }
      }
    }
  })
}

resource "null_resource" "get_dns_ip" {
  depends_on = [kubectl_manifest.tailscale_operator_config]
  provisioner "local-exec" {
    command = "kubectl get dnsconfig ts-dns -o jsonpath='{.status.nameserver.ip}' > /tmp/nameserver_ip"
  }
}

data "local_file" "nameserver_ip" {
  filename   = "/tmp/nameserver_ip"
  depends_on = [null_resource.get_dns_ip]
}

resource "kubectl_manifest" "coredns_config" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "coredns"
      namespace = "kube-system"
    }
    data = {
      Corefile  = <<-EOF
        .:53 {
            errors
            health
            ready
            kubernetes cluster.local in-addr.arpa ip6.arpa {
              pods insecure
              fallthrough in-addr.arpa ip6.arpa
            }
            hosts /etc/coredns/NodeHosts {
              ttl 60
              reload 15s
              fallthrough
            }
            prometheus :9153
            forward . /etc/resolv.conf
            cache 30
            loop
            reload
            loadbalance
            import /etc/coredns/custom/*.override
        }
        ts.net {
            errors
            cache 30
            forward . ${local.nameserver_ip}
        }
        import /etc/coredns/custom/*.server
      EOF
      NodeHosts = <<-EOF
        ${var.k3s_master.ipv4_address} ${var.k3s_master.name}
        %{for worker in var.k3s_workers~}
        ${worker.ipv4_address} ${worker.name}
        %{endfor~}
      EOF
    }
  })
}
