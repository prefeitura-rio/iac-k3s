#!/usr/bin/env bash

get_machine_id() {
    if [[ -f /etc/machine-id && -s /etc/machine-id ]]; then
        cat /etc/machine-id
    elif [[ -f /var/lib/dbus/machine-id && -s /var/lib/dbus/machine-id ]]; then
        cat /var/lib/dbus/machine-id
    else
        echo "[WARNING] No machine-id found, using hostname as fallback" >&2
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

    if [[ -z "$token" || ${#token} -lt 32 ]]; then
        return 1
    fi

    return 0
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
            echo "[ERROR] Tailscale SSH authentication required!" >&2
            echo "[ERROR] Please authenticate by running: tailscale login" >&2
            echo "[ERROR] Or visit the authentication URL shown above" >&2
            return 1
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            echo "[WARNING] SSH command attempt $attempt failed, retrying in 2 seconds..." >&2
            sleep 2
        fi

        ((attempt++))
    done

    echo "[ERROR] SSH failed after $max_attempts attempts to $server_host" >&2
    return 1
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
            echo "[WARNING] Incus command attempt $attempt failed, retrying in 2 seconds..." >&2
            sleep 2
        fi

        ((attempt++))
    done

    echo "[ERROR] Incus command failed after $max_attempts attempts: $incus_command" >&2
    return 1
}

parse_force_flag() {
    local -n force_var="$1"
    shift

    while [[ $# -gt 0 ]]; do
        case $1 in
            --force|-f)
                force_var=true
                shift
                ;;
            *)
                echo "$1"
                shift
                ;;
        esac
    done
}

check_file_exists() {
    local file_path="$1"
    [[ -f "$file_path" && -s "$file_path" ]]
}

print_env_missing_error() {
    echo "[ERROR] Make sure environment variables are loaded from .envrc (run 'direnv allow')" >&2
}

validate_incus_environment() {
    local errors=0

    if [[ -z "${INCUS_TOKEN_FILE:-}" ]]; then
        echo "[ERROR] INCUS_TOKEN_FILE environment variable not set" >&2
        print_env_missing_error
        errors=1
    fi

    if [[ -z "${INCUS_SERVER_HOST:-}" ]]; then
        echo "[ERROR] INCUS_SERVER_HOST environment variable not set" >&2
        print_env_missing_error
        errors=1
    fi

    if [[ -z "${INCUS_SERVER_USER:-}" ]]; then
        echo "[ERROR] INCUS_SERVER_USER environment variable not set" >&2
        print_env_missing_error
        errors=1
    fi

    return "$errors"
}