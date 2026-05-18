set quiet
set shell := ["bash", "-euo", "pipefail", "-c"]

info := '\033[36m[→]\033[0m'
success := '\033[32m[✓]\033[0m'
error := '\033[31m[✗]\033[0m'
tfdir := "terraform"
sops_dir := env("K3S_SOPS_DIR", ".k3s")

default: apply

# Abort commit if plaintext tfvars are staged
[private]
check-unencrypted-tfvars:
    #!/usr/bin/env bash
    if git diff --cached --name-only | grep -qx "terraform/terraform.tfvars.json"; then
        echo -e "{{ error }} Plaintext tfvars staged — encrypt with: just edit-tfvars"
        exit 1
    fi

# Verify Tailscale is connected to the expected network
[private]
validate-tailscale:
    python3 -m scripts.validate_tailscale

# Ensure Incus remote is configured with a valid token
[private]
ensure-incus force="":
    python3 -m scripts.ensure_incus {{ if force != "" { "--force" } else { "" } }}

# Initialize Terraform backend if not already done
[private]
ensure-init:
    #!/usr/bin/env bash
    current=$(jq -r '.backend.config.bucket // empty' {{ tfdir }}/.terraform/terraform.tfstate 2>/dev/null || true)

    if [[ "$current" == "iplanrio-terraform-state" ]]; then
        echo -e "{{ info }} Terraform already initialized, skipping"
        exit 0
    fi

    echo -e "{{ info }} Initializing Terraform..."
    cd {{ tfdir }} && terraform init -backend-config bucket=iplanrio-terraform-state -upgrade -reconfigure
    echo -e "{{ success }} Terraform initialized"

# Run any command with KUBECONFIG injected from kubeconfig.sops
run *args:
    sops exec-file --no-fifo {{ sops_dir }}/kubeconfig.sops 'KUBECONFIG={} {{ args }}'

# Authenticate with Google Cloud
auth:
    echo -e "{{ info }} Authenticating with Google Cloud..."
    gcloud auth application-default login
    gcloud auth application-default set-quota-project rj-iplanrio-dia
    echo -e "{{ success }} Authentication completed"

# Run Ansible playbook for host configuration
ansible: validate-tailscale
    echo -e "{{ info }} Running Ansible playbook..."
    ansible-playbook playbook.yaml
    echo -e "{{ success }} Ansible playbook completed"

# Rotate Incus authentication token (revoke + regenerate + re-encrypt)
rotate-incus-token: (ensure-incus "force")

# Bootstrap or rotate kubeconfig: fetch from cluster and encrypt
rotate-kubeconfig: validate-tailscale ensure-incus
    python3 -m scripts.ensure_kubeconfig

# Initialize Terraform (forced)
init:
    echo -e "{{ info }} Initializing Terraform..."
    cd {{ tfdir }} && terraform init -backend-config bucket=iplanrio-terraform-state -upgrade -reconfigure
    echo -e "{{ success }} Terraform initialized"

# Validate Terraform configuration
validate:
    echo -e "{{ info }} Validating Terraform configuration..."
    cd {{ tfdir }} && terraform validate
    echo -e "{{ success }} Validation completed"

# Format Terraform files
fmt:
    echo -e "{{ info }} Formatting Terraform files..."
    cd {{ tfdir }} && terraform fmt -recursive
    echo -e "{{ success }} Formatting completed"

# Apply Terraform changes
apply: validate-tailscale ensure-init
    python3 -m scripts.terraform apply

# Import an existing resource into Terraform state
import address id: validate-tailscale ensure-init
    python3 -m scripts.terraform import '{{ address }}' '{{ id }}'

# Edit secrets
edit-tfvars:
    sops edit --input-type json --output-type json {{ tfdir }}/terraform.tfvars.sops.json

# Destroy Terraform resources
[confirm("Are you sure you want to destroy all resources?")]
destroy: validate-tailscale ensure-init
    python3 -m scripts.terraform destroy
