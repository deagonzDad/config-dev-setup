#!/bin/bash
 set -euo pipefail

 command_exists(){
     command -v "$1" &> /dev/null
 }

 ask_yes_no(){
    local question="$1"
    while true; do
        read -p "$question (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please enter yes or no.";;
        esac
    done
 }

 PKG_MANAGER=""
 INSTALL_CMD=""

 detect_package_manager() {
    if command_exists pacman; then
        PKG_MANAGER="pacman"
        INSTALL_CMD="sudo pacman -S --noconfirm"
    elif command_exists apt-get; then
        PKG_MANAGER="apt"
        INSTALL_CMD="sudo apt install -y"
    else
        exit 1
    fi
 }

 install_packages(){
    if [[ -z "$PKG_MANAGER" ]]; then
        echo "Package manager not detected, Call detect_package_manager()"
        exit 1
    fi
    echo "Installing packages: $* using $PKG_MANAGER..."
    $INSTALL_CMD "$@"
}

is_ohMyZsh_installed() {
    [[ -d "${HOME}/.oh-my-zsh" ]]
}


detect_current_shell_type() {
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        echo "Detected Zsh"
    elif [[ -n "${BASH_VERSION:-}" ]]; then
        echo "Detected Bash"
    else
        echo "Unknown shell"
        exit 1
    fi
}

fnm_set_default_fnm_node() {
    fnm default "${1}"
}
install_the_lts_fnm_version() {
    if command_exists fnm; then
        RESOLVE_LTS_TAG=$(fnm list-remote --lts --latest 2>/dev/null | awk '{print $1}' | head -n 1 || echo "")
        if [[ -z "$RESOLVE_LTS_TAG" ]]; then
            echo "Error Could not resolve latest Node.js LTS version FnM. Cannot proceed with Node.js setup." >&2
            exit 1
        fi
        
        if fnm ls | grep -q "${RESOLVE_LTS_TAG}"; then
            fnm_set_default_fnm_node "$RESOLVE_LTS_TAG"
        else
            fnm install --lts
            fnm_set_default_fnm_node "$RESOLVE_LTS_TAG"
        fi  
    fi
}

setup_pnpm() {
    local pnpm_setup_output
    local pnpm_setup_exit_status
    local filter_phrase="No changes to the environment were made. Everything is already up to date."
    
    if ! pnpm_setup_output=$(pnpm setup 2>&1); then
        pnpm_setup_exit_status=$?
        echo "Error: 'pnpm setup' failed. Exit status: $pnpm_setup_exit_status" >&2
        echo "Output from 'pnpm setup':" >&2
        echo "$pnpm_setup_output" >&2
        echo "You may need to configure pnpm's global bin directory manually." >&2
        exit 1
    fi

    if echo "$pnpm_setup_output" | grep -qF "$filter_phrase"; then
        echo "pnpm's global setup is already up to date. No changes were made."
        return 0
    else
        echo "Error: 'pnpm setup' failed after pnpm installation. You may need to configure pnpm's global bin directory manually." >&2
        echo "$pnpm_setup_output"
        echo "Please reload your zsh or bash to load the PATH"
        exit
    fi
}

install_pnpm() {
    if command_exists pnpm; then
        setup_pnpm
        return 0
    fi
    if ! command_exists npm; then
        exit 1
    fi
    if npm install -g pnpm; then
        setup_pnpm
        echo "Successfully installed pnpm"
    else
        echo "Failed to install pnpm"
        exit 1
    fi
}
