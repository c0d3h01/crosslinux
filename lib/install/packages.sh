#!/usr/bin/env bash
# -*- Package Installation Module -*-

# Configure pacman
configure_pacman() {
    log_info "Configuring pacman"
    
    # Enable parallel downloads
    if safe_exec "sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf"; then
        log_success "Parallel downloads enabled"
    else
        log_warning "Failed to enable parallel downloads"
    fi
    
    # Disable download timeout
    if safe_exec "sed -i '/^# Misc options/a DisableDownloadTimeout' /etc/pacman.conf"; then
        log_success "Download timeout disabled"
    else
        log_warning "Failed to disable download timeout"
    fi
}

# Update mirrorlist
update_mirrorlist() {
    log_info "Updating mirrorlist"
    
    if safe_exec "reflector --country India --age 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist"; then
        log_success "Mirrorlist updated"
    else
        log_warning "Failed to update mirrorlist"
    fi
}

# Refresh package databases
refresh_package_databases() {
    log_info "Refreshing package databases"
    
    if safe_exec "pacman -Syy"; then
        log_success "Package databases refreshed"
    else
        log_error "Failed to refresh package databases"
        return 1
    fi
}

# Install base packages
install_base_packages() {
    local mount_point=${1:-"/mnt"}
    log_info "Installing base packages"
    
    local packages=(
        # Core System
        base base-devel linux-firmware linux-lts linux-lts-headers
        btrfs-progs grub efibootmgr
        
        # CPU microcode
        $([ "${CONFIG[CPU_VENDOR]}" = "intel" ] && echo "intel-ucode" || echo "amd-ucode")
        
        # Graphics drivers
        $([ "${CONFIG[GPU_VENDOR]}" = "nvidia" ] && echo "nvidia nvidia-utils nvidia-settings" || echo "")
        $([ "${CONFIG[GPU_VENDOR]}" = "amd" ] && echo "libva-mesa-driver mesa vulkan-radeon xf86-video-amdgpu xf86-video-ati" || echo "")
        $([ "${CONFIG[GPU_VENDOR]}" = "intel" ] && echo "libva-intel-driver mesa vulkan-intel xf86-video-intel" || echo "")
        
        # X11 and Wayland
        xorg-server xorg-xinit xorg-xrandr xorg-xsetroot
        wayland wayland-protocols xdg-desktop-portal xdg-desktop-portal-gnome
        
        # Network & Security
        networkmanager firewalld openssh
        
        # Audio & Bluetooth
        bluez bluez-utils pipewire pipewire-pulse pipewire-alsa pipewire-jack
        wireplumber gstreamer gst-libav gst-plugins-base gst-plugins-good
        gst-plugins-bad gst-plugins-ugly pavucontrol
        
        # GNOME Desktop
        gnome gnome-extra gdm gnome-tweaks gnome-shell-extensions
        
        # Fonts
        noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-fira-code
        ttf-dejavu ttf-liberation ttf-roboto
        
        # Essential Tools
        git wget curl zsh neovim micro kitty
        fastfetch glances inxi htop tree unzip zip
        reflector pacutils snap-pac grub-btrfs
        cups snapper zram-generator
        
        # Development
        gcc glibc gdb cmake clang nodejs npm yarn
        docker docker-compose jdk-openjdk python python-pip
        jupyterlab python-virtualenv
        
        # Applications
        firefox discord telegram-desktop
        vim nano htop tree unzip zip
        openssh sshpass inxi zsh cups
        xclip neovim
        
        # System utilities
        systemd-swap zram-generator
        lm_sensors fancontrol
        cronie cronie-anacron
        logrotate
    )
    
    # Filter out empty packages
    local filtered_packages=()
    for package in "${packages[@]}"; do
        if [ -n "$package" ]; then
            filtered_packages+=("$package")
        fi
    done
    
    if safe_exec "pacstrap -K $mount_point --needed ${filtered_packages[@]}"; then
        log_success "Base packages installed"
    else
        log_error "Failed to install base packages"
        return 1
    fi
}

