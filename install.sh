#!/usr/bin/env bash
#
# ==============================================================================
# -*- Modular Linux Installation Script -*-
# ==============================================================================

# Set error handling
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Source all modules
source "$LIB_DIR/core/logging.sh"
source "$LIB_DIR/core/config.sh"
source "$LIB_DIR/core/errors.sh"
source "$LIB_DIR/core/utils.sh"
source "$LIB_DIR/disk/partition.sh"
source "$LIB_DIR/disk/filesystem.sh"
source "$LIB_DIR/install/packages.sh"
source "$LIB_DIR/install/bootloader.sh"
source "$LIB_DIR/config/system.sh"
source "$LIB_DIR/config/desktop.sh"
source "$LIB_DIR/services/network.sh"
source "$LIB_DIR/services/desktop.sh"
source "$LIB_DIR/services/system.sh"

# Set error trap
set_error_trap

# Main installation function
main() {
    log_info "Starting Linux installation"
    
    # Check system requirements
    check_root
    check_network
    check_disk_space
    
    # Initialize configuration
    init_config_defaults
    interactive_config
    
    # Detect distribution
    local distro=$(detect_distro)
    log_info "Detected distribution: $distro"
    
    # Show configuration
    show_config
    
    # Confirmation
    if ! confirm "Continue with installation? This will wipe ${CONFIG[DRIVE]}"; then
        log_info "Installation cancelled"
        exit 0
    fi
    
    # Installation steps
    log_step "Starting installation process"
    
    # Step 1: Partitioning
    log_step "Step 1/6: Partitioning disk"
    case $distro in
        "arch")
            create_arch_partitions "${CONFIG[DRIVE]}" || exit 1
            ;;
        "ubuntu")
            create_ubuntu_partitions "${CONFIG[DRIVE]}" || exit 1
            ;;
        "fedora")
            log_info "Fedora: Skipping partitioning (using existing partitions)"
            ;;
        *)
            log_error "Unsupported distribution: $distro"
            exit 1
            ;;
    esac
    
    # Step 2: Filesystem setup
    log_step "Step 2/6: Setting up filesystem"
    case $distro in
        "arch")
            setup_arch_filesystem "${CONFIG[EFI_PART]}" "${CONFIG[ROOT_PART]}" "/mnt" || exit 1
            ;;
        "ubuntu")
            setup_ubuntu_filesystem "${CONFIG[EFI_PART]}" "${CONFIG[ROOT_PART]}" "${CONFIG[HOME_PART]}" "/mnt" || exit 1
            ;;
        "fedora")
            log_info "Fedora: Skipping filesystem setup (using existing filesystem)"
            ;;
    esac
    
    # Step 3: Package installation
    log_step "Step 3/6: Installing packages"
    install_packages "$distro" "/mnt" || exit 1
    
    # Step 4: System configuration
    log_step "Step 4/6: Configuring system"
    case $distro in
        "arch")
            configure_arch_system "/mnt" || exit 1
            ;;
        "ubuntu")
            configure_ubuntu_system "/mnt" || exit 1
            ;;
        "fedora")
            configure_fedora_system "/mnt" || exit 1
            ;;
    esac
    
    # Step 5: Desktop configuration
    log_step "Step 5/6: Configuring desktop"
    configure_desktop "${CONFIG[USERNAME]}" "/mnt" || exit 1
    
    # Step 6: Service configuration
    log_step "Step 6/6: Configuring services"
    configure_network_services "$distro" "/mnt" || exit 1
    enable_desktop_services "$distro" "/mnt" || exit 1
    enable_all_system_services "/mnt" || exit 1
    
    # Step 7: Bootloader installation
    log_step "Installing bootloader"
    install_bootloader "$distro" "/mnt" || exit 1
    
    # Final steps
    log_success "Installation completed successfully!"
    
    # Save configuration
    save_config_file "/tmp/install_config.conf"
    
    # Final prompt
    if confirm "Unmount and reboot now?"; then
        umount -R /mnt
        reboot
    else
        log_info "System ready. You can manually unmount and reboot when ready."
    fi
}

# Execute main function
main "$@"
