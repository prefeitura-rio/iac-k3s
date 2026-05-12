set quiet
set shell := ["bash", "-euo", "pipefail", "-c"]

info    := '\033[36m[→]\033[0m'
success := '\033[32m[✓]\033[0m'
error   := '\033[31m[✗]\033[0m'
warning := '\033[33m[⚠]\033[0m'
debug   := '\033[34m[ℹ]\033[0m'
tf_dir  := "terraform"

# Default recipe
default: apply

[private]
validate-tailscale:
    #!/usr/bin/env bash
    echo -e "{{info}} Checking Tailscale configuration..."
    if ! tailscale status &>/dev/null; then
        echo -e "{{error}} Not connected to Tailscale! Run: tailscale up"
        exit 1
    fi
    CURRENT_TAILNET=$(tailscale status --json | jq -r '.Self.DNSName' | sed 's/^[^.]*\.//' | sed 's/\.$//')
    if [[ "$CURRENT_TAILNET" != "squirrel-regulus.ts.net" ]]; then
        echo -e "{{error}} Wrong Tailscale network! Expected: squirrel-regulus.ts.net, got: $CURRENT_TAILNET"
        exit 1
    fi
    echo -e "{{success}} Connected to squirrel-regulus.ts.net"

[private]
ensure-incus-token: validate-tailscale
    scripts/ensure-incus.sh

[private]
ensure-kubeconfig: ensure-incus-token
    scripts/ensure-kubeconfig.sh

# Show environment configuration
debug:
    echo -e "{{debug}} Environment Configuration"
    echo "    tf_dir: {{tf_dir}}"

# Authenticate with Google Cloud
auth:
    echo -e "{{info}} Authenticating with Google Cloud..."
    gcloud auth application-default login
    echo -e "{{success}} Authentication completed"

# Run Ansible playbook for host configuration
ansible: validate-tailscale
    echo -e "{{info}} Running Ansible playbook..."
    ansible-playbook playbook.yaml
    echo -e "{{success}} Ansible playbook completed"

# Force regenerate Incus authentication token
token-force: validate-tailscale
    scripts/ensure-incus.sh --force

# Force regenerate Kubernetes cluster configuration
kubeconfig-force: validate-tailscale ensure-incus-token
    scripts/ensure-kubeconfig.sh --force

[private]
ensure-init:
    #!/usr/bin/env bash
    current=$(jq -r '.backend.config.bucket // empty' {{tf_dir}}/.terraform/terraform.tfstate 2>/dev/null || true)
    [[ "$current" == "iplanrio-terraform-state" ]] && echo -e "{{info}} Terraform already initialized, skipping" && exit 0
    echo -e "{{info}} Initializing Terraform..."
    cd {{tf_dir}} && terraform init -backend-config bucket=iplanrio-terraform-state -upgrade -reconfigure
    echo -e "{{success}} Terraform initialized"

# Initialize Terraform (forced)
init:
    echo -e "{{info}} Initializing Terraform..."
    cd {{tf_dir}} && terraform init -backend-config bucket=iplanrio-terraform-state -upgrade -reconfigure
    echo -e "{{success}} Terraform initialized"

# Validate Terraform configuration
validate:
    echo -e "{{info}} Validating Terraform configuration..."
    cd {{tf_dir}} && terraform validate
    echo -e "{{success}} Validation completed"

# Format Terraform files
fmt:
    echo -e "{{info}} Formatting Terraform files..."
    cd {{tf_dir}} && terraform fmt -recursive
    echo -e "{{success}} Formatting completed"

# Apply Terraform changes
apply: ensure-init validate-tailscale ensure-incus-token ensure-kubeconfig
    echo -e "{{info}} Applying Terraform changes..."
    cd {{tf_dir}} && sops exec-file --output-type json terraform.tfvars.json.sops 'terraform apply -var-file={} -var="cluster_name=$CLUSTER_NAME"'
    echo -e "{{success}} Apply completed"

# Edit secrets
edit-tfvars:
    sops edit --input-type json --output-type json {{tf_dir}}/terraform.tfvars.json.sops

# Destroy Terraform resources
[confirm("Are you sure you want to destroy all resources?")]
destroy: ensure-init validate-tailscale
    echo -e "{{warning}} Running Terraform destroy..."
    cd {{tf_dir}} && sops exec-file --output-type json terraform.tfvars.json.sops 'terraform destroy -var-file={} -var="cluster_name=$CLUSTER_NAME"'
    echo -e "{{success}} Destroy completed"
