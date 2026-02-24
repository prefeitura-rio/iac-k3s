set quiet
set shell := ["bash", "-euo", "pipefail", "-c"]
set dotenv-load

bucket := "bucket=iplanrio-dia-terraform"
tfplan := "terraform/terraform.tfplan"
infisical := "npx @infisical/cli@latest"
infisical_json_path := "terraform/.infisical.json"

# Verify connection to correct Tailscale network
[private]
check_tailscale:
    scripts/check-tailscale.sh

# Ensure Infisical configuration exists
[private]
ensure_infisical_config:
    test -f {{infisical_json_path}} || { echo "Error: {{infisical_json_path}} file not found"; exit 1; }

# Ensure Incus token exists and connection works (idempotent)
[private]
ensure_incus_token: check_tailscale
    scripts/ensure-incus.sh

# Ensure Kubernetes configuration exists (idempotent)
[private]
ensure_kubeconfig: ensure_incus_token
    scripts/ensure-kubeconfig.sh

# Run Ansible playbook for host configuration
ansible: check_tailscale ensure_infisical_config
    ansible-playbook playbook.yaml

# Authenticate with Google Cloud and Infisical
auth: ensure_infisical_config
    gcloud auth application-default login
    {{infisical}} login

# Force regenerate Incus authentication token
token_force: check_tailscale
    scripts/ensure-incus.sh --force

# Force regenerate Kubernetes cluster configuration
kubeconfig_force: check_tailscale ensure_incus_token
    scripts/ensure-kubeconfig.sh --force

# Initialize Terraform
init: ensure_infisical_config
    cd terraform && terraform init -backend-config {{bucket}} -upgrade -reconfigure

# Validate Terraform configuration syntax
validate: ensure_infisical_config
    echo "Validating terraform configuration..."
    cd terraform && terraform validate
    echo "Terraform validation completed successfully!"

# Format Terraform files
fmt:
    cd terraform && terraform fmt -recursive

# Plan Terraform changes
plan: check_tailscale ensure_incus_token ensure_kubeconfig
    echo "Running terraform plan..."
    cd terraform && {{infisical}} run -- terraform plan -out terraform.tfplan
    echo "Terraform plan completed successfully!"

# Apply Terraform changes
apply: check_tailscale ensure_incus_token ensure_kubeconfig
    echo "Running terraform apply..."
    cd terraform && {{infisical}} run -- terraform apply terraform.tfplan
    echo "Terraform apply completed successfully!"

# Complete setup workflow (plan only, review before applying)
setup: plan
    echo "Setup complete! Review the plan and run 'just apply' to deploy."

# Destroy Terraform resources
[confirm("Are you sure you want to destroy all resources?")]
destroy: check_tailscale
    echo "Running terraform destroy..."
    cd terraform && {{infisical}} run -- terraform destroy
    echo "Terraform destroy completed successfully!"

# Clean generated files and Terraform plans
[confirm("Are you sure you want to clean generated files?")]
clean:
    echo "Cleaning generated files..."
    rm -f {{tfplan}} "${INCUS_TOKEN_FILE}" || true
    rm -f "${KUBECONFIG}" || true
    echo "Cleanup complete"
