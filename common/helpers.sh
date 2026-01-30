#!/bin/bash
set -euo pipefail

# --- Logging Functions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# --- Utility Functions ---
command_exists() {
    command -v "$1" &> /dev/null
}

validate_and_get_value() {
    local OPTION_NAME="$1"
    local VALUE_TO_CHECK="$2"
    if [[ -z "$VALUE_TO_CHECK" || "$VALUE_TO_CHECK" == -* ]]; then
        log_error "'$OPTION_NAME' requires a value."
        exit 1
    fi
    echo "$VALUE_TO_CHECK"
}

ask_yes_no() {
    local question="$1"
    local yn=""
    while true; do
        printf "%b%s (y/n): %b" "${YELLOW}" "$question" "${NC}"
        read yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please enter yes or no.";;
        esac
    done
}

# --- Package Management ---
PKG_MANAGER=""
INSTALL_CMD=()

detect_package_manager() {
    log_info "Detecting package manager..."
    if command_exists pacman; then
        PKG_MANAGER="pacman"
        INSTALL_CMD=(sudo pacman -Sy --noconfirm)
        log_success "Detected Arch Linux (pacman)"
    elif command_exists apt-get; then
        PKG_MANAGER="apt"
        INSTALL_CMD=(sudo apt install -y)
        log_success "Detected Debian/Ubuntu (apt)"
    elif command_exists dnf; then
        PKG_MANAGER="dnf"
        INSTALL_CMD=(sudo dnf install -y)
        log_success "Detected Fedora/RHEL (dnf)"
    else
        log_error "Supported package manager (pacman, apt, dnf) not found."
        exit 1
    fi
}

is_package_installed() {
    local pkg_name="$1"
    case "$PKG_MANAGER" in
        pacman) pacman -Q "$pkg_name" &> /dev/null ;;
        apt) dpkg-query -W -f='${Status}' "$pkg_name" 2>/dev/null | grep -q "install ok installed" ;;
        dnf) rpm -q "$pkg_name" &> /dev/null ;;
    esac
}

install_packages() {
    if [[ -z "$PKG_MANAGER" ]]; then
        detect_package_manager
    fi
    
    local packages_to_install=()
    for pkg in "$@"; do
        if is_package_installed "$pkg"; then
            log_info "Package '$pkg' is already installed."
        else
            packages_to_install+=("$pkg")
        fi
    done

    if [[ ${#packages_to_install[@]} -gt 0 ]]; then
        log_info "Installing: ${packages_to_install[*]}"
        "${INSTALL_CMD[@]}" "${packages_to_install[@]}"
    fi
}

# --- Shell Configuration ---
update_shell_config() {
    local config_file="$1"
    local marker_start="# --- ANTIGRAVITY CONFIG START ---"
    local marker_end="# --- ANTIGRAVITY CONFIG END ---"
    local new_content="$2"

    if [[ ! -f "$config_file" ]]; then
        touch "$config_file"
    fi

    # Remove old block if exists and append new one
    if grep -q "$marker_start" "$config_file"; then
        sed -i "/$marker_start/,/$marker_end/d" "$config_file"
    fi

    echo -e "\n$marker_start\n$new_content\n$marker_end" >> "$config_file"
}

is_ohMyZsh_installed() {
    [[ -d "${HOME}/.oh-my-zsh" ]]
}

# --- Node/Tools Management ---
fnm_set_default_fnm_node() {
    fnm default "${1}"
}

ensure_fnm_in_path() {
    if ! command_exists fnm; then
        export PATH="$HOME/.local/share/fnm:$PATH"
    fi
    if command_exists fnm; then
        eval "$(fnm env --use-on-cd)"
    fi
}

setup_fnm_node_pnpm() {
    log_info "Installing/updating fnm..."
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
    
    ensure_fnm_in_path
    
    if command_exists fnm; then
        install_the_lts_fnm_version
        install_pnpm
        
        FNM_CONFIG='export PATH="$HOME/.local/share/fnm:$PATH"
eval "$(fnm env --use-on-cd)"'
        
        if [[ -f "$HOME/.zshrc" ]]; then
            update_shell_config "$HOME/.zshrc" "$FNM_CONFIG"
        fi
        log_success "fnm, Node.js (LTS), and pnpm setup complete."
    else
        log_error "fnm installation failed."
    fi
}

install_the_lts_fnm_version() {
    ensure_fnm_in_path
    if command_exists fnm; then
        log_info "Resolving latest Node.js LTS version..."
        RESOLVE_LTS_TAG=$(fnm list-remote --lts --latest 2>/dev/null | awk '{print $1}' | head -n 1 || echo "")
        if [[ -z "$RESOLVE_LTS_TAG" ]]; then
            log_error "Could not resolve latest Node.js LTS version from fnm."
            exit 1
        fi
        
        log_info "Ensuring Node $RESOLVE_LTS_TAG is installed..."
        if ! fnm ls | grep -q "${RESOLVE_LTS_TAG}"; then
            fnm install "$RESOLVE_LTS_TAG"
        fi
        
        fnm default "$RESOLVE_LTS_TAG"
        eval "$(fnm env --use-on-cd)"
        log_success "Node $RESOLVE_LTS_TAG is now default."
    fi
}

setup_pnpm() {
    local pnpm_setup_output
    local filter_phrase="No changes to the environment were made. Everything is already up to date."
    
    if ! pnpm_setup_output=$(pnpm setup 2>&1); then
        log_error "'pnpm setup' failed."
        echo "$pnpm_setup_output" >&2
        return 1
    fi

    if echo "$pnpm_setup_output" | grep -qF "$filter_phrase"; then
        log_info "pnpm's global setup is already up to date."
    else
        log_warn "pnpm setup modified your environment. Please reload your shell."
    fi
}

install_pnpm() {
    ensure_fnm_in_path
    if command_exists pnpm; then
        setup_pnpm
        return 0
    fi
    if ! command_exists npm; then
        log_error "npm not found. Cannot install pnpm."
        return 1
    fi
    if npm install -g pnpm; then
        setup_pnpm
        log_success "Successfully installed pnpm"
    else
        log_error "Failed to install pnpm"
        return 1
    fi
}
