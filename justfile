bucket := "bucket=iplanrio-dia-terraform"
tfplan := "terraform/terraform.tfplan"

# Ensure Infisical configuration exists
@ensure-infisical-config:
    test -f terraform/.infisical.json || { echo "[ERROR] terraform/.infisical.json file not found"; exit 1; }

# Ensure Incus token exists and connection works (idempotent)
@ensure-incus-token:
    scripts/ensure-incus.sh

# Ensure Kubernetes configuration exists (idempotent)
@ensure-kubeconfig: ensure-incus-token
    scripts/ensure-kubeconfig.sh

# Run Ansible playbook for host configuration
@ansible: ensure-infisical-config
    ansible-playbook playbook.yaml

# Authenticate with Google Cloud and Infisical
@auth: ensure-infisical-config
    gcloud auth application-default login
    infisical login

# Force regenerate Incus authentication token
@token-force:
    scripts/ensure-incus.sh --force

# Force regenerate Kubernetes cluster configuration
@kubeconfig-force: ensure-infisical-config ensure-incus-token
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

# Plan Terraform changes
@plan: ensure-incus-token ensure-kubeconfig
    cd terraform && infisical run -- terraform plan -out terraform.tfplan

# Apply Terraform changes
@apply: ensure-incus-token ensure-kubeconfig
    cd terraform && infisical run -- terraform apply terraform.tfplan

# Destroy Terraform-managed infrastructure
@destroy:
    cd terraform && infisical run -- terraform destroy -auto-approve
