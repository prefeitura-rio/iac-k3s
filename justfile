set quiet
set shell := ["bash", "-euo", "pipefail", "-c"]
set dotenv-load

info := '\033[36m[→]\033[0m'
success := '\033[32m[✓]\033[0m'
error := '\033[31m[✗]\033[0m'
warning := '\033[33m[⚠]\033[0m'
debug := '\033[34m[ℹ]\033[0m'

bucket := "bucket=iplanrio-terraform-state"
tfplan := "terraform.tfplan"
infisical := "npx @infisical/cli@latest"
infisical_json_path := ".infisical.json"
tf_dir := "terraform"

# Default recipe
default: plan

[private]
validate_tailscale:
    #!/usr/bin/env bash
    echo -e "{{info}} Checking Tailscale configuration..."

    if ! tailscale status &>/dev/null; then
        echo -e "{{error}} Not connected to Tailscale!"
        echo "    Run: tailscale up"
        exit 1
    fi

    CURRENT_TAILNET=$(tailscale status --json | jq -r '.Self.DNSName' | sed 's/^[^.]*\.//' | sed 's/\.$//')

    if [[ "$CURRENT_TAILNET" != "squirrel-regulus.ts.net" ]]; then
        echo -e "{{error}} Wrong Tailscale network!"
        echo "    Expected: squirrel-regulus.ts.net"
        echo "    Current: $CURRENT_TAILNET"
        exit 1
    fi

    echo -e "{{success}} Connected to squirrel-regulus.ts.net"

[private]
ensure_infisical_config:
    #!/usr/bin/env bash
    if [[ ! -f "{{tf_dir}}/{{infisical_json_path}}" ]]; then
        echo -e "{{error}} {{tf_dir}}/{{infisical_json_path}} file not found"
        exit 1
    fi

[private]
ensure_incus_token: validate_tailscale
    scripts/ensure-incus.sh

[private]
ensure_kubeconfig: ensure_incus_token
    scripts/ensure-kubeconfig.sh

# Show environment configuration
debug:
    echo -e "{{debug}} Environment Configuration"
    echo "    bucket: {{bucket}}"
    echo "    tf_dir: {{tf_dir}}"
    echo "    tfplan: {{tfplan}}"

# Authenticate with Google Cloud and Infisical
auth: ensure_infisical_config
    echo -e "{{info}} Authenticating with Google Cloud..."
    gcloud auth application-default login
    echo -e "{{info}} Authenticating with Infisical..."
    {{infisical}} login
    echo -e "{{success}} Authentication completed"

# Run Ansible playbook for host configuration
ansible: validate_tailscale ensure_infisical_config
    echo -e "{{info}} Running Ansible playbook..."
    ansible-playbook playbook.yaml
    echo -e "{{success}} Ansible playbook completed"

# Force regenerate Incus authentication token
token_force: validate_tailscale
    scripts/ensure-incus.sh --force

# Force regenerate Kubernetes cluster configuration
kubeconfig_force: validate_tailscale ensure_incus_token
    scripts/ensure-kubeconfig.sh --force

# Initialize Terraform
init: ensure_infisical_config
    echo -e "{{info}} Initializing Terraform..."
    cd {{tf_dir}} && terraform init -backend-config {{bucket}} -upgrade -reconfigure
    echo -e "{{success}} Terraform initialized"

# Validate Terraform configuration
validate: ensure_infisical_config
    echo -e "{{info}} Validating Terraform configuration..."
    cd {{tf_dir}} && terraform validate
    echo -e "{{success}} Validation completed"

# Format Terraform files
fmt:
    echo -e "{{info}} Formatting Terraform files..."
    cd {{tf_dir}} && terraform fmt -recursive
    echo -e "{{success}} Formatting completed"

# Plan Terraform changes
plan: validate_tailscale ensure_incus_token ensure_kubeconfig
    echo -e "{{info}} Running Terraform plan..."
    cd {{tf_dir}} && {{infisical}} run -- terraform plan -var="cluster_name=$CLUSTER_NAME" -out {{tfplan}}
    echo -e "{{success}} Plan completed"

# Apply Terraform changes
apply: validate_tailscale ensure_incus_token ensure_kubeconfig
    echo -e "{{info}} Applying Terraform changes..."
    cd {{tf_dir}} && {{infisical}} run -- terraform apply {{tfplan}}
    echo -e "{{success}} Apply completed"

# Complete setup workflow (plan only, review before applying)
setup: plan
    echo -e "{{debug}} Setup complete! Review the plan and run 'just apply' to deploy."

# Destroy Terraform resources
[confirm("Are you sure you want to destroy all resources?")]
destroy: validate_tailscale
    echo -e "{{warning}} Running Terraform destroy..."
    cd {{tf_dir}} && {{infisical}} run -- terraform destroy -var="cluster_name=$CLUSTER_NAME"
    echo -e "{{success}} Destroy completed"

# Clean generated files and Terraform plans
[confirm("Are you sure you want to clean generated files?")]
clean:
    echo -e "{{info}} Cleaning generated files..."
    rm -f {{tf_dir}}/{{tfplan}} || true
    rm -f incus-token.txt || true
    rm -f {{tf_dir}}/files/kubeconfig || true
    echo -e "{{success}} Cleanup completed"
