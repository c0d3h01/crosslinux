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
    local drive="${CONFIG[DRIVE]}"
    local efi_part="${CONFIG[EFI_PART]}"
    local boot_part="${CONFIG[BOOT_PART]}"
    local root_part="${CONFIG[ROOT_PART]}"

    # Wipe and prepare the disk
    wipefs -af "$drive"
    sgdisk --zap-all "$drive"

    # Create fresh GPT
    sgdisk --clear "$drive"

    # Create partitions
    sgdisk \
        --new=1:0:+512M --typecode=1:ef00 --change-name=1:"EFI" \
        --new=2:0:+1G --typecode=2:8300 --change-name=2:"BOOT" \
        --new=3:0:0 --typecode=3:8300 --change-name=3:"ROOT" \
        "$drive"

    # Reload the partition table
    partprobe "$drive"
    sleep 2
}

function setup_filesystems() {
    local efi_part="${CONFIG[EFI_PART]}"
    local boot_part="${CONFIG[BOOT_PART]}"
    local root_part="${CONFIG[ROOT_PART]}"

    # Format partitions
    mkfs.fat -F32 "$efi_part"
    mkfs.ext4 -L "BOOT" "$boot_part"
    mkfs.btrfs -L "ROOT" -n 16k -f "$root_part"

    # Mount root partition temporarily
    mount "$root_part" /mnt

    # Create subvolumes
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home

    # Unmount and remount with subvolumes
    umount /mnt
    mount -o "subvol=@,compress=zstd:1,discard=async" "$root_part" /mnt

    # Create necessary directories
    mkdir -p /mnt/home /mnt/boot /mnt/boot/efi

    # Mount EFI partition first
    mount "$efi_part" /mnt/boot/efi

    # Mount boot partition
    mount "$boot_part" /mnt/boot

    # Mount home subvolume
    mount -o "subvol=@home,compress=zstd:1,discard=async" "$root_part" /mnt/home
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
        linux linux-headers
        linux-lts linux-lts-headers

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
        ufw # Firewall
    
        # Multimedia & Bluetooth
        bluez
        bluez-utils
        pipewire
        pipewire-pulse
        pipewire-alsa
        pipewire-jack
        wireplumber
        gstreamer
        gst-plugins-base
        gst-plugins-good
        gst-plugins-bad
        gst-plugins-ugly

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
        zram-generator
        bc
        ibus-typing-booster
        thermald
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

function post_install() {
    arch-chroot /mnt /bin/bash << EOF
    cat > "/usr/lib/systemd/zram-generator.conf" << ZRAM
[zram0] 
compression-algorithm = zstd
zram-size = ram
swap-priority = 100
fs-type = swap
ZRAM

    # Install AUR helper (yay)
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm

    # Install AUR packages
    yay -S --noconfirm \
        yaru-gtk-theme \
        visual-studio-code-bin

    # Configure Flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    # Set default browser (Firefox)
    xdg-settings set default-web-browser firefox.desktop

    # Set default terminal (GNOME Terminal)
    gsettings set org.gnome.desktop.default-applications.terminal exec 'gnome-terminal'

    sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
    sed -i 's/^#Color/Color/' /etc/pacman.conf
    sed -i '/^# Misc options/a DisableDownloadTimeout\nILoveCandy' /etc/pacman.conf
    sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf

    # Configure Docker
    usermod -aG docker "${CONFIG[USERNAME]}"

    # Enable additional services
    systemctl enable \
    NetworkManager \
    bluetooth \
    thermald \
    fstrim.timer \
    gdm \
    cups.service \
    systemd-timesyncd \
    snapper-timeline.timer snapper-cleanup.timer \
    swap-create@zram0.service
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
    post_install
    umount -R /mnt
    success "Installation completed! You can now reboot your system."
}

# Execute main function
main
