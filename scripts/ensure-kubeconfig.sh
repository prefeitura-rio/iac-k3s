#!/usr/bin/env bash

set -euo pipefail

source "$PWD/scripts/lib/logging.sh"

validate_environment() {
    local errors=0

    if [[ -z "${CLUSTER_NAME:-}" ]]; then
        log_error "CLUSTER_NAME not set"
        errors=1
    fi

    if [[ -z "${KUBECONFIG:-}" ]]; then
        log_error "KUBECONFIG environment variable not set"
        errors=1
    fi

    if [[ $errors -ne 0 ]]; then
        log_error "Make sure environment variables are loaded from .envrc (run 'direnv allow')"
    fi

    return "$errors"
}

file_exists() {
    [[ -f "$1" && -s "$1" ]]
}

retry_incus_command() {
    local incus_command="$*"
    local max_attempts=3
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if timeout 30 bash -c "$incus_command" 2>/dev/null; then
            return 0
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            log_warning "Incus attempt $attempt failed, retrying in 2s..."
            sleep 2
        fi

        ((attempt++))
    done

    log_error "Incus command failed after $max_attempts attempts"
    return 1
}

validate_kubeconfig() {
    local kubeconfig_path="$1"
    local expected_hostname="$2"

    if ! file_exists "$kubeconfig_path"; then
        log_warning "Kubeconfig file is missing or empty"
        return 1
    fi

    log_info "Validating kubeconfig cluster match..."
    local server_url
    server_url=$(KUBECONFIG="$kubeconfig_path" kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null)

    if [[ -z "$server_url" ]]; then
        log_warning "Cannot extract server URL from kubeconfig"
        return 1
    fi

    if [[ "$server_url" != *"$expected_hostname"* ]]; then
        log_warning "Kubeconfig server doesn't match expected hostname ($expected_hostname)"
        return 1
    fi

    log_info "Validating kubeconfig connectivity..."
    if ! KUBECONFIG="$kubeconfig_path" kubectl get nodes >/dev/null 2>&1; then
        log_warning "Kubeconfig cannot connect to cluster"
        return 1
    fi

    log_success "Kubeconfig is valid and functional"
    return 0
}

should_regenerate() {
    local kubeconfig_path="$1"
    local cluster_hostname="$2"
    local force="$3"

    if [[ "$force" == "true" ]]; then
        log_info "Force regeneration requested"
        return 0
    fi

    if ! file_exists "$kubeconfig_path"; then
        log_info "Kubeconfig missing, needs generation"
        return 0
    fi

    if ! validate_kubeconfig "$kubeconfig_path" "$cluster_hostname"; then
        log_info "Kubeconfig invalid, needs regeneration"
        rm -f "$kubeconfig_path"
        return 0
    fi

    return 1
}

fetch_kubeconfig() {
    local master_name="$1"
    local kubeconfig_path="$2"

    if ! retry_incus_command "incus file pull ${master_name}/etc/rancher/k3s/k3s.yaml $kubeconfig_path"; then
        log_error "Failed to fetch kubeconfig from cluster"
        return 1
    fi

    if ! file_exists "$kubeconfig_path"; then
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
        log_warning "Hostname replacement may have failed"
    fi
}

main() {
    local force=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --force|-f) force=true; shift ;;
            *) log_error "Unknown argument: $1"; log_error "Usage: $0 [--force|-f]"; exit 1 ;;
        esac
    done

    validate_environment || exit 1

    local kubeconfig_path="$KUBECONFIG"
    local cluster_hostname="${K3S_MASTER_HOSTNAME:-k3s-master}"
    local master_name="${CLUSTER_NAME}-master"

    if ! should_regenerate "$kubeconfig_path" "$cluster_hostname" "$force"; then
        log_success "Kubeconfig already valid at ${kubeconfig_path#"$PWD/"}"
        return 0
    fi

    log_info "Fetching kubeconfig from ${master_name}..."

    mkdir -p "$(dirname "$kubeconfig_path")"

    if ! fetch_kubeconfig "$master_name" "$kubeconfig_path"; then
        exit 1
    fi

    if ! update_server_hostname "$kubeconfig_path" "$cluster_hostname"; then
        exit 1
    fi

    if ! validate_kubeconfig "$kubeconfig_path" "$cluster_hostname"; then
        log_error "Generated kubeconfig failed validation"
        exit 1
    fi

    log_success "Kubeconfig saved at ${kubeconfig_path}"
}

main "$@"
