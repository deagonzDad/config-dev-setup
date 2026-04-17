# Manual Installation Guide: Arch Linux WSL2 (Rootless & Protected)

This guide provides a step-by-step command-line walkthrough to manually replicate the environment configuration.

## 1. System Foundation & Identity

### Elevated Permissions
Allow the `wheel` group to use sudo:
```bash
sudo sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
```

### WSL Configuration
Enable systemd and set your default user:
```bash
cat <<EOF | sudo tee /etc/wsl.conf
[boot]
systemd=true
[user]
default=$(whoami)
EOF
```

### Locale Generation
Fix Perl/Locale warnings:
```bash
sudo sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sudo locale-gen
echo "LANG=en_US.UTF-8" | sudo tee /etc/locale.conf
```

### Directory Architecture
```bash
mkdir -p ~/projects/personal
mkdir -p ~/projects/work
```

---

## 2. Core Toolchain & Git

### Install Basic Tools
```bash
sudo pacman -Sy --noconfirm git vim wget curl unzip zsh
```

### Git & Vim Configuration
Set up your identity and force Vim as the default editor:
```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
git config --global core.editor "vim"
git config --global init.defaultBranch main
```

---

## 3. Language Version Managers

### uv (Python Manager)
Install the fast Python manager:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### fnm (Fast Node Manager)
Install fnm and the latest Node.js LTS:
```bash
curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
# Apply to current session to continue setup
export PATH="$HOME/.local/share/fnm:$PATH"
eval "$(fnm env --use-on-cd)"
# Install Node.js LTS
fnm install --lts
fnm default $(fnm ls | grep "lts" | awk '{print $2}')
```

### pnpm (Node Package Manager)
Install pnpm using the standalone script:
```bash
curl -fsSL https://get.pnpm.io/install.sh | sh -
```

---

## 4. Multi-Account SSH Workflow

### Key Generation
Create separate keys for personal and work identities:
```bash
# Personal
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "your.email@example.com"
# Work
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_work -C "your.work.email@company.com"
```

### SSH Config Mapping
```bash
cat <<EOF > ~/.ssh/config
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
chmod 600 ~/.ssh/config
```

---

## 4. Docker Rootless Configuration

### ID Mapping & Dependencies
```bash
sudo pacman -S --noconfirm docker docker-rootless-extras newuidmap newgidmap
echo "$(whoami):100000:65536" | sudo tee -a /etc/subuid
echo "$(whoami):100000:65536" | sudo tee -a /etc/subgid
```

### WSL Network Fix
```bash
mkdir -p ~/.config/docker
cat <<EOF > ~/.config/docker/daemon.json
{
  "iptables": false,
  "ip6tables": false,
  "bridge": "none"
}
EOF
```

### Service Persistence
```bash
loginctl enable-linger $(whoami)
dockerd-rootless-setuptool.sh install
systemctl --user enable --now docker
```

---

## 5. Zsh & Starship Setup

### Install Oh My Zsh
```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
```

### Install Starship
```bash
curl -sS https://starship.rs/install.sh | sh
```

### Apply Starship Preset (Tokyo Night)
```bash
starship preset tokyo-night -o ~/.config/starship.toml
```

---

## 6. Shell Integration (.zshrc)

Add the following block to the end of your `~/.zshrc`:

```bash
# Docker Rootless Connection
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
if command -v docker >/dev/null 2>&1; then
    docker context use rootless >/dev/null 2>&1
fi

# Version Managers (fnm/pnpm)
eval "$(fnm env --use-on-cd --shell zsh)"

# Starship Initialization (Keep at the very end)
eval "$(starship init zsh)"
```

---

## 7. Global Security Hardening

Disable automatic script execution for Node.js package managers:
```bash
npm config set ignore-scripts true --global
pnpm config set ignore-scripts true --global
```

---

## 8. Finalizing
Change your default shell to Zsh and restart WSL:
```bash
sudo chsh -s $(command -v zsh) $(whoami)
```
Exit WSL and run `wsl --terminate <distro>` in PowerShell to apply all changes.
