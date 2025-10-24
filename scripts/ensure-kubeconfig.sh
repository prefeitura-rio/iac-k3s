#!/usr/bin/env bash

set -euo pipefail

source "$PWD/scripts/lib/common.sh"
source "$PWD/scripts/lib/kubeconfig.sh"

check_existing_kubeconfig() {
    local kubeconfig_path="$1"
    check_file_exists "$kubeconfig_path"
}

validate_environment() {
    if [[ -z "${TF_VAR_cluster_name:-}" ]]; then
        log_error "TF_VAR_cluster_name not set"
        print_env_missing_error
        return 1
    fi

    if [[ -z "$KUBECONFIG" ]]; then
        log_error "KUBECONFIG environment variable not set"
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
        log_error "Failed to fetch kubeconfig from cluster after multiple attempts"
        return 1
    fi

    if [[ ! -f "$kubeconfig_path" || ! -s "$kubeconfig_path" ]]; then
        log_error "Kubeconfig file is missing or empty after fetch"
        return 1
    fi
}

update_server_hostname() {
    local kubeconfig_path="$1"
    local cluster_hostname="$2"

    if ! sed -i "s|127.0.0.1|${cluster_hostname}|g" "$kubeconfig_path"; then
        log_error "Failed to update server hostname in kubeconfig"
        return 1
    fi

    if ! grep -q "$cluster_hostname" "$kubeconfig_path"; then
        log_warning "Hostname replacement may have failed - $cluster_hostname not found in kubeconfig"
    fi
}

main() {
    local force_regenerate=false
    local remaining_args

    remaining_args=$(parse_force_flag force_regenerate "$@")

    if [[ -n "$remaining_args" ]]; then
        log_error "Unknown argument: $remaining_args"
        log_error "Usage: $0 [--force|-f]"
        exit 1
    fi

    validate_environment || exit 1

    local kubeconfig_path="$KUBECONFIG"

    local cluster_hostname="${K3S_MASTER_HOSTNAME:-k3s-master}"

    if ! should_regenerate_kubeconfig "$kubeconfig_path" "$cluster_hostname" "$force_regenerate"; then
        log_success "Kubeconfig already exists and is valid at ${kubeconfig_path#"$PWD/"}"
        return 0
    fi

    log_info "Kubeconfig missing or invalid, fetching from cluster..."

    local master_name="${TF_VAR_cluster_name}-master"

    log_info "Pulling kubeconfig from ${master_name} (${cluster_hostname})..."

    create_output_directory "$(dirname "$kubeconfig_path")"

    if ! fetch_kubeconfig_from_cluster "$master_name" "$kubeconfig_path"; then
        log_error "Failed to fetch kubeconfig from cluster"
        return 1
    fi

    if ! update_server_hostname "$kubeconfig_path" "$cluster_hostname"; then
        log_error "Failed to update kubeconfig hostname"
        return 1
    fi

    if ! validate_existing_kubeconfig "$kubeconfig_path" "$cluster_hostname"; then
        log_error "Generated kubeconfig failed validation"
        return 1
    fi

    log_success "Kubeconfig saved and validated at ${kubeconfig_path}"
}

main "$@"
