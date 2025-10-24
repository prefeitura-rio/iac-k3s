locals {
  kubeconfig_path = "./files/kubeconfig"
}

resource "incus_storage_pool" "incus_pool" {
  name   = "incus"
  driver = "zfs"

  config = {
    source = "incus"
  }
}

resource "incus_network" "k3s_network" {
  name = var.cluster_name

  config = {
    "ipv4.address" = var.network_cidr
    "ipv4.nat"     = "true"
    "ipv4.dhcp"    = "true"
    "ipv4.routing" = "true"
    "ipv6.address" = "none"
    "dns.domain"   = "incus"
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
      pool = incus_storage_pool.incus_pool.name
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
      k3s_token         = random_password.k3s_token.result
      tailscale_authkey = var.tailscale.authkey
      cluster_name      = var.cluster_name
    })
  }
}

resource "time_sleep" "wait_for_master_ip" {
  depends_on      = [incus_instance.k3s_master]
  create_duration = "10s"
}

resource "incus_instance" "k3s_workers" {
  count      = var.worker_count
  name       = "${var.cluster_name}-worker-${count.index + 1}"
  image      = var.container_image
  type       = "container"
  profiles   = [incus_profile.k3s_profile.name]
  depends_on = [time_sleep.wait_for_master_ip]

  config = {
    "cloud-init.user-data" = templatefile("./files/cloud-init-worker.yaml", {
      k3s_token         = random_password.k3s_token.result
      cluster_name      = var.cluster_name
      tailscale_authkey = var.tailscale.authkey
    })
  }
}

resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

module "deployments" {
  count            = fileexists(local.kubeconfig_path) ? 1 : 0
  depends_on       = [incus_instance.k3s_workers]
  source           = "./deployments"
  cloudsql_proxies = var.cloudsql_proxies
  github           = var.github
  infisical        = var.infisical
  k3s_master       = incus_instance.k3s_master
  k3s_workers      = incus_instance.k3s_workers
  kubeconfig_path  = local.kubeconfig_path
  prefect_address  = var.prefect_address
  tailscale        = var.tailscale
}
