#!/usr/bin/env bash
#
# shellcheck disable=SC2162
#
# ==============================================================================
# -*- Automated Arch Linux Installation Personal Setup Script -*-
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
        [HOSTNAME]="Quantum"
        [USERNAME]="harshal"
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
    mkfs.btrfs -L "ROOT" -n 16k -f "${CONFIG[ROOT_PART]}"

    # Mount root partition temporarily
    mount "${CONFIG[ROOT_PART]}" /mnt

    # Create subvolumes
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@log
    btrfs subvolume create /mnt/@cache

    # Unmount and remount with subvolumes
    umount /mnt
    mount -o "subvol=@,compress=zstd:1,discard=async" "${CONFIG[ROOT_PART]}" /mnt

    # Create necessary directories
    mkdir -p /mnt/home /mnt/boot/efi /mnt/var/log /mnt/var/cache

    # Mount EFI and home subvolumes
    mount "${CONFIG[EFI_PART]}" /mnt/boot/efi
    mount -o "subvol=@home,compress=zstd:1,discard=async" "${CONFIG[ROOT_PART]}" /mnt/home
    mount -o "subvol=@cache,compress=zstd:1,discard=async" "${CONFIG[ROOT_PART]}" /mnt/var/cache
    mount -o "subvol=@log,compress=zstd:1,discard=async" "${CONFIG[ROOT_PART]}" /mnt/var/log
}

