#!/usr/bin/env bash

[[ "${_LOGGING_LOADED:-}" == "1" ]] && return
readonly _LOGGING_LOADED=1

declare -A COLORS=(
    [RED]='\033[38;5;196m'
    [YELLOW]='\033[38;5;220m'
    [GREEN]='\033[38;5;46m'
    [BLUE]='\033[38;5;39m'
    [GRAY]='\033[38;5;240m'
    [BOLD]='\033[1m'
    [RESET]='\033[0m'
)

detect_color_support() {
    [[ "${NO_COLOR:-}" == "1" ]] && return 1
    [[ "${TERM:-}" == "dumb" ]] && return 1

    [[ -t 2 ]] && [[ "${TERM:-}" != "" ]] && return 0

    return 1
}

_COLORS_ENABLED=false
if detect_color_support; then
    _COLORS_ENABLED=true
fi

log_error() {
    local message="$1"
    if [[ "$_COLORS_ENABLED" == "true" ]]; then
        echo -e "${COLORS[RED]}${COLORS[BOLD]}[ERROR]${COLORS[RESET]} ${message}" >&2
    else
        echo "[ERROR] ${message}" >&2
    fi
}

log_warning() {
    local message="$1"
    if [[ "$_COLORS_ENABLED" == "true" ]]; then
        echo -e "${COLORS[YELLOW]}${COLORS[BOLD]}[WARNING]${COLORS[RESET]} ${message}" >&2
    else
        echo "[WARNING] ${message}" >&2
    fi
}

log_info() {
    local message="$1"
    if [[ "$_COLORS_ENABLED" == "true" ]]; then
        echo -e "${COLORS[BLUE]}${COLORS[BOLD]}[INFO]${COLORS[RESET]} ${message}"
    else
        echo "[INFO] ${message}"
    fi
}

log_success() {
    local message="$1"
    if [[ "$_COLORS_ENABLED" == "true" ]]; then
        echo -e "${COLORS[GREEN]}${COLORS[BOLD]}[SUCCESS]${COLORS[RESET]} ${message}"
    else
        echo "[SUCCESS] ${message}"
    fi
}

log_debug() {
    local message="$1"
    [[ "${DEBUG:-}" != "1" ]] && return

    if [[ "$_COLORS_ENABLED" == "true" ]]; then
        echo -e "${COLORS[GRAY]}[DEBUG]${COLORS[RESET]} ${message}" >&2
    else
        echo "[DEBUG] ${message}" >&2
    fi
}
