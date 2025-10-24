set dotenv-load
set quiet

bucket := "bucket=iplanrio-dia-terraform"
tfplan := "terraform/terraform.tfplan"
infisical := "npx @infisical/cli@latest"
infisical_json_path := "terraform/.infisical.json"

# Verify connection to correct Tailscale network
@check-tailscale:
    scripts/check-tailscale.sh

# Ensure Infisical configuration exists
@ensure-infisical-config:
    test -f {{infisical_json_path}} || { echo "[ERROR] {{infisical_json_path}} file not found"; exit 1; }

# Ensure Incus token exists and connection works (idempotent)
@ensure-incus-token: check-tailscale
    scripts/ensure-incus.sh

# Ensure Kubernetes configuration exists (idempotent)
@ensure-kubeconfig: ensure-incus-token
    scripts/ensure-kubeconfig.sh

# Run Ansible playbook for host configuration
@ansible: check-tailscale ensure-infisical-config
    ansible-playbook playbook.yaml

# Authenticate with Google Cloud and Infisical
@auth: ensure-infisical-config
    gcloud auth application-default login
    {{infisical}} login

# Force regenerate Incus authentication token
@token-force: check-tailscale
    scripts/ensure-incus.sh --force

# Force regenerate Kubernetes cluster configuration
@kubeconfig-force: check-tailscale ensure-incus-token
    scripts/ensure-kubeconfig.sh --force

# Remove all generated files and Terraform plans
@clean:
    echo "[INFO] Cleaning generated files..."
    rm -f {{tfplan}} "${INCUS_TOKEN_FILE}"
    rm -f "${KUBECONFIG}"
    echo "[INFO] Cleanup complete"

# Init Terraform with backend config
@init: ensure-infisical-config
    cd terraform && terraform init -backend-config {{bucket}} -upgrade -reconfigure

# Validate Terraform configuration syntax
@validate: ensure-infisical-config
    echo "[INFO] Validating terraform configuration..."
    cd terraform && terraform validate

# Plan Terraform changes
@plan: check-tailscale ensure-incus-token ensure-kubeconfig
    cd terraform && {{infisical}} run -- terraform plan -out terraform.tfplan

# Apply Terraform changes
@apply: check-tailscale ensure-incus-token ensure-kubeconfig
    cd terraform && {{infisical}} run -- terraform apply terraform.tfplan

# Complete setup workflow (plan only, review before applying)
@setup: plan
    echo "[INFO] Setup complete! Review the plan and run 'just apply' to deploy."

# Destroy Terraform-managed infrastructure
@destroy: check-tailscale
    cd terraform && {{infisical}} run -- terraform destroy -auto-approve
