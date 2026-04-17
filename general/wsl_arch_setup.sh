#!/bin/bash
set -euo pipefail

# Source helpers
if [ -n "${BASH_VERSION:-}" ]; then
    SCRIPT_PATH="${BASH_SOURCE[0]:-}"
elif [ -n "${ZSH_VERSION:-}" ]; then
    SCRIPT_PATH="${(%):-%x}"
else
    SCRIPT_PATH="$0"
fi

SCRIPT_DIR="$( cd "$( dirname "$SCRIPT_PATH" )" && pwd )"
HELPERS_PATH="${SCRIPT_DIR}/../common/helpers.sh"

if [[ -f "$HELPERS_PATH" ]]; then
    . "$HELPERS_PATH"
else
    echo "Error: helpers.sh not found at $HELPERS_PATH" >&2
    exit 1
fi

detect_package_manager
sudo -v

# 1. System Foundation & Identity
if is_wsl; then
    log_info "Configuring WSL foundations..."
    # visudo wheel configuration is manual or needs sudo sed
    if ask_yes_no "Do you want to enable wheel group in visudo (requires root)?"; then
        sudo sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers || log_warn "Failed to update visudo. Please do it manually."
    fi

    log_info "Configuring /etc/wsl.conf..."
    cat <<EOF | sudo tee /etc/wsl.conf > /dev/null
[boot]
systemd=true
[user]
default=$USER
EOF

    log_info "Fixing locales..."
    if [[ -f "/etc/locale.gen" ]]; then
        sudo sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
        sudo locale-gen
    fi
    echo "LANG=en_US.UTF-8" | sudo tee /etc/locale.conf > /dev/null
fi

log_info "Setting up project directory structure..."
mkdir -p "$HOME/projects/personal"
mkdir -p "$HOME/projects/work"

# 2. Multi-Account SSH Workflow
if ask_yes_no "Do you want to setup multi-account SSH keys?"; then
    setup_ssh_identities "personal"
    setup_ssh_identities "work"

    log_info "Creating ~/.ssh/config..."
    mkdir -p "$HOME/.ssh"
    cat > "$HOME/.ssh/config" <<EOF
Host github.com-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes

Host github.com-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_work
    IdentitiesOnly yes
EOF
    chmod 600 "$HOME/.ssh/config"
fi

# 3. Docker Rootless
if ask_yes_no "Do you want to setup Docker Rootless?"; then
    setup_docker_rootless
fi

# 4. .zshrc Updates
ZSH_CONFIG_BLOCK='
# Docker Rootless
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
if command -v docker >/dev/null 2>&1; then
    docker context use rootless >/dev/null 2>&1
fi

# fnm automation
if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --use-on-cd --shell zsh)"
fi

# Starship Prompt
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi
'

if [[ -f "$HOME/.zshrc" ]]; then
    update_shell_config "$HOME/.zshrc" "$ZSH_CONFIG_BLOCK"
    log_success ".zshrc updated with Docker and tool automations."
fi

# 5. Global Security Hardening
if ask_yes_no "Apply security hardening (disable npm/pnpm scripts globally)?"; then
    if command_exists npm; then
        npm config set ignore-scripts true --global
        log_success "npm global ignore-scripts enabled."
    fi
    if command_exists pnpm; then
        pnpm config set ignore-scripts true --global
        log_success "pnpm global ignore-scripts enabled."
    fi
fi

log_success "WSL/Arch setup complete!"