# Install Ubuntu packages
install_ubuntu_packages() {
    log_info "Installing Ubuntu packages"
    
    # Update package lists
    if safe_exec "apt update"; then
        log_success "Package lists updated"
    else
        log_error "Failed to update package lists"
        return 1
    fi
    
    # Install debootstrap
    if safe_exec "apt install -y debootstrap"; then
        log_success "Debootstrap installed"
    else
        log_error "Failed to install debootstrap"
        return 1
    fi
    
    # Install base system
    if safe_exec "debootstrap --arch amd64 focal /mnt http://archive.ubuntu.com/ubuntu/"; then
        log_success "Base system installed"
    else
        log_error "Failed to install base system"
        return 1
    fi
    
    # Mount essential filesystems
    mount --bind /dev /mnt/dev
    mount --bind /proc /mnt/proc
    mount --bind /sys /mnt/sys
    mount --bind /run /mnt/run
    
    # Install packages in chroot
    chroot /mnt /bin/bash <<EOF
    apt update
    
    # Install essential packages
    DEBIAN_FRONTEND=noninteractive apt install -y \
        linux-generic linux-headers-generic \
        grub-efi-amd64 grub-efi-amd64-signed \
        network-manager ufw openssh-server \
        ubuntu-gnome-desktop gnome-tweaks gnome-shell-extensions \
        pipewire pipewire-pulse pipewire-alsa bluez \
        git wget curl zsh neovim micro kitty \
        htop neofetch inxi cups \
        build-essential gcc g++ make cmake \
        nodejs npm python3 python3-pip \
        docker.io docker-compose openjdk-11-jdk \
        firefox discord telegram-desktop \
        vim nano htop tree unzip zip \
        software-properties-common apt-transport-https ca-certificates \
        gnupg lsb-release
EOF
    
    if [ $? -eq 0 ]; then
        log_success "Ubuntu packages installed"
    else
        log_error "Failed to install Ubuntu packages"
        return 1
    fi
}

# Install Fedora packages
install_fedora_packages() {
    log_info "Installing Fedora packages"
    
    # Update package lists
    if safe_exec "dnf update -y"; then
        log_success "Package lists updated"
    else
        log_error "Failed to update package lists"
        return 1
    fi
    
    # Install development and system packages
    local packages=(
        # Development tools
        gcc gcc-c++ make cmake clang
        git wget curl zsh neovim micro
        nodejs npm python3 python3-pip
        java-11-openjdk java-11-openjdk-devel
        docker docker-compose
        jupyterlab python3-virtualenv
        
        # System utilities
        htop neofetch inxi tree unzip zip
        openssh-server cups
        zram-generator systemd-swap
        lm_sensors fancontrol
        logrotate cronie
        
        # Network and security
        NetworkManager firewalld
        bluez bluez-utils
        
        # Audio
        pipewire pipewire-pulse pipewire-alsa
        wireplumber gstreamer1-plugins-*
        
        # Applications
        firefox discord telegram-desktop
        vim nano htop tree unzip zip
        
        # System optimization
        tuned tuned-utils
        systemd-oomd
    )
    
    # Install packages
    if safe_exec "dnf install -y ${packages[@]}"; then
        log_success "Fedora packages installed"
    else
        log_error "Failed to install Fedora packages"
        return 1
    fi
    
    # Enable RPM Fusion repositories
    if safe_exec "dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"; then
        log_success "RPM Fusion repositories enabled"
    else
        log_warning "Failed to enable RPM Fusion repositories"
    fi
}

# Install packages based on distribution
install_packages() {
    local distro=$1
    local mount_point=${2:-"/mnt"}
    
    log_info "Installing packages for $distro"
    
    case $distro in
        "arch")
            configure_pacman
            update_mirrorlist
            refresh_package_databases
            install_base_packages "$mount_point"
            ;;
        "ubuntu")
            install_ubuntu_packages
            ;;
        "fedora")
            install_fedora_packages
            ;;
        *)
            log_error "Unsupported distribution: $distro"
            return 1
            ;;
    esac
}

# Export functions
export -f configure_pacman update_mirrorlist refresh_package_databases install_base_packages
export -f install_ubuntu_packages install_fedora_packages install_packages
