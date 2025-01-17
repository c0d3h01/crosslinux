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
    mkfs.fat -F32 "${CONFIG[EFI_PART]}"
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
    btrfs subvolume create /mnt/@swap
    btrfs subvolume create /mnt/@snapshots

    # Unmount and remount with subvolumes
    cd /
    umount /mnt

    mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,ssd,subvol=@ "${CONFIG[ROOT_PART]}" /mnt

    # Create necessary directories
    mkdir -p /mnt/{home,var/cache,var/log,boot/efi,.snapshots,swap}

    # Mount subvolumes
    mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,ssd,subvol=@home "${CONFIG[ROOT_PART]}" /mnt/home
    mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,ssd,subvol=@cache "${CONFIG[ROOT_PART]}" /mnt/var/cache
    mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,ssd,subvol=@log "${CONFIG[ROOT_PART]}" /mnt/var/log
    mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,ssd,subvol=@log "${CONFIG[ROOT_PART]}" /mnt/swap
    mount -o noatime,compress=zstd:1,space_cache=v2,discard=async,ssd,subvol=@snapshots "${CONFIG[ROOT_PART]}" /mnt/var/.snapshots

    # Mount EFI partition
    mount "${CONFIG[EFI_PART]}" /mnt/boot/efi

    # Create swapfile
    btrfs filesystem mkswapfile --size 6G /mnt/swap/swapfile
    swapon /mnt/swap/swapfile
}

# Base system installation function
function install_base_system() {
    info "Installing base system..."

    reflector --country India --age 6 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

    # Pacman configure for arch-iso
    sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
    sed -i '/^# Misc options/a DisableDownloadTimeout' /etc/pacman.conf
    sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf

    # Refresh package databases
    pacman -Syy

    local base_packages=(
        # Core System
        base base-devel
        linux-firmware 
        linux-lts linux-lts-headers

        # Filesystem
        btrfs-progs
        dosfstools

        # Boot
        grub
        efibootmgr
        efitools

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
        bind
        ufw
    
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
        loupe
        evince
        file-roller
        gdm
        gnome-settings-daemon
        gnome-session 
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
        gnome-themes-extra
        gnome-tweaks
        gnome-usage
        gst-plugins-good
        gst-plugins-base
        gvfs
        gvfs-afc
        gvfs-gphoto2
        gvfs-mtp
        gvfs-nfs
        gvfs-smb
        nautilus
        sushi
        totem
        xdg-desktop-portal-gnome
        xdg-user-dirs-gtk
        rhythmbox
        micro

        # Fonts
        noto-fonts
        noto-fonts-emoji
        ttf-dejavu
        ttf-liberation
        terminus-font

        # Essential System Utilities
        ibus-typing-booster
        dialog
        thermald
        git
        reflector
        pacutils
        neovim
        fastfetch
        snapper snap-pac
        xclip
        laptop-detect
        flatpak
        glances
        wget
        curl
        sshpass
        openssh
        nmap
        inxi

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
        kdeconnect
        discord
        wine
        steam
        zed
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

    echo '/swap/swapfile none swap defaults 0 0' >> /etc/fstab

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
