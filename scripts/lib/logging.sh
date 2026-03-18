#!/usr/bin/env bash

[[ "${_LOGGING_LOADED:-}" == "1" ]] && return
readonly _LOGGING_LOADED=1

readonly CYAN='\033[36m'
readonly GREEN='\033[32m'
readonly RED='\033[31m'
readonly YELLOW='\033[33m'
readonly RESET='\033[0m'

_colors_supported() {
    [[ "${NO_COLOR:-}" != "1" && "${TERM:-}" != "dumb" && -t 2 ]]
}

log_error() {
    if _colors_supported; then
        echo -e "${RED}[✗] $1${RESET}" >&2
    else
        echo "[✗] $1" >&2
    fi
}

log_warning() {
    if _colors_supported; then
        echo -e "${YELLOW}[⚠] $1${RESET}" >&2
    else
        echo "[⚠] $1" >&2
    fi
}

log_info() {
    if _colors_supported; then
        echo -e "${CYAN}[→] $1${RESET}"
    else
        echo "[→] $1"
    fi
}

log_success() {
    if _colors_supported; then
        echo -e "${GREEN}[✓] $1${RESET}"
    else
        echo "[✓] $1"
    fi
}
