#!/usr/bin/env bash

source "$PWD/scripts/lib/logging.sh"

validate_kubeconfig_connectivity() {
    local kubeconfig_path="$1"

    log_info "Validating kubeconfig connectivity..."

    if ! KUBECONFIG="$kubeconfig_path" kubectl get nodes >/dev/null 2>&1; then
        log_warning "Kubeconfig cannot connect to cluster or cluster is unreachable"
        return 1
    fi

    log_info "Kubeconfig connectivity validated successfully"
    return 0
}

validate_kubeconfig_cluster_match() {
    local kubeconfig_path="$1"
    local expected_hostname="$2"

    log_info "Validating kubeconfig cluster match..."

    local server_url
    server_url=$(KUBECONFIG="$kubeconfig_path" kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null)

    if [[ -z "$server_url" ]]; then
        log_warning "Cannot extract server URL from kubeconfig"
        return 1
    fi

    if [[ "$server_url" != *"$expected_hostname"* ]]; then
        log_warning "Kubeconfig server ($server_url) doesn't match expected cluster hostname ($expected_hostname)"
        return 1
    fi

    log_info "Kubeconfig cluster match validated successfully"
    return 0
}

validate_existing_kubeconfig() {
    local kubeconfig_path="$1"
    local cluster_hostname="${2:-}"

    if [[ ! -f "$kubeconfig_path" || ! -s "$kubeconfig_path" ]]; then
        log_warning "Kubeconfig file is missing or empty"
        return 1
    fi

    if [[ -n "$cluster_hostname" ]] && ! validate_kubeconfig_cluster_match "$kubeconfig_path" "$cluster_hostname"; then
        return 1
    fi

    if ! validate_kubeconfig_connectivity "$kubeconfig_path"; then
        return 1
    fi

    log_success "Existing kubeconfig is valid and functional"
    return 0
}

should_regenerate_kubeconfig() {
    local kubeconfig_path="$1"
    local cluster_hostname="${2:-}"
    local force_regenerate="${3:-false}"

    if [[ "$force_regenerate" == "true" ]]; then
        log_info "Force regeneration requested"
        return 0
    fi

    if ! check_file_exists "$kubeconfig_path"; then
        log_info "Kubeconfig missing, needs generation"
        return 0
    fi

    if ! validate_existing_kubeconfig "$kubeconfig_path" "$cluster_hostname"; then
        log_info "Existing kubeconfig is invalid, needs regeneration"
        rm -f "$kubeconfig_path"
        log_info "Removed invalid kubeconfig file"
        return 0
    fi

    return 1
}
