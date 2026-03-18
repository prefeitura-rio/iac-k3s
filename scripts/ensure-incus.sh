#!/usr/bin/env bash

set -euo pipefail

source "$PWD/scripts/lib/logging.sh"

validate_environment() {
    local errors=0

    if [[ -z "${INCUS_TOKEN_FILE:-}" ]]; then
        log_error "INCUS_TOKEN_FILE environment variable not set"
        errors=1
    fi

    if [[ -z "${INCUS_SERVER_HOST:-}" ]]; then
        log_error "INCUS_SERVER_HOST environment variable not set"
        errors=1
    fi

    if [[ -z "${INCUS_SERVER_USER:-}" ]]; then
        log_error "INCUS_SERVER_USER environment variable not set"
        errors=1
    fi

    if [[ $errors -ne 0 ]]; then
        log_error "Make sure environment variables are loaded from .envrc (run 'direnv allow')"
    fi

    return "$errors"
}

get_machine_id() {
    if [[ -f /etc/machine-id && -s /etc/machine-id ]]; then
        cat /etc/machine-id
    elif [[ -f /var/lib/dbus/machine-id && -s /var/lib/dbus/machine-id ]]; then
        cat /var/lib/dbus/machine-id
    else
        log_warning "No machine-id found, using hostname as fallback"
        hostname
    fi
}

generate_client_name() {
    local machine_id="$1"
    local hostname="${HOSTNAME:-$(hostname)}"
    echo "${hostname}-${machine_id:0:8}"
}

validate_token() {
    local token="$1"
    [[ -n "$token" && ${#token} -ge 32 ]]
}

file_exists() {
    [[ -f "$1" && -s "$1" ]]
}

retry_ssh_command() {
    local server_host="$1"
    local ssh_command="$2"
    local max_attempts=3
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        local ssh_output
        local ssh_exit_code

        ssh_output=$(timeout 30 ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$INCUS_SERVER_USER@$server_host" "$ssh_command" 2>&1)
        ssh_exit_code=$?

        if [[ $ssh_exit_code -eq 0 ]]; then
            echo "$ssh_output"
            return 0
        fi

        if echo "$ssh_output" | grep -qi "tailscale ssh requires an additional check\|visit.*login\.tailscale\.com\|authenticate.*tailscale"; then
            log_error "Tailscale SSH authentication required!"
            log_error "Please authenticate by running: tailscale login"
            return 1
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            log_warning "SSH attempt $attempt failed, retrying in 2s..."
            sleep 2
        fi

        ((attempt++))
    done

    log_error "SSH failed after $max_attempts attempts to $server_host"
    return 1
}

check_incus_connection() {
    incus list >/dev/null 2>&1
}

check_machine_trusted() {
    local server_host="$1"
    local machine_id="$2"

    local trust_list
    if ! trust_list=$(retry_ssh_command "$server_host" "incus config trust list --format csv"); then
        log_error "Failed to get trusted clients list from $server_host"
        return 1
    fi

    if ! echo "$trust_list" | grep -q "$machine_id"; then
        log_info "Machine not found in trusted clients list"
        return 1
    fi

    return 0
}

generate_token() {
    local server_host="$1"
    local client_name="$2"
    local token_file="$3"
    local is_trusted="$4"

    if [[ "$is_trusted" == "true" ]]; then
        log_info "Generating token for trusted machine..."
        if ! retry_ssh_command "$server_host" "incus config trust add --name=$client_name --quiet" > "$token_file"; then
            log_error "Failed to generate token via SSH"
            return 1
        fi
    else
        log_info "Creating new client trust: ${client_name}"
        local token_output
        if ! token_output=$(retry_ssh_command "$server_host" "incus config trust add ${client_name}"); then
            log_error "Failed to generate token via SSH"
            return 1
        fi

        local actual_token
        actual_token=$(echo "$token_output" | tail -n 1)

        if ! validate_token "$actual_token"; then
            log_error "Invalid token format received"
            return 1
        fi

        echo "$actual_token" > "$token_file"
    fi

    chmod 600 "$token_file"

    if ! file_exists "$token_file" || ! validate_token "$(cat "$token_file")"; then
        log_error "Failed to save valid token"
        rm -f "$token_file"
        return 1
    fi

    log_success "Token saved to ${token_file}"
}

setup_incus_remote() {
    local server_host="$1"
    local token_file="$2"

    local token
    token=$(cat "$token_file")

    log_info "Adding Incus remote..."
    if incus remote add k3s "${server_host}:8443" --accept-certificate --token="$token" 2>/dev/null; then
        log_success "Remote 'k3s' added successfully"
    else
        log_info "Remote 'k3s' may already exist (this is okay)"
    fi

    incus remote switch k3s
    log_success "Incus client setup complete!"
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

    local token_file="$INCUS_TOKEN_FILE"
    local server_host="$INCUS_SERVER_HOST"

    if file_exists "$token_file" && check_incus_connection && [[ "$force" == "false" ]]; then
        log_success "Incus token and connection already working"
        return 0
    fi

    if [[ "$force" == "true" ]] && file_exists "$token_file"; then
        log_info "Force regenerating existing token..."
        rm -f "$token_file"
    fi

    log_info "Setting up Incus token and connection..."

    local machine_id client_name
    machine_id=$(get_machine_id)
    client_name=$(generate_client_name "$machine_id")

    log_info "Checking if machine ${client_name} is trusted on ${server_host}..."

    local is_trusted=false
    if check_machine_trusted "$server_host" "$machine_id"; then
        is_trusted=true
        log_info "Machine already trusted, generating new token..."
    else
        log_info "Machine not trusted, creating new trust entry..."
    fi

    if ! generate_token "$server_host" "$machine_id" "$token_file" "$is_trusted"; then
        log_error "Failed to generate token"
        exit 1
    fi

    setup_incus_remote "$server_host" "$token_file"
}

main "$@"
