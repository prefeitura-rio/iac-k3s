output "k3s_master_ip" {
  description = "IP address of the K3s master node"
  value       = incus_instance.k3s_master.ipv4_address
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = abspath("./kubeconfig")
  depends_on  = [null_resource.wait_for_k3s]
}
