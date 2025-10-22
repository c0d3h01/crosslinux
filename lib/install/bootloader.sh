#!/usr/bin/env bash
# -*- Bootloader Installation Module -*-

# Install GRUB for Arch Linux
install_grub_arch() {
    local mount_point=${1:-"/mnt"}
    log_info "Installing GRUB for Arch Linux"
    
    # Install GRUB
    if safe_exec "arch-chroot $mount_point grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB"; then
        log_success "GRUB installed"
    else
        log_error "Failed to install GRUB"
        return 1
    fi
    
    # Generate GRUB configuration
    if safe_exec "arch-chroot $mount_point grub-mkconfig -o /boot/grub/grub.cfg"; then
        log_success "GRUB configuration generated"
    else
        log_error "Failed to generate GRUB configuration"
        return 1
    fi
    
    # Regenerate initramfs
    if safe_exec "arch-chroot $mount_point mkinitcpio -P"; then
        log_success "Initramfs regenerated"
    else
        log_error "Failed to regenerate initramfs"
        return 1
    fi
}

# Install GRUB for Ubuntu
install_grub_ubuntu() {
    local mount_point=${1:-"/mnt"}
    log_info "Installing GRUB for Ubuntu"
    
    # Install GRUB
    if safe_exec "chroot $mount_point grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu"; then
        log_success "GRUB installed"
    else
        log_error "Failed to install GRUB"
        return 1
    fi
    
    # Update GRUB configuration
    if safe_exec "chroot $mount_point update-grub"; then
        log_success "GRUB configuration updated"
    else
        log_error "Failed to update GRUB configuration"
        return 1
    fi
}

# Install bootloader based on distribution
install_bootloader() {
    local distro=$1
    local mount_point=${2:-"/mnt"}
    
    log_info "Installing bootloader for $distro"
    
    case $distro in
        "arch")
            install_grub_arch "$mount_point"
            ;;
        "ubuntu")
            install_grub_ubuntu "$mount_point"
            ;;
        "fedora")
            log_info "Fedora: Skipping bootloader installation (using existing bootloader)"
            ;;
        *)
            log_error "Unsupported distribution: $distro"
            return 1
            ;;
    esac
}

# Export functions
export -f install_grub_arch install_grub_ubuntu install_bootloader
