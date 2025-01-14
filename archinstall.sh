#!/usr/bin/env bash
#
# shellcheck disable=SC2162
#
# ==============================================================================
# Automated Arch Linux Installation Personal Setup Script
# ==============================================================================

set -exuo pipefail

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

declare -A CONFIG

# Configuration function
function init_config() {

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

    CONFIG=(
        [DRIVE]="/dev/nvme0n1"
        [HOSTNAME]="archost"
        [USERNAME]="c0d3h01"
        [PASSWORD]="$PASSWORD"
        [TIMEZONE]="Asia/Kolkata"
        [LOCALE]="en_IN.UTF-8"
    )
    CONFIG[EFI_PART]="${CONFIG[DRIVE]}p1"
    CONFIG[ROOT_PART]="${CONFIG[DRIVE]}p2"
}

# Logging functions
function info() { echo -e "${BLUE}INFO: $* ${NC}"; }
function success() { echo -e "${GREEN}SUCCESS:$* ${NC}"; }

function setup_disk() {
    # Wipe and prepare the disk
    wipefs -af "${CONFIG[DRIVE]}"
    sgdisk --zap-all "${CONFIG[DRIVE]}"

    # Create fresh GPT
    sgdisk --clear "${CONFIG[DRIVE]}"

    # Create partitions
    sgdisk \
        --new=1:0:+1G --typecode=1:ef00 --change-name=1:"EFI" \
        --new=2:0:0 --typecode=2:8300 --change-name=2:"ROOT" \
        "${CONFIG[DRIVE]}"

    # Reload the partition table
    partprobe "${CONFIG[DRIVE]}"
    sleep 2
}

function setup_filesystems() {
    # Format partitions
    mkfs.fat -F32 -n "${CONFIG[EFI_PART]}"
    mkfs.btrfs \
        -L "ROOT" \
        -n 16k \
        -f \
        "${CONFIG[ROOT_PART]}"

    # Mount root partition temporarily
    mount "${CONFIG[ROOT_PART]}" /mnt

    # Create subvolumes
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@cache
    btrfs subvolume create /mnt/@log

    # Unmount and remount with subvolumes
    cd /
    umount /mnt

    mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,ssd,subvol=@ "${CONFIG[ROOT_PART]}" /mnt

    # Create necessary directories
    mkdir -p /mnt/{home,var/cache,var/log,boot/efi}

    # Mount subvolumes
    mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,ssd,subvol=@home "${CONFIG[ROOT_PART]}" /mnt/home
    mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,ssd,subvol=@cache "${CONFIG[ROOT_PART]}" /mnt/var/cache
    mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,ssd,subvol=@log "${CONFIG[ROOT_PART]}" /mnt/var/log

    # Mount EFI partition
    mount "${CONFIG[EFI_PART]}" /mnt/boot/efi
}

