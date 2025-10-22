#!/usr/bin/env bash
# -*- Desktop Configuration Module -*-

# Configure GDM
configure_gdm() {
    local username=$1
    local mount_point=${2:-"/mnt"}
    log_info "Configuring GDM"
    
    cat > "$mount_point/etc/gdm/custom.conf" << EOF
[daemon]
AutomaticLogin=$username
AutomaticLoginEnable=true
EOF
    
    if [ $? -eq 0 ]; then
        log_success "GDM configured"
    else
        log_error "Failed to configure GDM"
        return 1
    fi
}

# Configure GNOME settings
configure_gnome_settings() {
    local username=$1
    local mount_point=${2:-"/mnt"}
    log_info "Configuring GNOME settings"
    
    # Configure GNOME extensions
    cat > "$mount_point/home/$username/.config/gnome-shell/enabled-extensions" << EOF
user-theme
dash-to-dock
EOF
    
    # Configure dash-to-dock
    cat > "$mount_point/home/$username/.config/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/settings.json" << EOF
{
    "dock-position": "BOTTOM",
    "extend-height": false
}
EOF
    
    # Configure desktop theme
    cat > "$mount_point/home/$username/.config/gtk-3.0/settings.ini" << EOF
[Settings]
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=true
EOF
    
    log_success "GNOME settings configured"
}

# Configure zsh
configure_zsh() {
    local username=$1
    local mount_point=${2:-"/mnt"}
    log_info "Configuring zsh for $username"
    
    # Set zsh as default shell
    if safe_exec "arch-chroot $mount_point chsh -s /bin/zsh $username"; then
        log_success "Zsh set as default shell"
    else
        log_error "Failed to set zsh as default shell"
        return 1
    fi
    
    # Install Oh My Zsh
    if safe_exec "arch-chroot $mount_point su - $username -c 'sh -c \"\$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended'"; then
        log_success "Oh My Zsh installed"
    else
        log_warning "Failed to install Oh My Zsh"
    fi
}

# Configure desktop environment
configure_desktop() {
    local username=$1
    local mount_point=${2:-"/mnt"}
    log_info "Configuring desktop environment"
    
    # Configure GDM
    configure_gdm "$username" "$mount_point" || return 1
    
    # Configure GNOME settings
    configure_gnome_settings "$username" "$mount_point" || return 1
    
    # Configure zsh
    configure_zsh "$username" "$mount_point" || return 1
    
    log_success "Desktop environment configured"
}

# Export functions
export -f configure_gdm configure_gnome_settings configure_zsh configure_desktop
