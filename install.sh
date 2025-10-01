#!/usr/bin/env bash
#
# shellcheck disable=SC2162
#
# ==============================================================================
# -*- Automated Arch Linux Installation Personal Setup Script -*-
# ==============================================================================

# Logs all commands and exits on error
set -exuo pipefail

# -*- Source external modules -*-
source ./modules/setup_base_system.sh
source ./modules/setup_configuration.sh
source ./modules/setup_disk.sh
source ./modules/setup_filesystem.sh
source ./modules/setup_optimization.sh
source ./modules/setup_system.sh

# -*- Color codes -*-
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# -*- Global variables -*-
declare -A CONFIG

# -*- Configuration function -*-
function init_config() {

    # Prompt for password
    while true; do
        read -s -p "Enter a single password for root and user: " PASSWORD
        echo
        read -s -p "Confirm the password: " CONFIRM_PASSWORD
        echo
        if [ "$PASSWORD" = "$CONFIRM_PASSWORD" ]; then
            break
        else
            echo "Passwords do not match. Try again."
        fi
    done

    # Configuration settings
    CONFIG=(
        [DRIVE]="/dev/nvme0n1"
        [HOSTNAME]="eva"
        [USERNAME]="c0d3h01"
        [PASSWORD]="$PASSWORD"
        [TIMEZONE]="Asia/Kolkata"
        [LOCALE]="en_IN.UTF-8"
    )
    CONFIG[EFI_PART]="${CONFIG[DRIVE]}p1"
    CONFIG[ROOT_PART]="${CONFIG[DRIVE]}p2"
}

# -*- Logging functions -*-
function info() { echo -e "${BLUE}INFO: $* ${NC}"; }
function success() { echo -e "${GREEN}SUCCESS:$* ${NC}"; }

function main() {
    info "Starting Arch Linux installation script..."

    # Initialize configuration
    init_config

    # Main installation steps
    setup_disk
    setup_filesystems
    install_base_system
    configure_system
    coustom_configuration

    # Final message and unmount prompt
    read -p "Installation successful!, Unmount NOW? (y/n): " UNMOUNT
    if [[ $UNMOUNT =~ ^[Yy]$ ]]; then
        umount -R /mnt
    else
        arch-chroot /mnt
    fi
}

# Execute main function
main
