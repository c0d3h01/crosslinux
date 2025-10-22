#!/usr/bin/env bash
# -*- Network Services Module -*-

# Enable NetworkManager
enable_networkmanager() {
    local mount_point=${1:-"/mnt"}
    log_info "Enabling NetworkManager"
    
    if safe_exec "arch-chroot $mount_point systemctl enable NetworkManager"; then
        log_success "NetworkManager enabled"
    else
        log_error "Failed to enable NetworkManager"
        return 1
    fi
}

# Configure firewall for Arch
configure_firewall_arch() {
    local mount_point=${1:-"/mnt"}
    log_info "Configuring firewall for Arch Linux"
    
    # Enable firewalld
    if safe_exec "arch-chroot $mount_point systemctl enable firewalld"; then
        log_success "Firewalld enabled"
    else
        log_error "Failed to enable firewalld"
        return 1
    fi
    
    # Configure firewall rules
    if safe_exec "arch-chroot $mount_point firewall-cmd --permanent --zone=public --add-service=ssh"; then
        log_success "SSH service added to firewall"
    else
        log_warning "Failed to add SSH service to firewall"
    fi
    
    if safe_exec "arch-chroot $mount_point firewall-cmd --permanent --zone=public --add-service=http"; then
        log_success "HTTP service added to firewall"
    else
        log_warning "Failed to add HTTP service to firewall"
    fi
    
    if safe_exec "arch-chroot $mount_point firewall-cmd --permanent --zone=public --add-service=https"; then
        log_success "HTTPS service added to firewall"
    else
        log_warning "Failed to add HTTPS service to firewall"
    fi
    
    # Reload firewall
    if safe_exec "arch-chroot $mount_point firewall-cmd --reload"; then
        log_success "Firewall reloaded"
    else
        log_warning "Failed to reload firewall"
    fi
}

# Configure firewall for Ubuntu
configure_firewall_ubuntu() {
    local mount_point=${1:-"/mnt"}
    log_info "Configuring firewall for Ubuntu"
    
    # Enable UFW
    if safe_exec "chroot $mount_point ufw --force enable"; then
        log_success "UFW enabled"
    else
        log_error "Failed to enable UFW"
        return 1
    fi
    
    # Configure firewall rules
    if safe_exec "chroot $mount_point ufw default deny incoming"; then
        log_success "Default deny incoming set"
    else
        log_warning "Failed to set default deny incoming"
    fi
    
    if safe_exec "chroot $mount_point ufw default allow outgoing"; then
        log_success "Default allow outgoing set"
    else
        log_warning "Failed to set default allow outgoing"
    fi
    
    if safe_exec "chroot $mount_point ufw allow ssh"; then
        log_success "SSH allowed"
    else
        log_warning "Failed to allow SSH"
    fi
    
    if safe_exec "chroot $mount_point ufw allow http"; then
        log_success "HTTP allowed"
    else
        log_warning "Failed to allow HTTP"
    fi
    
    if safe_exec "chroot $mount_point ufw allow https"; then
        log_success "HTTPS allowed"
    else
        log_warning "Failed to allow HTTPS"
    fi
}

# Configure firewall for Fedora
configure_firewall_fedora() {
    local mount_point=${1:-"/mnt"}
    log_info "Configuring firewall for Fedora"
    
    # Enable firewalld
    if safe_exec "chroot $mount_point systemctl enable firewalld"; then
        log_success "Firewalld enabled"
    else
        log_error "Failed to enable firewalld"
        return 1
    fi
    
    # Configure firewall rules
    if safe_exec "chroot $mount_point firewall-cmd --permanent --zone=public --add-service=ssh"; then
        log_success "SSH service added to firewall"
    else
        log_warning "Failed to add SSH service to firewall"
    fi
    
    if safe_exec "chroot $mount_point firewall-cmd --permanent --zone=public --add-service=http"; then
        log_success "HTTP service added to firewall"
    else
        log_warning "Failed to add HTTP service to firewall"
    fi
    
    if safe_exec "chroot $mount_point firewall-cmd --permanent --zone=public --add-service=https"; then
        log_success "HTTPS service added to firewall"
    else
        log_warning "Failed to add HTTPS service to firewall"
    fi
    
    # Reload firewall
    if safe_exec "chroot $mount_point firewall-cmd --reload"; then
        log_success "Firewall reloaded"
    else
        log_warning "Failed to reload firewall"
    fi
}

# Configure network services
configure_network_services() {
    local distro=$1
    local mount_point=${2:-"/mnt"}
    log_info "Configuring network services for $distro"
    
    # Enable NetworkManager
    enable_networkmanager "$mount_point" || return 1
    
    # Configure firewall
    case $distro in
        "arch")
            configure_firewall_arch "$mount_point"
            ;;
        "ubuntu")
            configure_firewall_ubuntu "$mount_point"
            ;;
        "fedora")
            configure_firewall_fedora "$mount_point"
            ;;
        *)
            log_error "Unsupported distribution: $distro"
            return 1
            ;;
    esac
}

# Export functions
export -f enable_networkmanager configure_firewall_arch configure_firewall_ubuntu configure_firewall_fedora configure_network_services