# Base system installation function
function install_base_system() {
    info "Installing base system..."
    
    info "Configuring pacman for iso installaton..."
    # Pacman configure for arch-iso
    sed -i 's/^#ParallelDownloads/ParallelDownloads/' "/etc/pacman.conf"
    sed -i '/^# Misc options/a DisableDownloadTimeout' "/etc/pacman.conf"

    # Refresh package databases
    pacman -Syy

    info "Running reflctor..."
    reflector --country India --age 7 --protocol https --sort rate --save "/etc/pacman.d/mirrorlist"

    local base_packages=(
        # -*- Core System -*-
        base # Minimal package set to define a basic Arch Linux installation
        base-devel # Basic tools to build Arch Linux packages
        linux-firmware # Firmware files for Linux
        linux # The Linux kernel and modules
        linux-headers # Headers and scripts for building modules for the Linux kernel
        linux-lts  # The LTS Linux kernel and modules
        linux-lts-headers # Headers and scripts for building modules for the LTS Linux kernel

        # -*- Filesystem -*-
        btrfs-progs # Btrfs filesystem utilities

        # -*- Boot -*-
        grub # GNU GRand Unified Bootloader
        efibootmgr # Linux user-space application to modify the EFI Boot Manager

        # -*- CPU & GPU Drivers -*-
        amd-ucode # Microcode update image for AMD CPUs
        libva-mesa-driver # mesa with 32bit driver
        mesa # Open-source OpenGL drivers
        vulkan-radeon # Open-source Vulkan driver for AMD GPUs
        xf86-video-amdgpu # X.org amdgpu video driver
        xf86-video-ati # X.org ati video driver
        xorg-server # Xorg X server
        xorg-xinit # X.Org initialisation program

        # -*- Network & firewall -*-
        networkmanager
        ufw # Uncomplicated and easy to use CLI tool for managing a netfilter firewall
        fail2ban # Bans IPs after too many failed authentication attempts
    
        # -*- Multimedia & Bluetooth -*-
        bluez # Daemons for the bluetooth protocol stack
        bluez-utils # Development and debugging utilities for the bluetooth protocol stack
        pipewire # Low-latency audio/video router and processor
        pipewire-pulse # Low-latency audio/video router and processor - PulseAudio replacement
        pipewire-alsa # Low-latency audio/video router and processor - ALSA configuration
        pipewire-jack # Low-latency audio/video router and processor - JACK replacement
        wireplumber # Session / policy manager implementation for PipeWire
        gstreamer # Multimedia graph framework - core
        gst-libav # Multimedia graph framework - libav plugin
        gst-plugins-base # Multimedia graph framework - base plugins
        gst-plugins-good # Multimedia graph framework - good plugins
        gst-plugins-bad # Multimedia graph framework - bad plugins
        gst-plugins-ugly # Multimedia graph framework - ugly plugins

        # -*- Desktop environment [ Gnome ] -*-
        nautilus # Default file manager for GNOME
        sushi # A quick previewer for Nautilus
        totem # Movie player for the GNOME desktop based on GStreamer
        loupe # A simple image viewer for GNOME
        evince # Document viewer (PDF, PostScript, XPS, djvu, dvi, tiff, cbr, cbz, cb7, cbt)
        file-roller # Create and modify archives
        rhythmbox # Music playback and management application
        micro # Modern and intuitive terminal-based text editor
        gdm # Display manager and login screen
        gnome-settings-daemon # GNOME Settings Daemon
        gnome-browser-connector # Native browser connector for integration with extensions.gnome.org
        gnome-backgrounds # Background images and data for GNOME
        gnome-session # The GNOME Session Handler
        gnome-calculator # GNOME Scientific calculator
        gnome-clocks # gnome-clocks
        gnome-control-center # GNOME's main interface to configure various aspects of the desktop
        gnome-disk-utility # Disk Management Utility for GNOME
        gnome-calendar # Calendar application
        gnome-keyring # Stores passwords and encryption keys
        gnome-nettool # Graphical interface for various networking tools
        gnome-power-manager # System power information and statistics
        gnome-screenshot # Take pictures of your screen
        gnome-shell # Next generation desktop shell
        gnome-terminal # The GNOME Terminal Emulator
        gnome-themes-extra # Extra Themes for GNOME Applications
        gnome-tweaks # Graphical interface for advanced GNOME 3 settings (Tweak Tool)
        gnome-logs # A log viewer for the systemd journal
        gvfs # Virtual filesystem implementation for GIO
        gvfs-afc # Virtual filesystem implementation for GIO - AFC backend (Apple mobile devices)
        gvfs-gphoto2 # Virtual filesystem implementation for GIO - gphoto2 backend (PTP camera, MTP media player)
        gvfs-mtp # Virtual filesystem implementation for GIO - MTP backend (Android, media player)
        gvfs-nfs # Virtual filesystem implementation for GIO - NFS backend
        gvfs-smb # Virtual filesystem implementation for GIO - SMB/CIFS backend (Windows file sharing)
        xdg-desktop-portal # Desktop integration portals for sandboxed apps
        xdg-desktop-portal-gnome # Backend implementation for xdg-desktop-portal for the GNOME desktop environment
        xdg-user-dirs-gtk # Creates user dirs and asks to relocalize them

        # -*- Fonts -*-
        noto-fonts # Google Noto TTF fonts
        noto-fonts-cjk # Google Noto CJK fonts
        noto-fonts-emoji # Google Noto emoji fonts
        ttf-fira-code # Monospaced font with programming ligatures
        ttf-dejavu # Font family based on the Bitstream Vera Fonts with a wider range of characters
        ttf-liberation # Font family which aims at metric compatibility with Arial, Times New Roman, and Courier New


        # -*- Essential System Utilities -*-
        ghostty # Fast, native, feature-rich terminal emulator pushing modern features
        zram-generator # Systemd unit generator for zram devices
        ibus # Intelligent input bus for Linux/Unix
        ibus-typing-booster # Predictive input method for the IBus platform
        thermald # The Linux Thermal Daemon program from 01.org
        git # the fast distributed version control system
        reflector # Filter the latest Pacman mirror list.
        pacutils # Helper tools for libalpm
        neovim # Fork of Vim aiming to improve user experience, plugins, and GUIs
        xclip # Command line interface to the X11 clipboard
        nano # Pico editor clone with enhancements
        fastfetch # A feature-rich and performance oriented neofetch like system information tool
        snapper # A tool for managing BTRFS and LVM snapshots. It can create, diff and restore snapshots and provides timelined auto-snapping.
        snap-pac # Pacman hooks that use snapper to create pre/post btrfs snapshots like openSUSE's YaST
        flatpak # Linux application sandboxing and distribution framework (formerly xdg-app)
        glances # CLI curses-based monitoring tool
        wget # Network utility to retrieve files from the Web
        curl # command line tool and library for transferring data with URLs
        bat # Cat clone with syntax highlighting and git integration
        sshpass # Fool ssh into accepting an interactive password non-interactively
        openssh # SSH protocol implementation for remote login, command execution and file transfer
        inxi # Full featured CLI system information tool
        zsh # A very advanced and programmable command interpreter (shell) for UNIX
        cups # OpenPrinting CUPS - daemon package
        ccache # Compiler cache that speeds up recompilation by caching previous compilations
        acpid # A daemon for delivering ACPI power management events with netlink support
        apparmor # Mandatory Access Control (MAC) using Linux Security Module (LSM)
        meson # High productivity build system
        busybox # Utilities for rescue and embedded systems
        dracut # An event driven initramfs infrastructure
        yank # Copy terminal output to clipboard

        # -*- Development-tool -*-
        gcc # The GNU Compiler Collection - C and C++ frontends
        cmake # A cross-platform open-source make system
        clang # C language family frontend for LLVM
        npm # JavaScript package manager
        nodejs # Evented I/O for V8 javascript
        docker # Pack, ship and run any application as a lightweight container
        docker-compose # Fast, isolated development environments using Docker
        jdk-openjdk # OpenJDK Java 23 development kit
        jupyterlab # JupyterLab computational environment
        python # The Python programming language
        python-virtualenv # Virtual Python Environment builder
        python-pip # The PyPA recommended tool for installing Python packages
        pycharm-community-edition # Python IDE for Professional Developers

        # -*- User Utilities -*-
        firefox # Fast, Private & Safe Web Browser
        discord # All-in-one voice and text chat for gamers
        transmission-gtk # Fast, easy, and free BitTorrent client (GTK+ GUI)
        telegram-desktop # Official Telegram Desktop client
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
    # Set timezone and synchronize hardware clock
    # Links the specified timezone from zoneinfo to localtime
    ln -sf /usr/share/zoneinfo/${CONFIG[TIMEZONE]} "/etc/localtime"
    # Synchronizes system time with hardware clock, using UTC
    hwclock --systohc
    
    # Configure system locale
    # Add specified locale to locale generation file
    echo "${CONFIG[LOCALE]} UTF-8" >> "/etc/locale.gen"
    # Generate locale configurations
    locale-gen
    # Set default language configuration
    echo "LANG=${CONFIG[LOCALE]}" > "/etc/locale.conf"
    
    # Set keyboard layout for virtual console
    echo "KEYMAP=us" > "/etc/vconsole.conf"
    
    # Set system hostname
    echo "${CONFIG[HOSTNAME]}" > "/etc/hostname"
    
    # Configure hosts file for network resolution
    # Sets localhost and system-specific hostname mappings
    cat > "/etc/hosts" << HOSTS
# Standard localhost entries
127.0.0.1       localhost
::1             localhost
127.0.1.1       ${CONFIG[HOSTNAME]}.localdomain ${CONFIG[HOSTNAME]}
HOSTS

    # Set root password using chpasswd (securely)
    echo "root:${CONFIG[PASSWORD]}" | chpasswd

    # Create new user account
    # -m creates home directory
    # -G adds user to wheel group (for sudo access)
    # -s sets default shell to bash
    useradd -m -G wheel -s /bin/bash ${CONFIG[USERNAME]}
    # Set user password
    echo "${CONFIG[USERNAME]}:${CONFIG[PASSWORD]}" | chpasswd
    
    # Enable sudo access for wheel group members
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' "/etc/sudoers"
    
    # Install GRUB bootloader for UEFI systems
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
    # Generate GRUB configuration file
    grub-mkconfig -o /boot/grub/grub.cfg

    cat > "/etc/dracut.conf.d/dracut.conf" << DRACUT
compress="zstd"
compress_o="-1"
hostonly="yes"
hostonly_cmdline="yes"
add_drivers+=" amdgpu radeon nvme r8169 nvme-core ahci sd_mod usb_storage "
filesystems+=" btrfs vfat ext4 "
add_dracutmodules+=" systemd systemd-initrd bash kernel-modules rootfs-block "
early_microcode="yes"
omit_dracutmodules+=" plymouth biosdevname fcoe fcoe-uefi nbd network-legacy network-manager "
DRACUT

    # Regenerate initramfs for all kernels
    # mkinitcpio -P
    dracut -f --regenerate-all
EOF
}

function coustom_configuration() {
    arch-chroot /mnt /bin/bash << EOF

    # Create zram configuration file for systemd zram generator
    # This enables compressed RAM-based swap for improved system performance
    cat > "/usr/lib/systemd/zram-generator.conf" << ZRAM
[zram0]
compression-algorithm = zstd
zram-size = ram
swap-priority = 100
fs-type = swap
ZRAM

    # Enable parallel downloads in pacman to speed up package retrieval
    # This allows simultaneous downloads of multiple packages
    sed -i 's/^#ParallelDownloads/ParallelDownloads/' "/etc/pacman.conf"

    # Enable color output in pacman for better readability of package management logs
    sed -i 's/^#Color/Color/' "/etc/pacman.conf"

    # Add two special configurations after the "Misc options" section:
    # 1. DisableDownloadTimeout prevents pacman from timing out during slow downloads
    # 2. ILoveCandy adds a fun pacman animation during package downloads
    sed -i '/^# Misc options/a DisableDownloadTimeout\nILoveCandy' "/etc/pacman.conf"

    # Uncomment and enable the multilib repository
    # This allows installation of 32-bit packages on 64-bit systems
    # Useful for compatibility and running certain legacy applications
    sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' "/etc/pacman.conf"

    # Configure Docker
    usermod -aG docker "${CONFIG[USERNAME]}"

    # Set zsh as default shell for the user
    chsh -s /bin/zsh ${CONFIG[USERNAME]}

    # Configure Flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    # Configure Snapper
    snapper -c root create-config /
    snapper -c home create-config /home

    # Enable additional services
    systemctl enable \
    NetworkManager \
    bluetooth \
    thermald \
    fstrim.timer \
    gdm \
    cups.service \
    dbus \
    lm_sensors \
    apparmor \
    fail2ban \
    avahi-daemon \
    docker \
    systemd-timesyncd \
    snapper-timeline.timer snapper-cleanup.timer

    systemctl --user enable --now pipewire wireplumber

    # Enable UFW with basic rules
    ufw allow ssh
    ufw enable
    ufw allow 1714:1764/udp
    ufw allow 1714:1764/tcp

    # Install chaotic-aur repo
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com --noconfirm
    pacman-key --lsign-key 3056513887B78AEB --noconfirm
    pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' --noconfirm
    pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm
    sed -i '/^\[chaotic-aur\]/a Include = /etc/pacman.d/chaotic-mirrorlist' /etc/pacman.conf

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
    coustom_configuration

    read -p "Installation complete. Would you like to unmount now? (y/n): " UNMOUNT
    if [[ $UNMOUNT =~ ^[Yy]$ ]]; then
        umount -R /mnt
    fi

    success "Installation completed! You can now reboot your system."
    read -p "Reboot now? (y/n): " REBOOT
    if [[ $REBOOT =~ ^[Yy]$ ]]; then
        reboot
    fi
}

# Execute main function
main
