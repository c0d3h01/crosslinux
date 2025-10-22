#!/usr/bin/env bash
# -*- System Services Module -*-

# Enable essential system services
enable_system_services() {
    local mount_point=${1:-"/mnt"}
    log_info "Enabling system services"
    
    local services=(
        "fstrim.timer"
        "cups"
        "avahi-daemon"
        "systemd-timesyncd"
        "lm_sensors"
    )
    
    for service in "${services[@]}"; do
        if safe_exec "arch-chroot $mount_point systemctl enable $service"; then
            log_success "Enabled $service"
        else
            log_warning "Failed to enable $service"
        fi
    done
}

# Enable Docker
enable_docker() {
    local mount_point=${1:-"/mnt"}
    log_info "Enabling Docker"
    
    if safe_exec "arch-chroot $mount_point systemctl enable docker"; then
        log_success "Docker enabled"
    else
        log_error "Failed to enable Docker"
        return 1
    fi
}

# Enable SSH
enable_ssh() {
    local mount_point=${1:-"/mnt"}
    log_info "Enabling SSH"
    
    if safe_exec "arch-chroot $mount_point systemctl enable ssh"; then
        log_success "SSH enabled"
    else
        log_error "Failed to enable SSH"
        return 1
    fi
}

# Configure zram
configure_zram() {
    local mount_point=${1:-"/mnt"}
    log_info "Configuring zram"
    
    cat > "$mount_point/etc/systemd/zram-generator.conf" << EOF
[zram0]
compression-algorithm = zstd
zram-size = ram * 2
swap-priority = 100
fs-type = swap
EOF
    
    if [ $? -eq 0 ]; then
        log_success "ZRAM configured"
    else
        log_error "Failed to configure ZRAM"
        return 1
    fi
}

# Configure system optimization
configure_system_optimization() {
    local mount_point=${1:-"/mnt"}
    log_info "Configuring system optimization"
    
    # Configure systemd services
    cat > "$mount_point/etc/systemd/system/system-optimize.service" << EOF
[Unit]
Description=System Optimization
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo never > /sys/kernel/mm/transparent_hugepage/enabled'
ExecStart=/bin/bash -c 'echo 1 > /proc/sys/vm/drop_caches'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    if safe_exec "arch-chroot $mount_point systemctl enable system-optimize.service"; then
        log_success "System optimization service enabled"
    else
        log_error "Failed to enable system optimization service"
        return 1
    fi
}

# Enable Fedora-specific services
enable_fedora_services() {
    local mount_point=${1:-"/mnt"}
    log_info "Enabling Fedora-specific services"
    
    # Enable tuned for performance optimization
    if safe_exec "chroot $mount_point systemctl enable tuned"; then
        log_success "Tuned service enabled"
    else
        log_warning "Failed to enable tuned service"
    fi
    
    # Enable zram-generator
    if safe_exec "chroot $mount_point systemctl enable zram-generator.service"; then
        log_success "ZRAM generator enabled"
    else
        log_warning "Failed to enable ZRAM generator"
    fi
    
    # Enable systemd-oomd for memory management
    if safe_exec "chroot $mount_point systemctl enable systemd-oomd"; then
        log_success "systemd-oomd enabled"
    else
        log_warning "Failed to enable systemd-oomd"
    fi
    
    # Configure tuned profile
    if safe_exec "chroot $mount_point tuned-adm profile throughput-performance"; then
        log_success "Tuned profile set to throughput-performance"
    else
        log_warning "Failed to set tuned profile"
    fi
}

# Enable all system services
enable_all_system_services() {
    local mount_point=${1:-"/mnt"}
    log_info "Enabling all system services"
    
    # Enable system services
    enable_system_services "$mount_point" || return 1
    
    # Enable Docker
    enable_docker "$mount_point" || return 1
    
    # Enable SSH
    enable_ssh "$mount_point" || return 1
    
    # Configure zram
    configure_zram "$mount_point" || return 1
    
    # Configure system optimization
    configure_system_optimization "$mount_point" || return 1
    
    # Enable Fedora-specific services if running on Fedora
    if [ -f /etc/fedora-release ]; then
        enable_fedora_services "$mount_point" || return 1
    fi
    
    log_success "All system services enabled"
}

# Export functions
export -f enable_system_services enable_docker enable_ssh configure_zram configure_system_optimization enable_fedora_services enable_all_system_services
