#!/bin/bash
set -euo pipefail

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd )"
. "${SOURCE_DIR}/../common/helpers.sh"

ZSH_INSTALLED=false

detect_package_manager

install_the_lts_fnm_version

install_pnpm

install_gemini_cli() {
    if command_exists gemini; then
        return 0
    fi
    if pnpm install -g @google/gemini-cli; then
        echo "Successfully installed gemini-cli"
    else
        echo "Failed to install gemini-cli"
        exit 1
    fi
}

install_gemini_cli