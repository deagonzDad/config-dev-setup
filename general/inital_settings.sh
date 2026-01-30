#!/bin/bash

# -e: exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error when substituting.
# -o pipefail: The return value of a pipeline is the status of the last command.
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
validate_and_get_value() {
    local OPTION_NAME="$1"
    local VALUE_TO_CHECK="$2"
    if [[ -z "$VALUE_TO_CHECK" || "$VALUE_TO_CHECK" == -* ]]; then
        log_error "'$OPTION_NAME' requires a value."
        echo "Usage: $0 --name <name> --email <email>" >&2
        exit 1
    fi
    echo "$VALUE_TO_CHECK"
}

ask_yes_no() {
    local question="$1"
    local yn=""
    while true; do
        printf "%b%s (y/n): %b" "${YELLOW}" "$question" "${NC}"
        # Use read without -p for portability between bash and zsh
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

is_framework_installed(){
    command -v "$1" &> /dev/null
}

is_package_installed() {
    local pkg_name="$1"
    case "$PKG_MANAGER" in
        pacman) pacman -Q "$pkg_name" &> /dev/null ;;
        apt) dpkg-query -W -f='${Status}' "$pkg_name" 2>/dev/null | grep -q "install ok installed" ;;
        dnf) rpm -q "$pkg_name" &> /dev/null ;;
    esac
}

is_ohMyZsh_installed() {
    [[ -d "${HOME}/.oh-my-zsh" ]]
}

detect_package_manager() {
    log_info "Detecting package manager..."
    if command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
        INSTALL_CMD=(sudo pacman -Sy --noconfirm)
        log_success "Detected Arch Linux (pacman)"
    elif command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
        INSTALL_CMD=(sudo apt install -y)
        log_success "Detected Debian/Ubuntu (apt)"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        INSTALL_CMD=(sudo dnf install -y)
        log_success "Detected Fedora/RHEL (dnf)"
    else
        log_error "Supported package manager (pacman, apt, dnf) not found."
        exit 1
    fi
}


install_packages() {
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

# --- Main Logic ---

# Init variables
USER_NAME=""
USER_EMAIL=""

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --name)  USER_NAME=$(validate_and_get_value "--name" "$2"); shift ;;
        --email) USER_EMAIL=$(validate_and_get_value "--email" "$2"); shift ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

detect_package_manager
sudo -v

# --- Git Configuration ---
if [[ -z "$USER_NAME" ]]; then
    USER_NAME=$(git config --global user.name || echo "")
    if [[ -z "$USER_NAME" ]]; then
        printf "Enter your Git name: "
        read USER_NAME
    fi
fi

if [[ -z "$USER_EMAIL" ]]; then
    USER_EMAIL=$(git config --global user.email || echo "")
    if [[ -z "$USER_EMAIL" ]]; then
        printf "Enter your Git email: "
        read USER_EMAIL
    fi
fi

log_info "Configuring Git globally..."
git config --global user.name "$USER_NAME"
git config --global user.email "$USER_EMAIL"
git config --global init.defaultBranch main
log_success "Git configured for $USER_NAME <$USER_EMAIL>"

# --- Basic Tools ---
install_packages wget curl unzip git vim tmux htop

# --- Zsh & Oh My Zsh ---
if ask_yes_no "Do you want to install Zsh and Oh My Zsh?"; then
    install_packages zsh
    if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
        log_info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
    fi

    # Plugins
    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]] && git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]] && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

    ZSH_PATH=$(command -v zsh)
    if ! grep -q "^${ZSH_PATH}$" /etc/shells; then
        echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
    fi
    sudo chsh -s "$ZSH_PATH" "$USER"
    log_success "Zsh configured. Please reload your shell after the script finishes."
fi

# --- uv (Python Manager) ---
if ask_yes_no "Do you want to install/update uv (Fast Python manager)?"; then
    log_info "Installing/updating uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    log_success "uv installation/update complete."
fi

# --- fnm (Node Manager) ---
if ask_yes_no "Do you want to install/update fnm (Fast Node manager)?"; then
    log_info "Installing/updating fnm..."
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
    
    FNM_CONFIG='export PATH="$HOME/.local/share/fnm:$PATH"
eval "$(fnm env --use-on-cd)"'
    
    if [[ -f "$HOME/.zshrc" ]]; then
        update_shell_config "$HOME/.zshrc" "$FNM_CONFIG"
    fi
    log_success "fnm installation/update complete."
fi

# --- Optional Tools ---
if ask_yes_no "Do you want to install Neovim?"; then
    install_packages neovim
fi

if ask_yes_no "Do you want to install Docker and Docker Compose (v2)?"; then
    if [[ "$PKG_MANAGER" == "apt" || "$PKG_MANAGER" == "dnf" ]]; then
        install_packages docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    else
        # Arch usually bundles v2 in docker-compose or just 'docker'
        install_packages docker docker-compose
    fi

    if ! groups "$USER" | grep -q '\bdocker\b'; then
        sudo usermod -aG docker "$USER"
        log_warn "Added $USER to docker group. You need to logout/login."
    fi
    
    # Start docker if not running
    sudo systemctl enable --now docker || true
fi

# --- Final Summary ---
echo -e "\n${BLUE}--- Version Summary ---${NC}"
command -v git &>/dev/null && echo "Git: $(git --version)" || true
command -v uv &>/dev/null && echo "uv: $(uv --version)" || true
command -v fnm &>/dev/null && echo "fnm: $(fnm --version)" || true
command -v docker &>/dev/null && echo "Docker: $(docker --version)" || true
if command -v docker &>/dev/null && docker compose version &>/dev/null; then
    echo "Docker Compose: $(docker compose version)"
elif command -v docker-compose &>/dev/null; then
    echo "Docker Compose: $(docker-compose --version)"
fi
command -v nvim &>/dev/null && echo "Neovim: $(nvim --version | head -n 1)" || true

log_success "All specified setup tasks completed successfully!"
