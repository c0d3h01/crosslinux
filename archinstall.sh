#!/usr/bin/env bash
#
# shellcheck disable=SC2162
#
# ==============================================================================
# Automated Arch Linux Installation Personal Setup Script
# ==============================================================================

set -exuo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
        [HOSTNAME]="localhost"
        [USERNAME]="harshal"
        [PASSWORD]="$PASSWORD"
        [TIMEZONE]="Asia/Kolkata"
        [LOCALE]="en_IN.UTF-8"
        [BTRFS_OPTS]="noatime,compress=zstd:1,ssd,space_cache=v2,discard=async,autodefrag"
    )
    CONFIG[EFI_PART]="${CONFIG[DRIVE]}p1"
    CONFIG[ROOT_PART]="${CONFIG[DRIVE]}p2"
}

# Logging functions
function info() { echo -e "${BLUE}INFO: $* ${NC}"; }
function warn() { echo -e "${YELLOW}WARN: $* ${NC}"; }
function error() {
    echo -e "${RED}ERROR: $* ${NC}" >&2
    exit 1
}
function success() { echo -e "${GREEN}SUCCESS:$* ${NC}"; }

function setup_disk() {
    # Wipe and prepare the disk
    sgdisk --zap-all "${CONFIG[DRIVE]}"

    # Create partitions
    sgdisk \
        --new=1:0:+512M --typecode=1:ef00 --change-name=1:"EFI" \
        --new=2:0:0 --typecode=2:8300 --change-name=2:"ROOT" \
        "${CONFIG[DRIVE]}"

    # Reload the partition table
    partprobe "${CONFIG[DRIVE]}"
}

function setup_filesystems() {
    # Format partitions
    mkfs.fat -F32 "${CONFIG[EFI_PART]}"
    mkfs.btrfs -f "${CONFIG[ROOT_PART]}"

    # Mount root partition temporarily
    mount "${CONFIG[ROOT_PART]}" /mnt

    # Create subvolumes
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@cache
    btrfs subvolume create /mnt/@log
    btrfs subvolume create /mnt/@swap

    # Unmount and remount with options
    umount /mnt
    mount -o "${CONFIG[BTRFS_OPTS]},subvol=@" "${CONFIG[ROOT_PART]}" /mnt

    # Create necessary directories
    mkdir -p /mnt/{home,var/cache,var/log,boot/efi,swap}

    # Mount subvolumes
    mount -o "${CONFIG[BTRFS_OPTS]},subvol=@home" "${CONFIG[ROOT_PART]}" /mnt/home
    mount -o "${CONFIG[BTRFS_OPTS]},subvol=@cache" "${CONFIG[ROOT_PART]}" /mnt/var/cache
    mount -o "${CONFIG[BTRFS_OPTS]},subvol=@log" "${CONFIG[ROOT_PART]}" /mnt/var/log
    mount -o "${CONFIG[BTRFS_OPTS]},subvol=@swap" "${CONFIG[ROOT_PART]}" /mnt/swap

    # Mount EFI partition
    mount "${CONFIG[EFI_PART]}" /mnt/boot/efi

    btrfs filesystem mkswapfile --size 6g --uuid clear /mnt/swap/swapfile
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
        linux-firmware linux-lts

        # Filesystem
        btrfs-progs
        dosfstools

        # Boot
        grub
        efibootmgr

        # CPU & GPU Drivers
        amd-ucode
        xorg-server
        xorg-xinit
        xf86-input-libinput
        xf86-video-amdgpu
        
        # Network
        networkmanager
        wpa_supplicant
        dialog
        
        # Multimedia & Bluetooth
        bluez
        bluez-utils
        pipewire
        pipewire-pulse
        pipewire-alsa
        pipewire-jack
        wireplumber

        # Gnome
        rhythmbox
        loupe
        evince
        file-roller
        gdm
        gnome-browser-connector
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
        gnome-terminal
        gnome-text-editor
        gnome-themes-extra
        gnome-tweaks
        gnome-calendar
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
        xdg-desktop-portal
        xdg-user-dirs-gtk

        # Fonts
        noto-fonts
        noto-fonts-emoji
        ttf-dejavu
        ttf-liberation

        # Essential System Utilities
        zstd
        zram-generator
        thermald
        git
        reflector
        pacutils
        nano
        vim
        fastfetch
        timeshift
        snapper snap-pac
        xclip
        laptop-detect
        flatpak
        gufw
        glances
        earlyoom
        ananicy-cpp

        # User Utilities
        kdeconnect
        libreoffice-fresh
        firefox
        wget
        gcc
        gdb
        cmake
        clang
        nodejs
        sshpass
        openssh
        rsync
        npm
        nmap
        jupyterlab
        docker docker-compose
        python
        python-virtualenv
        python-pip
        python-scikit-learn
        python-numpy
        python-pandas
        python-scipy
        python-matplotlib
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

    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch-GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
EOF
}

function apply_customization() {

    arch-chroot /mnt /bin/bash << 'EOF'

    # Get the offset
    SWAP_OFFSET=$(filefrag -v /swap/swapfile | awk '/ 0:/ {print $4}' | cut -d '.' -f 1)

    RESUME_DEVICE=$(df /swap | awk 'NR==2 {print $1}')

    # Modify GRUB with the correct device path
    sed -i "/^GRUB_CMDLINE_LINUX=/s|\"$|resume=$RESUME_DEVICE resume_offset=$SWAP_OFFSET\"|" /etc/default/grub

    echo "/swap/swapfile none swap defaults,pri=100 0 0" >> /etc/fstab

    grub-mkconfig -o /boot/grub/grub.cfg
    mkinitcpio -P

    sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
    sed -i 's/^#Color/Color/' /etc/pacman.conf
    sed -i '/^# Misc options/a DisableDownloadTimeout\nILoveCandy' /etc/pacman.conf
    sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf

    cat > "/usr/lib/systemd/zram-generator.conf" << ZRAM
[zram0]
compression-algorithm = zstd                
zram-size = ram
swap-priority = 100
fs-type = swap
ZRAM

    snapper -c root create-config /
    snapper -c home create-config /home

    cat > "/etc/snapper/configs/root" << SNAPR
TIMELINE_CREATE=yes
TIMELINE_LIMIT_HOURLY=2
TIMELINE_LIMIT_DAILY=5
SNAPR

    cat > "/etc/snapper/configs/home" << SNAPH
TIMELINE_CREATE=yes
TIMELINE_LIMIT_HOURLY=1
TIMELINE_LIMIT_DAILY=5
SNAPH

    systemctl enable \
    NetworkManager \
    bluetooth \
    thermald \
    fstrim.timer \
    reflector \
    docker \
    gdm \
    earlyoom \
    ananicy-cpp

    # systemctl --user enable --now \
    # pipewire.service \
    # pipewire-pulse.service \
    # wireplumber.service

    # Configure Docker
    usermod -aG docker "$USER"

    git config --global user.name "c0d3h01"
    git config --global user.email "harshalsawant2004h@gmail.com"
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
