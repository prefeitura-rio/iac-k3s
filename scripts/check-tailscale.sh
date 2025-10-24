#!/usr/bin/env bash

set -euo pipefail

source "$PWD/scripts/lib/logging.sh"

check_tailscale_installed() {
    if ! command -v tailscale >/dev/null 2>&1; then
        log_error "Tailscale is not installed or not in PATH"
        log_info "Install Tailscale from: https://tailscale.com/download"
        return 1
    fi
}

check_tailscale_running() {
    if ! tailscale status >/dev/null 2>&1; then
        log_error "Tailscale is not running or not authenticated"
        log_info "Run 'tailscale up' to connect to your network"
        return 1
    fi
}

get_current_tailnet() {
    tailscale status --json 2>/dev/null | jq -r '.CurrentTailnet.Name // empty' 2>/dev/null || echo ""
}

get_current_domain() {
    tailscale status --json 2>/dev/null | jq -r '.CurrentTailnet.MagicDNSSuffix // empty' 2>/dev/null || echo ""
}

validate_tailscale_network() {
    local expected_tailnet="${TAILSCALE_TAILNET:-}"
    local expected_domain="${TAILSCALE_DOMAIN:-}"

    if [[ -z "$expected_tailnet" && -z "$expected_domain" ]]; then
        log_info "No Tailscale network validation configured (TAILSCALE_TAILNET/TAILSCALE_DOMAIN not set)"
        return 1
    fi

    local current_tailnet
    local current_domain

    current_tailnet=$(get_current_tailnet)
    current_domain=$(get_current_domain)

    if [[ -n "$expected_tailnet" && "$current_tailnet" != "$expected_tailnet" ]]; then
        log_error "Connected to wrong Tailscale network"
        log_error "Expected: $expected_tailnet"
        log_error "Current:  $current_tailnet"
        return 1
    fi

    if [[ -n "$expected_domain" && "$current_domain" != "$expected_domain" ]]; then
        log_error "Connected to wrong Tailscale domain"
        log_error "Expected: $expected_domain"
        log_error "Current:  $current_domain"
        return 1
    fi

    if [[ -n "$expected_tailnet" ]]; then
        log_success "Connected to correct Tailscale network: $current_tailnet"
    fi

    if [[ -n "$expected_domain" ]]; then
        log_success "Connected to correct Tailscale domain: $current_domain"
    fi
}

main() {
    log_info "Checking Tailscale connectivity..."

    if ! check_tailscale_installed; then
        exit 1
    fi

    if ! check_tailscale_running; then
        exit 1
    fi

    if ! validate_tailscale_network; then
        exit 1
    fi

    log_success "Tailscale connectivity validated"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
