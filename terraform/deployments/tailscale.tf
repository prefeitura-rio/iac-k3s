locals {
  nameserver_ip = trimspace(data.local_file.nameserver_ip.content)
}

resource "helm_release" "tailscale_operator" {
  name             = "tailscale-operator"
  repository       = "https://pkgs.tailscale.com/helmcharts"
  chart            = "tailscale-operator"
  version          = "1.88.2"
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

resource "kubectl_manifest" "tailscale_egress_proxyclass" {
  depends_on = [helm_release.tailscale_operator]
  yaml_body = yamlencode({
    apiVersion = "tailscale.com/v1alpha1"
    kind       = "ProxyClass"
    metadata = {
      name = "egress"
    }
    spec = {
      tailscale = {
        acceptRoutes = true
      }
    }
  })
}

resource "null_resource" "get_dns_ip" {
  depends_on = [kubectl_manifest.tailscale_operator_config]
  provisioner "local-exec" {
    command = <<-EOF
      kubectl wait --for=condition=NameserverReady dnsconfig/ts-dns --timeout=300s || true

      for i in {1..30}; do
        IP=$(kubectl get dnsconfig ts-dns -o jsonpath='{.status.nameserver.ip}' 2>/dev/null || echo "")

        if [ -n "$IP" ] && [ "$IP" != "" ]; then
          echo "$IP" > ./files/nameserver_ip.txt
          exit 0
        fi

        echo "Waiting for nameserver IP... attempt $i/30"
        sleep 10
      done

      echo "Failed to get nameserver IP from Tailscale DNSConfig"
      echo "Using fallback IP"
      echo "100.100.100.100" > ./files/nameserver_ip.txt
    EOF
  }
}

data "local_file" "nameserver_ip" {
  filename   = "./files/nameserver_ip.txt"
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
