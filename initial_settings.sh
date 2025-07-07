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

is_framework_installed(){
    command -v "$1" &> /dev/null
}

is_package_installed(){
    local pkg_name="$1"
    if [[ "$PKG_MANAGER" == "pacman" ]]; then
        pacman -Q "$pkg_name" &> /dev/null
    elif [[ "$PKG_MANAGER" == "apt" ]]; then
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

    if [[ ${#package_to_install[@]} -gt 0 ]]; then
        $INSTALL_CMD ${package_to_install[@]}
    fi
}
#init variables
USER_NAME=""
USER_EMAIL=""


ZSH_PATH=""
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


echo "This script requires sudo access for package installation."
sudo -v

echo "Configuring Git globally"
git config --global user.name "$USER_NAME"
git config --global user.email "$USER_EMAIL"
git config --global init.defaultBranch main

#install the basic packages need it
install_packages wget curl unzip

if ask_if_install_dep "Do you want to install Zsh and Oh My Zsh?"; then
    install_packages zsh
    if ! is_ohMyZsh_installed; then
        echo "Installing Zsh with Oh My ZSh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
    fi
    ZSH_PATH=$(command -v zsh)
    if ! grep -q "^${ZSH_PATH}$" /etc/shells; then
        echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
    fi
    sudo chsh -s "$ZSH_PATH" "$USER"
    ZSH_INSTALLED=true
else
    echo "Skipping Zsh and Oh My Zsh installation"
fi
if ask_if_install_dep "Do you want to install uv (a fast Python package manager)?"; then
    if ! is_framework_installed uv; then
        curl -LsSf https://astral.sh/uv/install.sh | env INSTALLER_NO_MODIFY_PATH=1 sh
    fi
    UV_INSTALLER_ENV_COMMAND="${HOME}/.local/bin/env"
    UV_APPEND_COMMAND=". \"${UV_INSTALLER_ENV_COMMAND}\""
    if [[ "$ZSH_INSTALLED" == "true" ]] && [[ -f "$UV_INSTALLER_ENV_COMMAND" ]] && ! grep -q "${UV_APPEND_COMMAND}" "${HOME}/.zshrc"; then
        echo  $UV_APPEND_COMMAND>> "${HOME}/.zshrc"
    fi
else
    echo "Skipping uv (python manager based Rust) installation"
fi

if ask_if_install_dep "Do you want to install fnm (a fast Node.js version manager)?"; then
    if ! is_framework_installed fnm; then
        curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
        FNM_INSTALLER_ENV_COMMAND='eval "`fnm env`"'
        if [[ "$ZSH_INSTALLED" == "true" ]] && ! grep -q "${FNM_INSTALLER_ENV_COMMAND}" "${HOME}/.zshrc"; then
            FNM_INSTALL_DIR=$HOME/.local/share/fnm
            {
            echo ''
            echo '# fnm'
            echo 'FNM_PATH="'"$FNM_INSTALL_DIR"'"'
            echo 'if [ -d "$FNM_PATH" ]; then'
            echo '  export PATH="'$FNM_INSTALL_DIR':$PATH"'
            echo "${FNM_INSTALLER_ENV_COMMAND}"
            echo 'fi'
            } >> "${HOME}/.zshrc"
            # echo 'eval "$(fnm env --use-on-cd --shell=zsh)"' >> "${HOME}/.zshrc"
        fi
    fi
else
    echo "Skipping fnm (Node Manager based in Rust) installation"
fi
# C# Installation
# install_packages tar gzip openssl zlib icu

#docker 
if ask_if_install_dep "Do you want to install Docker and Docker-compose?"; then
    install_packages docker docker-compose
    if ! groups "$USER" | grep -q '\bdocker\b'; then
        sudo usermod -aG docker "$USER"
    fi
fi

echo "INFO: You must log out and log back in for Docker group changes to take effect."
echo "All specified setup tasks completed successfully!"
