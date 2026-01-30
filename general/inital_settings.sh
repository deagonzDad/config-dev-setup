#!/bin/bash
# -e: exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error when substituting.
# -o pipefail: The return value of a pipeline is the status of the last command.
set -euo pipefail

# Source helpers
# Determine the script's directory in a way that works for both Bash and Zsh
if [ -n "${BASH_VERSION:-}" ]; then
    SCRIPT_PATH="${BASH_SOURCE[0]:-}"
elif [ -n "${ZSH_VERSION:-}" ]; then
    # In Zsh, (%):-%x gives the active script path
    SCRIPT_PATH="${(%):-%x}"
else
    SCRIPT_PATH="$0"
fi

SCRIPT_DIR="$( cd "$( dirname "$SCRIPT_PATH" )" && pwd )"
HELPERS_PATH="${SCRIPT_DIR}/../common/helpers.sh"

if [[ -f "$HELPERS_PATH" ]]; then
    . "$HELPERS_PATH"
else
    # Fallback to current dir if the above fails (e.g. if script is sourced or moved)
    if [[ -f "${PWD}/common/helpers.sh" ]]; then
        . "${PWD}/common/helpers.sh"
    else
        echo "Error: helpers.sh not found at $HELPERS_PATH" >&2
        exit 1
    fi
fi

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

# --- Node/pnpm Management ---
if ask_yes_no "Do you want to install/update fnm, Node.js (LTS), and pnpm?"; then
    setup_fnm_node_pnpm
fi

# --- Optional Tools ---
if ask_yes_no "Do you want to install Gemini CLI?"; then
    log_info "Installing gemini-cli..."
    if command_exists pnpm; then
        if pnpm install -g @google/gemini-cli; then
            log_success "Successfully installed gemini-cli"
        else
            log_error "Failed to install gemini-cli"
        fi
    # elif command_exists npm; then
    #      if npm install -g @google/gemini-cli; then
    #         log_success "Successfully installed gemini-cli"
    #     else
    #         log_error "Failed to install gemini-cli"
    #     fi
    else
        log_error "Neither pnpm nor npm found. Cannot install Gemini CLI."
    fi
fi

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
