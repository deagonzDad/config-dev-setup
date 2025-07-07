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