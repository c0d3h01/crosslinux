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
        [HOSTNAME]="archlinux"
        [USERNAME]="c0d3h01"
        [PASSWORD]="$PASSWORD"
        [TIMEZONE]="Asia/Kolkata"
        [LOCALE]="en_IN.UTF-8"
    )
    CONFIG[EFI_PART]="${CONFIG[DRIVE]}p1"
    CONFIG[BOOT_PART]="${CONFIG[DRIVE]}p2"
    CONFIG[ROOT_PART]="${CONFIG[DRIVE]}p3"
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
        --new=1:0:+512M --typecode=1:ef00 --change-name=1:"efi" \
        --new=2:0:+1G --typecode=2:8300 --change-name=2:"boot" \
        --new=3:0:0 --typecode=3:8300 --change-name=3:"root" \
        "${CONFIG[DRIVE]}"

    # Reload the partition table
    partprobe "${CONFIG[DRIVE]}"
    sleep 2
}

function setup_filesystems() {
    # Format partitions
    mkfs.fat -F32 "${CONFIG[EFI_PART]}"
    mkfs.ext4 -L "BOOT" "${CONFIG[BOOT_PART]}"
    mkfs.btrfs -L "ROOT" -n 16k -f "${CONFIG[ROOT_PART]}"

    # Mount root partition temporarily
    mount "${CONFIG[ROOT_PART]}" /mnt

    # Create subvolumes
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home

    # Unmount and remount with subvolumes
    umount /mnt
    mount -o "subvol=@,compress=zstd:1,discard=async" "${CONFIG[ROOT_PART]}" /mnt

    # Create necessary directories
    mkdir -p /mnt/home /mnt/boot

    # Mount subvolumes
    mount -o "subvol=@home,compress=zstd:1,discard=async" "${CONFIG[ROOT_PART]}" /mnt/home
    mount "${CONFIG[BOOT_PART]}" /mnt/boot
    
    mkdir -p /mnt/boot/efi
    mount "${CONFIG[EFI_PART]}" /mnt/boot/efi
}

# Base system installation function
function install_base_system() {
    info "Installing base system..."

    info "Running reflctor..."
    reflector --country India --age 7 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    
    info "Configuring pacman for iso installaton..."
    # Pacman configure for arch-iso
    sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
    sed -i '/^# Misc options/a DisableDownloadTimeout' /etc/pacman.conf

    # Refresh package databases
    pacman -Syy

    local base_packages=(
        # Core System
        base
        base-devel
        linux-firmware
        linux-lts

        # Filesystem
        btrfs-progs
        dosfstools

        # Boot
        grub
        efibootmgr

        # CPU & GPU Drivers
        amd-ucode
        libva-mesa-driver
        mesa
        vulkan-radeon
        xf86-video-amdgpu
        xf86-video-ati
        xorg-server
        xorg-xinit

        # Network
        networkmanager
        ufw
    
        # Multimedia & Bluetooth
        bluez
        bluez-utils
        pipewire
        pipewire-pulse
        pipewire-alsa
        pipewire-jack
        wireplumber

        # Gnome
        # AUR - yaru-gtk-theme yaru-icon-theme
        adwaita-icon-theme
        adwaita-cursors
        sushi
        totem
        loupe
        evince
        file-roller
        rhythmbox
        micro
        nautilus
        gdm
        power-profiles-daemon
        gnome-settings-daemon
        gnome-backgrounds
        gnome-session 
        gnome-calculator
        gnome-clocks
        gnome-control-center
        gnome-disk-utility
        gnome-keyring
        gnome-nettool
        gnome-power-manager
        gnome-screenshot
        gnome-shell
        gnome-terminal
        gnome-tweaks
        gnome-logs
        gvfs
        gvfs-afc
        gvfs-gphoto2
        gvfs-mtp
        gvfs-nfs
        gvfs-smb
        xdg-desktop-portal
        xdg-desktop-portal-gnome
        xdg-user-dirs-gtk

        # Fonts
        noto-fonts
        noto-fonts-emoji
        ttf-fira-code

        # Essential System Utilities
        bc
        ibus-typing-booster
        git
        reflector
        pacutils
        neovim
        fastfetch
        snapper
        snap-pac
        flatpak
        glances
        wget
        curl
        sshpass
        openssh
        nmap
        inxi
        zsh
        cups
        system-config-printer
        ccache
        bleachbit
        neovim
        python-neovim

        # Development-tool
        gcc
        gdb
        cmake
        clang
        npm
        nodejs
        docker
        docker-compose
        openjdk-src
        jupyterlab
        python
        python-virtualenv
        python-pip

        # User Utilities
        firefox
        discord
        transmission-gtk
        telegram-desktop
    )
    pacstrap -K /mnt --needed "${base_packages[@]}"
}

function create_swap() {
    btrfs subvolume create /swap
    btrfs filesystem mkswapfile --size 8g --uuid clear /swap/swapfile
    swapon /swap/swapfile
    echo "/swap/swapfile none swap defaults 0 0" > "/etc/fstab"
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

    sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
    sed -i 's/^#Color/Color/' /etc/pacman.conf
    sed -i '/^# Misc options/a DisableDownloadTimeout\nILoveCandy' /etc/pacman.conf
    sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf

    # Configure Docker
    usermod -aG docker "${CONFIG[USERNAME]}"

    # Snapper configuration for Btrfs
    # snapper -c root create-config /
    # snapper -c home create-config /home
    # chown -R :wheel /etc/snapper/configs/
    # chmod 750 /etc/snapper/configs/

    # echo "YAYFLAGS=\"--mflags=-j$(nproc)\"" >> ~/.zshrc

    # Enable additional services
    systemctl enable NetworkManager
    systemctl enable bluetooth
    systemctl enable fstrim.timer
    systemctl enable gdm
    systemctl enable cups.service
    systemctl enable systemd-timesyncd
    systemctl enable snapper-timeline.timer snapper-cleanup.timer
    systemctl enable ufw
    systemctl enable swap-create@zram0.service
EOF
}

function main() {
    info "Starting Arch Linux installation script..."
    init_config

    # Main installation steps
    setup_disk
    setup_filesystems
    install_base_system
    create_swap
    configure_system
    umount -R /mnt
    success "Installation completed! You can now reboot your system."
}

# Execute main function
main
