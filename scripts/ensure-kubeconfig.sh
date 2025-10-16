#!/usr/bin/env bash

set -euo pipefail

source "$PWD/scripts/lib/common.sh"

check_existing_kubeconfig() {
    local kubeconfig_path="$1"
    check_file_exists "$kubeconfig_path"
}

validate_environment() {
    if [[ -z "${TF_VAR_cluster_name:-}" ]]; then
        echo "[ERROR] TF_VAR_cluster_name not set" >&2
        print_env_missing_error
        return 1
    fi

    if [[ -z "$KUBECONFIG" ]]; then
        echo "[ERROR] KUBECONFIG environment variable not set" >&2
        return 1
    fi
}

create_output_directory() {
    local dir="$1"
    mkdir -p "$dir"
}

fetch_kubeconfig_from_cluster() {
    local master_name="$1"
    local kubeconfig_path="$2"

    if ! retry_incus_command "incus file pull ${master_name}/etc/rancher/k3s/k3s.yaml $kubeconfig_path"; then
        echo "[ERROR] Failed to fetch kubeconfig from cluster after multiple attempts" >&2
        return 1
    fi

    if [[ ! -f "$kubeconfig_path" || ! -s "$kubeconfig_path" ]]; then
        echo "[ERROR] Kubeconfig file is missing or empty after fetch" >&2
        return 1
    fi
}

update_server_hostname() {
    local kubeconfig_path="$1"
    local cluster_hostname="$2"

    if ! sed -i "s|127.0.0.1|${cluster_hostname}|g" "$kubeconfig_path"; then
        echo "[ERROR] Failed to update server hostname in kubeconfig" >&2
        return 1
    fi

    if ! grep -q "$cluster_hostname" "$kubeconfig_path"; then
        echo "[WARNING] Hostname replacement may have failed - $cluster_hostname not found in kubeconfig" >&2
    fi
}

main() {
    local force_regenerate=false
    local remaining_args

    remaining_args=$(parse_force_flag force_regenerate "$@")

    if [[ -n "$remaining_args" ]]; then
        echo "[ERROR] Unknown argument: $remaining_args" >&2
        echo "Usage: $0 [--force|-f]" >&2
        exit 1
    fi

    validate_environment || exit 1

    local kubeconfig_path="$KUBECONFIG"

    if check_existing_kubeconfig "$kubeconfig_path" && [[ "$force_regenerate" == "false" ]]; then
        echo "[SUCCESS] Kubeconfig already exists at ${kubeconfig_path#"$PWD/"}"
        return 0
    fi

    if [[ "$force_regenerate" == "true" ]] && check_existing_kubeconfig "$kubeconfig_path"; then
        echo "[INFO] Force regenerating existing kubeconfig..."
        rm -f "$kubeconfig_path"
    fi

    echo "[INFO] Kubeconfig missing, fetching from cluster..."

    local master_name="${TF_VAR_cluster_name}-master"
    local cluster_hostname="${K3S_MASTER_HOSTNAME:-k3s-master}"

    echo "[INFO] Pulling kubeconfig from ${master_name} (${cluster_hostname})..."

    create_output_directory "$(dirname "$kubeconfig_path")"

    if ! fetch_kubeconfig_from_cluster "$master_name" "$kubeconfig_path"; then
        echo "[ERROR] Failed to fetch kubeconfig from cluster" >&2
        return 1
    fi

    if ! update_server_hostname "$kubeconfig_path" "$cluster_hostname"; then
        echo "[ERROR] Failed to update kubeconfig hostname" >&2
        return 1
    fi

    echo "[SUCCESS] Kubeconfig saved to ${kubeconfig_path}"
}

main "$@"
