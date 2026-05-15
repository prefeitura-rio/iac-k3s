set quiet
set shell := ["bash", "-euo", "pipefail", "-c"]

info    := '\033[36m[→]\033[0m'
success := '\033[32m[✓]\033[0m'
error   := '\033[31m[✗]\033[0m'
warning := '\033[33m[⚠]\033[0m'
tfdir    := "terraform"
sops_dir := env_var_or_default("K3S_SOPS_DIR", ".k3s")

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
    sops_file="{{ sops_dir }}/incus-token.sops"
    [[ -n "{{ force }}" ]] && rm -f "$sops_file"
    if command -v incus &>/dev/null && incus list &>/dev/null; then
        echo -e "{{ success }} Incus connection already working"
        exit 0
    fi
    if [[ -z "${INCUS_SERVER_HOST:-}" || -z "${INCUS_SERVER_USER:-}" ]]; then
        echo -e "{{ error }} INCUS_SERVER_HOST and INCUS_SERVER_USER must be set (run 'direnv allow')"
        exit 1
    fi
    if ! command -v incus &>/dev/null; then
        echo -e "{{ warning }} incus not installed — skipping remote configuration"
        exit 0
    fi
    machine_id=$(cat /etc/machine-id 2>/dev/null || cat /var/lib/dbus/machine-id 2>/dev/null || hostname)
    client_name="${HOSTNAME:-$(hostname)}-${machine_id:0:8}"
    echo -e "{{ info }} Generating Incus token for ${client_name} via ${INCUS_SERVER_HOST}..."
    ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$INCUS_SERVER_USER@$INCUS_SERVER_HOST" "incus config trust revoke-token ${client_name}" &>/dev/null || true
    token=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$INCUS_SERVER_USER@$INCUS_SERVER_HOST" "incus config trust add ${client_name}" | tail -n 1)
    if [[ -z "$token" || ${#token} -lt 32 ]]; then
        echo -e "{{ error }} Failed to obtain a valid token from ${INCUS_SERVER_HOST}"
        exit 1
    fi
    mkdir -p "{{ sops_dir }}"
    echo "$token" | sops encrypt --input-type binary --output-type binary --filename-override "$sops_file" /dev/stdin > "$sops_file"
    chmod 600 "$sops_file"
    incus remote add k3s "${INCUS_SERVER_HOST}:8443" --accept-certificate --token="$token" 2>/dev/null || true
    incus remote switch k3s
    echo -e "{{ success }} Incus client configured"

[private]
ensure-kubeconfig force="": ensure-incus
    #!/usr/bin/env bash
    sops_file="{{ sops_dir }}/kubeconfig.sops"
    [[ -n "{{ force }}" ]] && rm -f "$sops_file"
    if [[ -z "${CLUSTER_NAME:-}" ]]; then
        echo -e "{{ error }} CLUSTER_NAME must be set (run 'direnv allow')"
        exit 1
    fi
    hostname="${K3S_MASTER_HOSTNAME:-k3s-master}"
    if [[ -s "$sops_file" ]] \
        && sops exec-file "$sops_file" 'kubectl --kubeconfig={} config view --minify -o jsonpath={.clusters[0].cluster.server}' 2>/dev/null | grep -q "$hostname" \
        && sops exec-file "$sops_file" 'kubectl --kubeconfig={} get nodes' &>/dev/null; then
        echo -e "{{ success }} Kubeconfig already valid"
        exit 0
    fi
    echo -e "{{ info }} Fetching kubeconfig from ${CLUSTER_NAME}-master..."
    mkdir -p "{{ sops_dir }}"
    incus file pull "${CLUSTER_NAME}-master/etc/rancher/k3s/k3s.yaml" /dev/stdout \
        | sed "s|127.0.0.1|${hostname}|g" \
        | sops encrypt --input-type binary --output-type binary --filename-override "$sops_file" /dev/stdin > "$sops_file"
    chmod 600 "$sops_file"
    sops exec-file "$sops_file" 'kubectl --kubeconfig={} get nodes' &>/dev/null \
        || { echo -e "{{ error }} Kubeconfig fetched but cluster unreachable"; exit 1; }
    echo -e "{{ success }} Kubeconfig encrypted at ${sops_file}"

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
    gcloud auth application-default set-quota-project rj-iplanrio-dia
    echo -e "{{ success }} Authentication completed"

# Run Ansible playbook for host configuration
ansible: validate-tailscale
    echo -e "{{ info }} Running Ansible playbook..."
    ansible-playbook playbook.yaml
    echo -e "{{ success }} Ansible playbook completed"

# Rotate Incus authentication token (revoke + regenerate + re-encrypt)
rotate-token: (ensure-incus "force")

# Rotate Kubernetes cluster configuration (re-fetch + re-encrypt)
rotate-kubeconfig: (ensure-kubeconfig "force")

# Initialize Terraform (forced)
init:
    echo -e "{{ info }} Initializing Terraform..."
    cd {{ tfdir }} && terraform init -backend-config bucket=iplanrio-terraform-state -upgrade -reconfigure
    echo -e "{{ success }} Terraform initialized"

# Validate Terraform configuration
validate: ensure-init
    echo -e "{{ info }} Validating Terraform configuration..."
    cd {{ tfdir }} && terraform validate
    echo -e "{{ success }} Validation completed"

# Format Terraform files
fmt:
    echo -e "{{ info }} Formatting Terraform files..."
    cd {{ tfdir }} && terraform fmt -recursive
    echo -e "{{ success }} Formatting completed"

[private]
with-secrets command:
    #!/usr/bin/env bash
    tmp_kubeconfig=$(mktemp)
    trap 'rm -f "$tmp_kubeconfig"' EXIT
    sops decrypt --output-type binary "{{ sops_dir }}/kubeconfig.sops" > "$tmp_kubeconfig"
    chmod 600 "$tmp_kubeconfig"
    incus_token=$(sops decrypt --output-type binary "{{ sops_dir }}/incus-token.sops")
    export TF_VAR_kubeconfig_path="$tmp_kubeconfig"
    export TF_VAR_incus_token="$incus_token"
    eval "{{ command }}"

# Apply Terraform changes
apply: validate ensure-kubeconfig
    #!/usr/bin/env bash
    echo -e "{{ info }} Applying Terraform changes..."
    just with-secrets "cd {{ tfdir }} && sops exec-file --output-type json --filename tfvars.json terraform.tfvars.json.sops \
        'terraform apply -var-file={} -var=cluster_name=\$CLUSTER_NAME'"
    echo -e "{{ success }} Apply completed"

# Import an existing resource into Terraform state
import address id: ensure-init
    #!/usr/bin/env bash
    export TF_ADDRESS='{{ address }}'
    export TF_ID='{{ id }}'
    just with-secrets "cd {{ tfdir }} && sops exec-file --output-type json --filename tfvars.json terraform.tfvars.json.sops \
        'terraform import -var-file={} -var=cluster_name=\$CLUSTER_NAME \$TF_ADDRESS \$TF_ID'"

# Edit secrets
edit-tfvars:
    sops edit --input-type json --output-type json {{ tfdir }}/terraform.tfvars.json.sops

# Destroy Terraform resources
[confirm("Are you sure you want to destroy all resources?")]
destroy: ensure-init validate-tailscale
    #!/usr/bin/env bash
    echo -e "{{ warning }} Running Terraform destroy..."
    just with-secrets "cd {{ tfdir }} && sops exec-file --output-type json --filename tfvars.json terraform.tfvars.json.sops \
        'terraform destroy -var-file={} -var=cluster_name=\$CLUSTER_NAME'"
    echo -e "{{ success }} Destroy completed"