# Base system installation function
function install_base_system() {
    info "Installing base system..."

    reflector --country India --age 6 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

    # Pacman configure for arch-iso
    sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
    sed -i '/^# Misc options/a DisableDownloadTimeout' /etc/pacman.conf
    sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
    sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf


    # Refresh package databases
    pacman -Syy

    local base_packages=(
        # Core System
        base base-devel
        linux-firmware linux-lts

        # Filesystem
        btrfs-progs
        dosfstools

        # Boot
        grub
        efibootmgr
        efitools

        # CPU & GPU Drivers
        amd-ucode
        mesa
        mesa-utils
        xf86-input-libinput
        xf86-video-amdgpu
        xf86-video-ati

        # X Window System server
        xorg

        # Network
        networkmanager
        networkmanager-openconnect
        networkmanager-openvpn
        networkmanager-pptp
        networkmanager-strongswan
        networkmanager-vpnc
        network-manager-sstp
        nm-connection-editor
        network-manager-applet
        wpa_supplicant
        dialog
        ufw-extras
        
        # Multimedia & Bluetooth
        bluez
        bluez-utils
        sof-firmware
        pipewire
        pipewire-pulse
        pipewire-alsa
        pipewire-jack
        wireplumber

        # Gnome
        arc-gtk-theme
        rhythmbox
        loupe
        evince
        file-roller
        nautilus
        sushi
        totem
        gdm
        gnome-calculator
        gnome-clocks
        gnome-console
        gnome-control-center
        gnome-disk-utility
        gnome-keyring
        gnome-nettool
        gnome-power-manager
        gnome-screenshot
        gnome-shell
        gnome-system-monitor
        gnome-terminal
        gnome-text-editor
        gnome-themes-extra
        gnome-tweaks
        gnome-usage
        gnome-weather
        gvfs
        gvfs-afc
        gvfs-gphoto2
        gvfs-mtp
        gvfs-nfs
        gvfs-smb
        xdg-desktop-portal-gnome
        xdg-desktop-portal
        xdg-user-dirs-gtk

        # Fonts
        noto-fonts
        noto-fonts-emoji
        ttf-dejavu
        ttf-liberation

        # Essential System Utilities
        kitty
        ethtool
        zstd
        zram-generator
        thermald
        git
        reflector
        pacutils
        nano
        neovim
        fastfetch
        snapper
        snap-pac
        xclip
        xcolor
        laptop-detect
        flatpak
        glances
        wget
        sshpass
        openssh
        nmap

        # Development-tool
        gcc
        gdb
        cmake
        clang
        npm
        nodejs
        docker
        docker-compose
        jupyterlab
        python
        python-virtualenv
        python-pip

        # User Utilities
        kdeconnect
        wine
        steam
        telegram-desktop
        libreoffice-fresh
    )
    pacstrap -K /mnt --needed "${base_packages[@]}"
}

# System configuration function
function configure_system() {
    info "Configuring system..."

    # Generate fstab
    genfstab -U /mnt >>/mnt/etc/fstab

    # Chroot and configure
    arch-chroot /mnt /bin/bash << EOF
    # Set timezone and clock
    ln -sf /usr/share/zoneinfo/${CONFIG[TIMEZONE]} /etc/localtime
    hwclock --systohc

    # Set locale
    echo "${CONFIG[LOCALE]} UTF-8" >> /etc/locale.gen
    locale-gen
    echo "LANG=${CONFIG[LOCALE]}" > /etc/locale.conf

    # Set Keymap
    echo "KEYMAP=us" > "/etc/vconsole.conf"

    # Set hostname
    echo "${CONFIG[HOSTNAME]}" > /etc/hostname

    # Configure hosts
    echo "127.0.0.1 localhost
127.0.1.1 ${CONFIG[HOSTNAME]}" > /etc/hosts

    # Set root password
    echo "root:${CONFIG[PASSWORD]}" | chpasswd

    # Create user
    useradd -m -G wheel -s /bin/bash ${CONFIG[USERNAME]}
    echo "${CONFIG[USERNAME]}:${CONFIG[PASSWORD]}" | chpasswd
    
    # Configure sudo
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
    mkinitcpio -P
EOF
}

function apply_customization() {

    arch-chroot /mnt /bin/bash << 'EOF'

    cat > "/etc/systemd/zram-generator.conf" << ZRAM
[zram0]
zram-size = ram * 2
compression-algorithm = zstd
priority = 100
ZRAM

    sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
    sed -i 's/^#Color/Color/' /etc/pacman.conf
    sed -i '/^# Misc options/a DisableDownloadTimeout\nILoveCandy' /etc/pacman.conf
    sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf

    systemctl enable \
    NetworkManager \
    bluetooth \
    thermald \
    fstrim.timer \
    docker \
    gdm

    # Configure Docker
    usermod -aG docker "$USER"
EOF

    pacman -Sy --noconfirm snapper snap-pac
    snapper -c root create-config /mnt/
    snapper -c home create-config /mnt/home

}

function main() {
    info "Starting Arch Linux installation script..."
    init_config

    # Main installation steps
    setup_disk
    setup_filesystems
    install_base_system
    configure_system
    apply_customization
    umount -R /mnt
    success "Installation completed! You can now reboot your system."
}

# Execute main function
main
