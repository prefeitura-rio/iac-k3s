set quiet
set shell := ["bash", "-euo", "pipefail", "-c"]
set dotenv-load

cyan := '\033[36m'
green := '\033[32m'
red := '\033[31m'
yellow := '\033[33m'
blue := '\033[34m'
reset := '\033[0m'

bucket := "bucket=iplanrio-dia-terraform"
tfplan := "terraform.tfplan"
infisical := "npx @infisical/cli@latest"
infisical_json_path := ".infisical.json"
tf_dir := "terraform"

# Default recipe
default: plan

[private]
validate_tailscale:
    #!/usr/bin/env bash
    set -euo pipefail
    echo -e "{{cyan}}[→] Checking Tailscale configuration...{{reset}}"

    if ! tailscale status &>/dev/null; then
        echo -e "{{red}}[✗] Error: Not connected to Tailscale!{{reset}}"
        echo "    Run: tailscale up"
        exit 1
    fi

    CURRENT_TAILNET=$(tailscale status --json | jq -r '.Self.DNSName' | sed 's/^[^.]*\.//' | sed 's/\.$//')
    if [[ "$CURRENT_TAILNET" != "squirrel-regulus.ts.net" ]]; then
        echo -e "{{red}}[✗] Error: Wrong Tailscale network!{{reset}}"
        echo "    Expected: squirrel-regulus.ts.net"
        echo "    Current: $CURRENT_TAILNET"
        exit 1
    fi

    echo -e "{{green}}[✓] Connected to squirrel-regulus.ts.net{{reset}}"

[private]
ensure_infisical_config:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ ! -f "{{tf_dir}}/{{infisical_json_path}}" ]]; then
        echo -e "{{red}}[✗] Error: {{tf_dir}}/{{infisical_json_path}} file not found{{reset}}"
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
    echo -e "{{blue}}[ℹ] Environment Configuration{{reset}}"
    echo "    bucket: {{bucket}}"
    echo "    tf_dir: {{tf_dir}}"
    echo "    tfplan: {{tfplan}}"

# Authenticate with Google Cloud and Infisical
auth: ensure_infisical_config
    echo -e "{{cyan}}[→] Authenticating with Google Cloud...{{reset}}"
    gcloud auth application-default login
    echo -e "{{cyan}}[→] Authenticating with Infisical...{{reset}}"
    {{infisical}} login
    echo -e "{{green}}[✓] Authentication completed{{reset}}"

# Run Ansible playbook for host configuration
ansible: validate_tailscale ensure_infisical_config
    echo -e "{{cyan}}[→] Running Ansible playbook...{{reset}}"
    ansible-playbook playbook.yaml
    echo -e "{{green}}[✓] Ansible playbook completed{{reset}}"

# Force regenerate Incus authentication token
token_force: validate_tailscale
    scripts/ensure-incus.sh --force

# Force regenerate Kubernetes cluster configuration
kubeconfig_force: validate_tailscale ensure_incus_token
    scripts/ensure-kubeconfig.sh --force

# Initialize Terraform
init: ensure_infisical_config
    echo -e "{{cyan}}[→] Initializing Terraform...{{reset}}"
    cd {{tf_dir}} && terraform init -backend-config {{bucket}} -upgrade -reconfigure
    echo -e "{{green}}[✓] Terraform initialized{{reset}}"

# Validate Terraform configuration
validate: ensure_infisical_config
    echo -e "{{cyan}}[→] Validating Terraform configuration...{{reset}}"
    cd {{tf_dir}} && terraform validate
    echo -e "{{green}}[✓] Validation completed{{reset}}"

# Format Terraform files
fmt:
    echo -e "{{cyan}}[→] Formatting Terraform files...{{reset}}"
    cd {{tf_dir}} && terraform fmt -recursive
    echo -e "{{green}}[✓] Formatting completed{{reset}}"

# Plan Terraform changes
plan: validate_tailscale ensure_incus_token ensure_kubeconfig
    echo -e "{{cyan}}[→] Running Terraform plan...{{reset}}"
    cd {{tf_dir}} && {{infisical}} run -- terraform plan -var="cluster_name=$CLUSTER_NAME" -out {{tfplan}}
    echo -e "{{green}}[✓] Plan completed{{reset}}"

# Apply Terraform changes
apply: validate_tailscale ensure_incus_token ensure_kubeconfig
    echo -e "{{cyan}}[→] Applying Terraform changes...{{reset}}"
    cd {{tf_dir}} && {{infisical}} run -- terraform apply {{tfplan}}
    echo -e "{{green}}[✓] Apply completed{{reset}}"

# Complete setup workflow (plan only, review before applying)
setup: plan
    echo -e "{{blue}}[ℹ] Setup complete! Review the plan and run 'just apply' to deploy.{{reset}}"

# Destroy Terraform resources
[confirm("Are you sure you want to destroy all resources?")]
destroy: validate_tailscale
    echo -e "{{yellow}}[⚠] Running Terraform destroy...{{reset}}"
    cd {{tf_dir}} && {{infisical}} run -- terraform destroy -var="cluster_name=$CLUSTER_NAME"
    echo -e "{{green}}[✓] Destroy completed{{reset}}"

# Clean generated files and Terraform plans
[confirm("Are you sure you want to clean generated files?")]
clean:
    echo -e "{{cyan}}[→] Cleaning generated files...{{reset}}"
    rm -f {{tf_dir}}/{{tfplan}} || true
    rm -f incus-token.txt || true
    rm -f {{tf_dir}}/files/kubeconfig || true
    echo -e "{{green}}[✓] Cleanup completed{{reset}}"
