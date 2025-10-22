#!/usr/bin/env bash
# -*- System Configuration Module -*-

# Generate fstab
generate_fstab() {
    local mount_point=${1:-"/mnt"}
    log_info "Generating fstab"
    
    if safe_exec "genfstab -U $mount_point >> $mount_point/etc/fstab"; then
        log_success "fstab generated"
    else
        log_error "Failed to generate fstab"
        return 1
    fi
}

# Set timezone
set_timezone() {
    local timezone=$1
    local mount_point=${2:-"/mnt"}
    log_info "Setting timezone: $timezone"
    
    if safe_exec "arch-chroot $mount_point ln -sf /usr/share/zoneinfo/$timezone /etc/localtime"; then
        log_success "Timezone set"
    else
        log_error "Failed to set timezone"
        return 1
    fi
    
    # Synchronize hardware clock
    if safe_exec "arch-chroot $mount_point hwclock --systohc"; then
        log_success "Hardware clock synchronized"
    else
        log_error "Failed to synchronize hardware clock"
        return 1
    fi
}

# Configure locale
configure_locale() {
    local locale=$1
    local mount_point=${2:-"/mnt"}
    log_info "Configuring locale: $locale"
    
    # Add locale to locale.gen
    if safe_exec "arch-chroot $mount_point echo '$locale UTF-8' >> /etc/locale.gen"; then
        log_success "Locale added to locale.gen"
    else
        log_error "Failed to add locale to locale.gen"
        return 1
    fi
    
    # Generate locale
    if safe_exec "arch-chroot $mount_point locale-gen"; then
        log_success "Locale generated"
    else
        log_error "Failed to generate locale"
        return 1
    fi
    
    # Set default locale
    if safe_exec "arch-chroot $mount_point echo 'LANG=$locale' > /etc/locale.conf"; then
        log_success "Default locale set"
    else
        log_error "Failed to set default locale"
        return 1
    fi
}

# Set hostname
set_hostname() {
    local hostname=$1
    local mount_point=${2:-"/mnt"}
    log_info "Setting hostname: $hostname"
    
    if safe_exec "arch-chroot $mount_point echo '$hostname' > /etc/hostname"; then
        log_success "Hostname set"
    else
        log_error "Failed to set hostname"
        return 1
    fi
}

# Configure hosts file
configure_hosts() {
    local hostname=$1
    local mount_point=${2:-"/mnt"}
    log_info "Configuring hosts file"
    
    cat > "$mount_point/etc/hosts" << EOF
127.0.0.1 localhost
::1 localhost
127.0.0.2 $hostname
EOF
    
    if [ $? -eq 0 ]; then
        log_success "Hosts file configured"
    else
        log_error "Failed to configure hosts file"
        return 1
    fi
}

# Set root password
set_root_password() {
    local password=$1
    local mount_point=${2:-"/mnt"}
    log_info "Setting root password"
    
    if safe_exec "arch-chroot $mount_point echo 'root:$password' | chpasswd"; then
        log_success "Root password set"
    else
        log_error "Failed to set root password"
        return 1
    fi
}

# Create user
create_user() {
    local username=$1
    local password=$2
    local mount_point=${3:-"/mnt"}
    log_info "Creating user: $username"
    
    # Create user
    if safe_exec "arch-chroot $mount_point useradd -m -G wheel -s /bin/zsh $username"; then
        log_success "User created"
    else
        log_error "Failed to create user"
        return 1
    fi
    
    # Set user password
    if safe_exec "arch-chroot $mount_point echo '$username:$password' | chpasswd"; then
        log_success "User password set"
    else
        log_error "Failed to set user password"
        return 1
    fi
}

# Configure sudo
configure_sudo() {
    local mount_point=${1:-"/mnt"}
    log_info "Configuring sudo"
    
    if safe_exec "arch-chroot $mount_point sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers"; then
        log_success "Sudo configured"
    else
        log_error "Failed to configure sudo"
        return 1
    fi
}

# Configure system for Arch Linux
configure_arch_system() {
    local mount_point=${1:-"/mnt"}
    log_info "Configuring Arch Linux system"
    
    # Generate fstab
    generate_fstab "$mount_point" || return 1
    
    # Set timezone
    set_timezone "${CONFIG[TIMEZONE]}" "$mount_point" || return 1
    
    # Configure locale
    configure_locale "${CONFIG[LOCALE]}" "$mount_point" || return 1
    
    # Set hostname
    set_hostname "${CONFIG[HOSTNAME]}" "$mount_point" || return 1
    
    # Configure hosts
    configure_hosts "${CONFIG[HOSTNAME]}" "$mount_point" || return 1
    
    # Set root password
    set_root_password "${CONFIG[PASSWORD]}" "$mount_point" || return 1
    
    # Create user
    create_user "${CONFIG[USERNAME]}" "${CONFIG[PASSWORD]}" "$mount_point" || return 1
    
    # Configure sudo
    configure_sudo "$mount_point" || return 1
    
    log_success "Arch Linux system configured"
}

