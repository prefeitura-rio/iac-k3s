locals {
  kubeconfig_ready = data.local_file.kubeconfig.filename
}

resource "incus_network" "k3s_network" {
  name = var.cluster_name

  config = {
    "ipv4.address" = var.network_cidr
    "ipv4.nat"     = "true"
    "ipv6.address" = "none"
  }
}

resource "incus_profile" "k3s_profile" {
  name = "${var.cluster_name}-profile"

  config = {
    "limits.cpu"                                = var.cpu_limit
    "limits.memory"                             = var.memory_limit
    "limits.cpu.allowance"                      = "100%"
    "security.nesting"                          = "true"
    "security.privileged"                       = "true"
    "security.syscalls.intercept.mknod"         = "true"
    "security.syscalls.intercept.setxattr"      = "true"
    "security.syscalls.intercept.mount"         = "true"
    "security.syscalls.intercept.mount.allowed" = "overlay,proc,tmpfs"
    "security.syscalls.intercept.mount.fuse"    = "ext4=ext4,btrfs=btrfs"
    "linux.kernel_modules"                      = "ip_tables,ip6_tables,netlink_diag,nf_nat,overlay,br_netfilter,xt_conntrack,xt_MASQUERADE,iptable_nat,iptable_filter"
    "raw.lxc"                                   = <<-EOF
      lxc.apparmor.profile=unconfined
      lxc.cap.drop=
      lxc.cgroup.devices.allow=a
      lxc.mount.auto=proc:rw sys:rw cgroup:rw
      EOF
  }

  device {
    name = "root"
    type = "disk"

    properties = {
      path = "/"
      pool = "default"
      size = var.disk_size
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = incus_network.k3s_network.name
    }
  }

  device {
    name = "kmsg"
    type = "unix-char"
    properties = {
      source = "/dev/kmsg"
      path   = "/dev/kmsg"
    }
  }
}

resource "incus_instance" "k3s_master" {
  name     = "${var.cluster_name}-master"
  image    = var.container_image
  type     = "container"
  profiles = [incus_profile.k3s_profile.name]

  config = {
    "cloud-init.user-data" = templatefile("./files/cloud-init-master.yaml", {
      k3s_token = random_password.k3s_token.result
    })
  }
}

resource "incus_instance" "k3s_workers" {
  count      = var.worker_count
  name       = "${var.cluster_name}-worker-${count.index + 1}"
  image      = var.container_image
  type       = "container"
  profiles   = [incus_profile.k3s_profile.name]
  depends_on = [incus_instance.k3s_master]

  config = {
    "cloud-init.user-data" = templatefile("./files/cloud-init-worker.yaml", {
      k3s_token = random_password.k3s_token.result
      master_ip = try(incus_instance.k3s_master.ipv4_address, "")
    })
  }
}

resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

resource "null_resource" "get_kubeconfig" {
  depends_on = [incus_instance.k3s_workers]

  provisioner "local-exec" {
    command = <<-EOF
      until incus exec ${incus_instance.k3s_master.name} -- k3s kubectl get nodes; do
        echo "Waiting for K3s API to be ready..."
        sleep 10
      done
    EOF
  }

  provisioner "local-exec" {
    command = "incus file pull ${incus_instance.k3s_master.name}/etc/rancher/k3s/k3s.yaml ./files/kubeconfig"
  }

  provisioner "local-exec" {
    command = "if ! netstat -tlnp 2>/dev/null | grep -q ':6443.*LISTEN'; then ssh -f -N -L 6443:${incus_instance.k3s_master.ipv4_address}:6443 -J ${var.jump_host} k3s@${var.target_host}; fi"
  }

  triggers = {
    master_ip = incus_instance.k3s_master.ipv4_address
  }
}

data "local_file" "kubeconfig" {
  filename   = "./files/kubeconfig"
  depends_on = [null_resource.get_kubeconfig]
}

module "deployments" {
  source           = "./deployments"
  cloudsql_proxies = var.cloudsql_proxies
  github           = var.github
  infisical        = var.infisical
  k3s_master       = incus_instance.k3s_master
  k3s_workers      = incus_instance.k3s_workers
  kubeconfig_path  = local.kubeconfig_ready
  prefect_address  = var.prefect_address
  tailscale        = var.tailscale
}
