set quiet
set shell := ["bash", "-euo", "pipefail", "-c"]

info    := '\033[36m[→]\033[0m'
success := '\033[32m[✓]\033[0m'
error   := '\033[31m[✗]\033[0m'
warning := '\033[33m[⚠]\033[0m'
tfdir   := "terraform"

# Default recipe
default: apply

[private]
check-unencrypted-tfvars:
    git diff --cached --name-only | grep -qx "terraform/terraform.tfvars.json" && { echo -e "{{ error }} Plaintext tfvars staged — encrypt with: just edit-tfvars"; exit 1; } || true

[private]
validate-tailscale:
    tailscale status --json 2>/dev/null | jq -re '.Self.DNSName | test("squirrel-regulus\\.ts\\.net")' > /dev/null || { echo -e "{{ error }} Not connected to squirrel-regulus.ts.net — run: tailscale up"; exit 1; }
    echo -e "{{ success }} Connected to squirrel-regulus.ts.net"

[private]
ensure-incus force="": validate-tailscale
    #!/usr/bin/env bash
    [[ -n "{{ force }}" ]] && rm -f "${INCUS_TOKEN_FILE:-}"
    if incus list &>/dev/null; then
        echo -e "{{ success }} Incus connection already working"
        exit 0
    fi
    if [[ -z "${INCUS_TOKEN_FILE:-}" || -z "${INCUS_SERVER_HOST:-}" || -z "${INCUS_SERVER_USER:-}" ]]; then
        echo -e "{{ error }} INCUS_TOKEN_FILE, INCUS_SERVER_HOST and INCUS_SERVER_USER must be set (run 'direnv allow')"
        exit 1
    fi
    machine_id=$(cat /etc/machine-id 2>/dev/null || cat /var/lib/dbus/machine-id 2>/dev/null || hostname)
    client_name="${HOSTNAME:-$(hostname)}-${machine_id:0:8}"
    echo -e "{{ info }} Generating Incus token for ${client_name} via ${INCUS_SERVER_HOST}..."
    token=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$INCUS_SERVER_USER@$INCUS_SERVER_HOST" "incus config trust add ${client_name}" | tail -n 1)
    if [[ -z "$token" || ${#token} -lt 32 ]]; then
        echo -e "{{ error }} Failed to obtain a valid token from ${INCUS_SERVER_HOST}"
        exit 1
    fi
    echo "$token" > "$INCUS_TOKEN_FILE"
    chmod 600 "$INCUS_TOKEN_FILE"
    incus remote add k3s "${INCUS_SERVER_HOST}:8443" --accept-certificate --token="$token" 2>/dev/null || true
    incus remote switch k3s
    echo -e "{{ success }} Incus client configured"

[private]
ensure-kubeconfig force="": ensure-incus
    #!/usr/bin/env bash
    [[ -n "{{ force }}" ]] && rm -f "${KUBECONFIG:-}"
    if [[ -z "${KUBECONFIG:-}" || -z "${CLUSTER_NAME:-}" ]]; then
        echo -e "{{ error }} KUBECONFIG and CLUSTER_NAME must be set (run 'direnv allow')"
        exit 1
    fi
    hostname="${K3S_MASTER_HOSTNAME:-k3s-master}"
    if [[ -s "$KUBECONFIG" ]] \
        && kubectl config view --kubeconfig "$KUBECONFIG" --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null | grep -q "$hostname" \
        && kubectl --kubeconfig "$KUBECONFIG" get nodes &>/dev/null; then
        echo -e "{{ success }} Kubeconfig already valid"
        exit 0
    fi
    echo -e "{{ info }} Fetching kubeconfig from ${CLUSTER_NAME}-master..."
    mkdir -p "$(dirname "$KUBECONFIG")"
    incus file pull "${CLUSTER_NAME}-master/etc/rancher/k3s/k3s.yaml" "$KUBECONFIG"
    chmod 600 "$KUBECONFIG"
    sed -i "s|127.0.0.1|${hostname}|g" "$KUBECONFIG"
    kubectl --kubeconfig "$KUBECONFIG" get nodes &>/dev/null \
        || { echo -e "{{ error }} Kubeconfig fetched but cluster unreachable"; exit 1; }
    echo -e "{{ success }} Kubeconfig saved at ${KUBECONFIG}"

[private]
ensure-init:
    #!/usr/bin/env bash
    current=$(jq -r '.backend.config.bucket // empty' {{ tfdir }}/.terraform/terraform.tfstate 2>/dev/null || true)
    [[ "$current" == "iplanrio-terraform-state" ]] && echo -e "{{ info }} Terraform already initialized, skipping" && exit 0
    echo -e "{{ info }} Initializing Terraform..."
    cd {{ tfdir }} && terraform init -backend-config bucket=iplanrio-terraform-state -upgrade -reconfigure
    echo -e "{{ success }} Terraform initialized"

# Authenticate with Google Cloud
auth:
    echo -e "{{ info }} Authenticating with Google Cloud..."
    gcloud auth application-default login
    echo -e "{{ success }} Authentication completed"

# Run Ansible playbook for host configuration
ansible: validate-tailscale
    echo -e "{{ info }} Running Ansible playbook..."
    ansible-playbook playbook.yaml
    echo -e "{{ success }} Ansible playbook completed"

# Force regenerate Incus authentication token
token-force: (ensure-incus "force")

# Force regenerate Kubernetes cluster configuration
kubeconfig-force: (ensure-kubeconfig "force")

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
apply: ensure-init ensure-kubeconfig
    echo -e "{{ info }} Applying Terraform changes..."
    cd {{ tfdir }} && sops exec-file --output-type json --filename tfvars.json terraform.tfvars.json.sops 'terraform apply -var-file={} -var="cluster_name=$CLUSTER_NAME"'
    echo -e "{{ success }} Apply completed"

# Edit secrets
edit-tfvars:
    sops edit --input-type json --output-type json {{ tfdir }}/terraform.tfvars.json.sops

# Destroy Terraform resources
[confirm("Are you sure you want to destroy all resources?")]
destroy: ensure-init validate-tailscale
    echo -e "{{ warning }} Running Terraform destroy..."
    cd {{ tfdir }} && sops exec-file --output-type json --filename tfvars.json terraform.tfvars.json.sops 'terraform destroy -var-file={} -var="cluster_name=$CLUSTER_NAME"'
    echo -e "{{ success }} Destroy completed"
