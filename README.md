# WSL/Linux Development Environment Setup Script

This script automates the setup of a consistent and powerful development environment on Debian/Ubuntu or Arch-based Linux distributions. It is designed to be run once on a new system to install and configure essential tools like Git, Zsh, Docker, and version managers for Node.js (`fnm`) and Python (`uv`).

## Features

- **Cross-Distribution Support**: Automatically detects and uses the appropriate package manager (`apt` for Debian/Ubuntu, `pacman` for Arch).
- **Git Configuration**: Sets your global `user.name` and `user.email` from command-line arguments.
- **Modern Shell**: Installs Zsh and the popular Oh My Zsh framework, then sets Zsh as your default shell.
- **Interactive Setup**: Asks for confirmation before installing major components like Zsh, `uv`, `fnm`, and Docker, allowing you to customize the installation.
- **Language Version Management**:
  - Installs **fnm** (Fast Node Manager) for managing multiple Node.js versions.
  - Installs **uv** (a fast Python package manager and resolver) from Astral.
- **Containerization**: Installs Docker and Docker Compose and adds your user to the `docker` group to enable running Docker commands without `sudo`.
- **Developer Tools**: Includes a separate script (`general/IA_settings.sh`) to install development tools like the Gemini CLI.
- **Shell Integration**: Automatically configures `.zshrc` to ensure all installed tools are available in your `PATH` and initialized correctly.

## Prerequisites

- A Debian-based (e.g., Ubuntu) or Arch-based (e.g., Manjaro) Linux distribution.
- `bash` to execute the script.
- `sudo` privileges for installing packages and changing system settings.

## Usage

1.  **Clone the repository (if you haven't already):**

    ```bash
    git clone <your-repo-url>
    cd wsl-config-dev-setup
    ```

2.  **Make the script executable:**

    ```bash
    chmod +x initial_settings.sh
    ```

3.  **Run the script with your Git details:**

    You must provide your name and email for the global Git configuration.

    ```bash
    ./initial_settings.sh --name "Your Name" --email "your.email@example.com"
    ```

4.  **Follow the interactive prompts:**

    The script will ask you whether you want to install Zsh, uv, fnm, and Docker. Answer `y` (yes) or `n` (no) for each prompt.

## What the Script Does

1.  **Argument Parsing**: Validates that `--name` and `--email` are provided.
2.  **Package Manager Detection**: Identifies whether to use `apt` or `pacman`.
3.  **Sudo Validation**: Prompts for your `sudo` password upfront.
4.  **Git Setup**: Configures `user.name`, `user.email`, and sets the default branch name to `main`.
5.  **Core Dependencies**: Installs `wget`, `curl`, and `unzip`.
6.  **Zsh & Oh My Zsh**: If confirmed, installs `zsh`, installs Oh My Zsh non-interactively, and sets `zsh` as the default login shell for the current user.
7.  **uv (Python Tools)**: If confirmed, downloads and installs `uv`. The script currently attempts to add it to `.zshrc` (Note: `uv`'s installer typically handles this by modifying `.profile` or `.bashrc`, and sources `.cargo/env`).
8.  **fnm (Node.js Manager)**: If confirmed, downloads and installs `fnm` and appends the necessary initialization code to `.zshrc`.
9.  **Docker**: If confirmed, installs `docker` and `docker-compose` and adds the current user to the `docker` group.

---

### **IMPORTANT: Post-Installation Steps**

After the script finishes, you **must log out and log back in** for two critical changes to take effect:

1.  Your user to be recognized as part of the `docker` group.
2.  Your default shell to change to Zsh.

A full reboot will also achieve this.

## Additional Scripts

### `general/IA_settings.sh`

This script is designed to be run after the main `initial_settings.sh` script. It focuses on setting up AI-related tools, specifically the Google Gemini CLI. It automates the installation of its dependencies, including Node.js (via `fnm`) and the `pnpm` package manager, before installing the `@google/gemini-cli` package itself.

To run it:

```bash
./general/IA_settings.sh
```

### `general/wsl_arch_setup.sh`

This script provides advanced configuration specifically tailored for Arch Linux on WSL2. It focuses on a "Protected/Rootless" architecture, professional identity management, and high-performance developer toolchain.

**Features:**
- **WSL2 Systemd Integration**: Configures `/etc/wsl.conf` to enable systemd and sets the default user.
- **Locale Fixes**: Resolves common Perl and locale warnings in WSL.
- **Multi-Account SSH**: Generates and configures separate SSH keys for personal and work Git identities.
- **Docker Rootless**: Sets up Docker to run without root privileges, specifically tuned for WSL2 network compatibility.
- **Security Hardening**: Globally disables automatic script execution for `npm` and `pnpm`.
- **Advanced Zsh Integration**: Automates `fnm`, `Docker Rootless`, and `Starship` prompt initialization.

To run it:
```bash
chmod +x general/wsl_arch_setup.sh
./general/wsl_arch_setup.sh
```

## Customization

You can easily customize this script by editing the `install_packages` function calls or by adding/removing the conditional blocks for different tools.
