#!/bin/bash

# -e: exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error when substituting.
# -o pipefail: The return value of a pipeline is the status of the last command.

set -euo pipefail

validate_and_get_value(){
    local OPTION_NAME="$1"
    local VALUE_TO_CHECK="$2"
    if [[ -z "$VALUE_TO_CHECK" || "$VALUE_TO_CHECK" == -* ]]; then
        echo "Error: '$OPTION_NAME' require a value.">&2
        echo "Usage: $0 --name <name> --email <email>" >&2
        exit 1
    fi
    echo "$VALUE_TO_CHECK"
}

ask_if_install_dep(){
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

is_package_installed(){
    local pkg_name="$1"
    if [ "$PKG_MANAGER" = "pacman" ]; then
        pacman -Q "$pkg_name" &> /dev/null
    elif [ "$PKG_MANAGER" = "apt" ]; then
        dpkg-query -W -f='${Status}' "$pkg_name" 2>/dev/null | grep -q "install ok installed"
    fi
}
is_ohMyZsh_installed() {
    [[ -d "${HOME}/.oh-my-zsh" ]]
}
detect_package_manager() {
    echo "Detecting package manager..."
    if command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
        INSTALL_CMD="sudo pacman -S --noconfirm"
        echo "Detected Arch Linux (pacman)"
    elif command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
        INSTALL_CMD="sudo apt install -y"
        echo "Detected Debian/Ubuntu (apt)"
    else
        echo "Error: No support package manager(pacman, apt) found"
        exit 1
    fi
}

install_packages(){
    local package_to_install=()
    for pkg in "$@"; do
        if is_package_installed "$pkg"; then
            echo "Package '$pkg' is already installed."
        else
            package_to_install+=("$pkg")
        fi
    done

    if [[ ${#package_to_install[@]} -gt 0]]; then
        $INSTALL_CMD ${package_to_install[@]}
    fi
}
#init variables
USER_NAME=""
USER_EMAIL=""

ZSH_INSTALLED=false


# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
case "$1" in
    --name)
        USER_NAME=$(validate_and_get_value "--name" "$2")
        shift
        ;;
    --email)
        USER_EMAIL=$(validate_and_get_value "--email" "$2")
        shift
        ;;
    *)
        echo "Error: Unknown option: $1" >&2
        echo "Usage: $0 --name <name> --email <email>" >&2
        exit 1
        ;;
    esac
    shift
done

detect_package_manager

echo "Configuring Git globally"
git config --global user.name "$USER_NAME"
git config --global user.email "$USER_EMAIL"
git config --global init.defaultBranch main

#install the basic packages need it
install_packages wget curl

if ask_if_install_dep "Do you want to install Zsh and Oh My Zsh?"; then
    if ! is_ohMyZsh_installed; then
        echo "Installing Zsh with Oh My ZSh..."
        install_packages zsh
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
        chsh -s "$(command -v zsh)" "$USER"
    fi
    ZSH_INSTALLED=true
else
    echo "Skipping Zsh and Oh My Zsh installation"
fi

echo "All specified setup tasks completed successfully!"
