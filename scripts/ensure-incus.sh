#!/usr/bin/env bash

set -euo pipefail

source "$PWD/scripts/lib/common.sh"

check_existing_token() {
    local token_file="$1"
    check_file_exists "$token_file"
}

check_incus_connection() {
    incus list >/dev/null 2>&1
}

check_machine_trusted() {
    local server_host="$1"
    local machine_id="$2"

    local trust_list

    if ! trust_list=$(retry_ssh_command "$server_host" "incus config trust list --format csv"); then
        echo "[ERROR] Failed to get trusted clients list from $server_host" >&2
        return 1
    fi

    if ! echo "$trust_list" | grep -q "$machine_id"; then
        local client_name
        client_name=$(generate_client_name "$machine_id")

        echo "[INFO] Machine ${client_name} not found in trusted clients list"
        return 1
    fi

    return 0
}

generate_token_for_trusted_machine() {
    local server_host="$1"
    local machine_id="$2"
    local token_file="$3"

    echo "[INFO] Generating token for trusted machine..."

    if ! retry_ssh_command "$server_host" "incus config trust add --name=$machine_id --quiet" > "$token_file"; then
        echo "[ERROR] Failed to generate token via SSH to ${server_host}" >&2
        echo "[ERROR] Check that Tailscale SSH is working and user has incus access" >&2
        return 1
    fi
}

generate_token_for_new_machine() {
    local server_host="$1"
    local client_name="$2"
    local token_file="$3"

    echo "[INFO] Creating new client trust: ${client_name}"
    
    local token_output
    if ! token_output=$(retry_ssh_command "$server_host" "incus config trust add ${client_name}"); then
        echo "[ERROR] Failed to generate token via SSH to ${server_host}" >&2
        return 1
    fi

    local actual_token
    actual_token=$(echo "$token_output" | tail -n 1)

    if ! validate_token "$actual_token"; then
        echo "[ERROR] Invalid token format received" >&2
        return 1
    fi

    echo "$actual_token" > "$token_file"
    chmod 600 "$token_file"
}

validate_token_file() {
    local token_file="$1"

    if [[ -f "$token_file" && -s "$token_file" ]]; then
        local token
        token=$(cat "$token_file")

        if validate_token "$token"; then
            echo "[SUCCESS] Token saved to ${token_file}"
            return 0
        else
            echo "[ERROR] Invalid token format in ${token_file}" >&2
            rm -f "$token_file"
            return 1
        fi
    else
        echo "[ERROR] Failed to create token file" >&2
        return 1
    fi
}

add_incus_remote() {
    local server_host="$1"
    local token="$2"
    
    echo "[INFO] Adding Incus remote..."
    
    if incus remote add k3s "${server_host}:8443" --accept-certificate --token="$token" 2>/dev/null; then
        echo "[SUCCESS] Remote 'k3s' added successfully"
    else
        echo "[INFO] Remote 'k3s' may already exist (this is okay)"
    fi
}

switch_to_remote() {
    incus remote switch k3s
}

setup_incus_connection() {
    local server_host="$1"
    local token_file="$2"
    
    local token
    token=$(cat "$token_file")
    
    add_incus_remote "$server_host" "$token"
    switch_to_remote
    
    echo "[SUCCESS] Incus client setup complete!"
    echo "[INFO] You can now use: incus list"
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

    validate_incus_environment || exit 1

    local token_file="$INCUS_TOKEN_FILE"
    local server_host="$INCUS_SERVER_HOST"

    # Check if we already have a working connection
    if check_existing_token "$token_file" && check_incus_connection && [[ "$force_regenerate" == "false" ]]; then
        echo "[SUCCESS] Incus token and connection already working"
        return 0
    fi

    # Force regenerate if requested
    if [[ "$force_regenerate" == "true" ]] && check_existing_token "$token_file"; then
        echo "[INFO] Force regenerating existing token..."
        rm -f "$token_file"
    fi

    echo "[INFO] Setting up Incus token and connection..."

    local machine_id
    machine_id=$(get_machine_id)

    local client_name
    client_name=$(generate_client_name "$machine_id")

    echo "Checking if machine ${client_name} is already trusted on ${server_host}..."

    if check_machine_trusted "$server_host" "$machine_id"; then
        echo "[INFO] Machine ${client_name} already trusted, generating new token..."
        if generate_token_for_trusted_machine "$server_host" "$machine_id" "$token_file" && validate_token_file "$token_file"; then
            setup_incus_connection "$server_host" "$token_file"
        else
            echo "[ERROR] Failed to generate or validate token for trusted machine" >&2
            exit 1
        fi
    else
        echo "[INFO] Machine ${client_name} not trusted, creating new trust entry..."
        if generate_token_for_new_machine "$server_host" "$client_name" "$token_file" && validate_token_file "$token_file"; then
            setup_incus_connection "$server_host" "$token_file"  
        else
            echo "[ERROR] Failed to generate or validate token for new machine" >&2
            exit 1
        fi
    fi
}

main "$@"