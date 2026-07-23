set quiet
set shell := ["bash", "-euo", "pipefail", "-c"]

info    := '\033[36m[>]\033[0m'
success := '\033[32m[ok]\033[0m'
tfdir    := env("TF_DIR", ".")
sops_dir := env("K3S_SOPS_DIR", ".k3s")

export TF_BACKEND_CONFIG := "bucket=iplanrio-terraform-state"
export TF_SOPS_FILE      := tfdir + "/terraform.tfvars.sops.json"

default: apply

[private]
validate-tailscale:
    k3s validate-tailscale

[private]
ensure-incus force="":
    k3s ensure-incus {{ if force != "" { "--force" } else { "" } }}

[private]
ensure-init:
    prefrio ensure-init

# Run any command with KUBECONFIG injected from kubeconfig.sops
run *args:
    sops exec-file --no-fifo {{ sops_dir }}/kubeconfig.sops 'KUBECONFIG={} {{ args }}'

# Run Ansible playbook for host configuration
ansible: validate-tailscale
    echo -e "{{ info }} Running Ansible playbook..."
    ansible-playbook playbook.yaml
    echo -e "{{ success }} Ansible playbook completed"

# Rotate Incus authentication token (revoke + regenerate + re-encrypt)
rotate-incus-token: (ensure-incus "force")

# Bootstrap or rotate kubeconfig: fetch from cluster and encrypt
rotate-kubeconfig: validate-tailscale ensure-incus
    k3s ensure-kubeconfig

# Initialize Terraform (forced)
init:
    prefrio init

# Format Terraform files
fmt:
    prefrio fmt

# Validate Terraform configuration
validate: ensure-init
    prefrio validate

# Apply Terraform changes
apply: validate-tailscale ensure-init
    k3s apply

# Import an existing resource into Terraform state
import address id: validate-tailscale ensure-init
    k3s import '{{ address }}' '{{ id }}'

# Edit secrets
edit-tfvars:
    prefrio edit-tfvars

# Destroy Terraform resources
[confirm("Are you sure you want to destroy all resources?")]
destroy: validate-tailscale ensure-init
    k3s destroy