# Configure system for Ubuntu
configure_ubuntu_system() {
    local mount_point=${1:-"/mnt"}
    log_info "Configuring Ubuntu system"
    
    # Set timezone
    if safe_exec "chroot $mount_point timedatectl set-timezone ${CONFIG[TIMEZONE]}"; then
        log_success "Timezone set"
    else
        log_error "Failed to set timezone"
        return 1
    fi
    
    # Configure locale
    if safe_exec "chroot $mount_point locale-gen ${CONFIG[LOCALE]}"; then
        log_success "Locale generated"
    else
        log_error "Failed to generate locale"
        return 1
    fi
    
    # Set hostname
    if safe_exec "chroot $mount_point hostnamectl set-hostname ${CONFIG[HOSTNAME]}"; then
        log_success "Hostname set"
    else
        log_error "Failed to set hostname"
        return 1
    fi
    
    # Create user
    if safe_exec "chroot $mount_point useradd -m -s /bin/zsh ${CONFIG[USERNAME]}"; then
        log_success "User created"
    else
        log_error "Failed to create user"
        return 1
    fi
    
    # Set passwords
    if safe_exec "chroot $mount_point echo 'root:${CONFIG[PASSWORD]}' | chpasswd"; then
        log_success "Root password set"
    else
        log_error "Failed to set root password"
        return 1
    fi
    
    if safe_exec "chroot $mount_point echo '${CONFIG[USERNAME]}:${CONFIG[PASSWORD]}' | chpasswd"; then
        log_success "User password set"
    else
        log_error "Failed to set user password"
        return 1
    fi
    
    # Configure sudo
    if safe_exec "chroot $mount_point usermod -aG sudo ${CONFIG[USERNAME]}"; then
        log_success "User added to sudo group"
    else
        log_error "Failed to add user to sudo group"
        return 1
    fi
    
    log_success "Ubuntu system configured"
}

# Configure system for Fedora
configure_fedora_system() {
    local mount_point=${1:-"/mnt"}
    log_info "Configuring Fedora system"
    
    # Set timezone
    if safe_exec "chroot $mount_point timedatectl set-timezone ${CONFIG[TIMEZONE]}"; then
        log_success "Timezone set"
    else
        log_error "Failed to set timezone"
        return 1
    fi
    
    # Configure locale
    if safe_exec "chroot $mount_point localectl set-locale LANG=${CONFIG[LOCALE]}"; then
        log_success "Locale set"
    else
        log_error "Failed to set locale"
        return 1
    fi
    
    # Set hostname
    if safe_exec "chroot $mount_point hostnamectl set-hostname ${CONFIG[HOSTNAME]}"; then
        log_success "Hostname set"
    else
        log_error "Failed to set hostname"
        return 1
    fi
    
    # Create user
    if safe_exec "chroot $mount_point useradd -m -s /bin/zsh ${CONFIG[USERNAME]}"; then
        log_success "User created"
    else
        log_error "Failed to create user"
        return 1
    fi
    
    # Set passwords
    if safe_exec "chroot $mount_point echo 'root:${CONFIG[PASSWORD]}' | chpasswd"; then
        log_success "Root password set"
    else
        log_error "Failed to set root password"
        return 1
    fi
    
    if safe_exec "chroot $mount_point echo '${CONFIG[USERNAME]}:${CONFIG[PASSWORD]}' | chpasswd"; then
        log_success "User password set"
    else
        log_error "Failed to set user password"
        return 1
    fi
    
    # Configure sudo
    if safe_exec "chroot $mount_point usermod -aG wheel ${CONFIG[USERNAME]}"; then
        log_success "User added to wheel group"
    else
        log_error "Failed to add user to wheel group"
        return 1
    fi
    
    # Configure zram
    if safe_exec "chroot $mount_point systemctl enable zram-generator.service"; then
        log_success "ZRAM generator enabled"
    else
        log_warning "Failed to enable ZRAM generator"
    fi
    
    # Configure system optimization
    if safe_exec "chroot $mount_point systemctl enable tuned.service"; then
        log_success "Tuned service enabled"
    else
        log_warning "Failed to enable tuned service"
    fi
    
    log_success "Fedora system configured"
}

# Export functions
export -f generate_fstab set_timezone configure_locale set_hostname configure_hosts
export -f set_root_password create_user configure_sudo configure_arch_system configure_ubuntu_system configure_fedora_system
