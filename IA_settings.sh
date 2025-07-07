#!/bin/bash
set -euo pipefail

echo "HOLA"
SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd )"

. "${SOURCE_DIR}/common/helpers.sh"

ZSH_INSTALLED=false

detect_package_manager
CURRENT_SHELL_TYPE=$(detect_current_shell_type)

echo "Current shell type: $CURRENT_SHELL_TYPE"
echo "$PKG_MANAGER"
echo "$INSTALL_CMD"