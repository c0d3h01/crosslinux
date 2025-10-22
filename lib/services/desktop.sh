#!/usr/bin/env bash
# -*- Desktop Services Module -*-

# Enable GDM
enable_gdm() {
    local mount_point=${1:-"/mnt"}
    log_info "Enabling GDM"
    
    if safe_exec "arch-chroot $mount_point systemctl enable gdm"; then
        log_success "GDM enabled"
    else
        log_error "Failed to enable GDM"
        return 1
    fi
}

# Enable GDM3 for Ubuntu
enable_gdm3() {
    local mount_point=${1:-"/mnt"}
    log_info "Enabling GDM3"
    
    if safe_exec "chroot $mount_point systemctl enable gdm3"; then
        log_success "GDM3 enabled"
    else
        log_error "Failed to enable GDM3"
        return 1
    fi
}

# Enable Bluetooth
enable_bluetooth() {
    local mount_point=${1:-"/mnt"}
    log_info "Enabling Bluetooth"
    
    if safe_exec "arch-chroot $mount_point systemctl enable bluetooth"; then
        log_success "Bluetooth enabled"
    else
        log_error "Failed to enable Bluetooth"
        return 1
    fi
}

# Enable audio services
enable_audio_services() {
    local mount_point=${1:-"/mnt"}
    log_info "Enabling audio services"
    
    # Enable PipeWire
    if safe_exec "arch-chroot $mount_point systemctl --user enable pipewire"; then
        log_success "PipeWire enabled"
    else
        log_error "Failed to enable PipeWire"
        return 1
    fi
    
    # Enable WirePlumber
    if safe_exec "arch-chroot $mount_point systemctl --user enable wireplumber"; then
        log_success "WirePlumber enabled"
    else
        log_error "Failed to enable WirePlumber"
        return 1
    fi
}

# Enable desktop services
enable_desktop_services() {
    local distro=$1
    local mount_point=${2:-"/mnt"}
    log_info "Enabling desktop services for $distro"
    
    # Enable display manager
    case $distro in
        "arch")
            enable_gdm "$mount_point" || return 1
            ;;
        "ubuntu")
            enable_gdm3 "$mount_point" || return 1
            ;;
        *)
            log_error "Unsupported distribution: $distro"
            return 1
            ;;
    esac
    
    # Enable Bluetooth
    enable_bluetooth "$mount_point" || return 1
    
    # Enable audio services
    enable_audio_services "$mount_point" || return 1
    
    log_success "Desktop services enabled"
}

# Export functions
export -f enable_gdm enable_gdm3 enable_bluetooth enable_audio_services enable_desktop_services
