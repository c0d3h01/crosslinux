#!/usr/bin/env bash
#
# shellcheck disable=SC1078
# shellcheck disable=SC2162
# shellcheck disable=SC1079
# shellcheck disable=SC1009
# shellcehck disable=SC1072
# shellcheck disable=SC1073
# shellcheck disable=SC2046
#
# ==============================================================================
# Automated Arch Linux Installation Personal Setup Script
# ==============================================================================

set -euo pipefail

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
        [HOSTNAME]="archlinux"
        [USERNAME]="c0d3h01"
        [PASSWORD]="$PASSWORD"
        [TIMEZONE]="Asia/Kolkata"
        [LOCALE]="en_IN.UTF-8"
        [BTRFS_OPTS]="noatime,compress=zstd:1,ssd,space_cache=v2,discard=async,autodefrag"
    )
    CONFIG[EFI_PART]="${CONFIG[DRIVE]}p1"
    CONFIG[SWAP_PART]="${CONFIG[DRIVE]}p2"
    CONFIG[ROOT_PART]="${CONFIG[DRIVE]}p3"
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
        --new=2:0:+16G --typecode=2:8200 --change-name=2:"SWAP" \
        --new=3:0:0 --typecode=3:8300 --change-name=3:"ROOT" \
        "${CONFIG[DRIVE]}"

    # Reload the partition table
    partprobe "${CONFIG[DRIVE]}"
}

function setup_filesystems() {
    # Format partitions
    mkfs.fat -F32 "${CONFIG[EFI_PART]}"
    mkswap -L SWAP "${CONFIG[SWAP_PART]}"
    mkfs.btrfs -f "${CONFIG[ROOT_PART]}"

    # Enable swap
    swapon "${CONFIG[SWAP_PART]}"

    # Mount root partition temporarily
    mount "${CONFIG[ROOT_PART]}" /mnt

    # Create subvolumes
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@cache
    btrfs subvolume create /mnt/@log
    btrfs subvolume create /mnt/@snapshots

    # Unmount and remount with options
    umount /mnt
    mount -o "${CONFIG[BTRFS_OPTS]},subvol=@" "${CONFIG[ROOT_PART]}" /mnt

    # Create necessary directories
    mkdir -p /mnt/{home,var/cache,var/log,boot/efi,.snapshots}

    # Mount subvolumes
    mount -o "${CONFIG[BTRFS_OPTS]},subvol=@home" "${CONFIG[ROOT_PART]}" /mnt/home
    mount -o "${CONFIG[BTRFS_OPTS]},subvol=@cache" "${CONFIG[ROOT_PART]}" /mnt/var/cache
    mount -o "${CONFIG[BTRFS_OPTS]},subvol=@log" "${CONFIG[ROOT_PART]}" /mnt/var/log
    mount -o "${CONFIG[BTRFS_OPTS]},subvol=@snapshots" "${CONFIG[ROOT_PART]}" /mnt/.snapshots

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

    # Refresh package databases
    pacman -Syy

    local base_packages=(
        # Core System
        base base-devel
        linux-firmware
        linux linux-headers
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
        xf86-input-libinput
        xf86-video-amdgpu
        xorg-server
        xorg-xinit
        xorg-xrandr
        
        # Network
        ethtool
        iwd
        modemmanager
        net-tools
        netctl
        networkmanager
        nss-mdns
        usb_modeswitch
        whois
        wireless-regdb
        wpa_supplicant

        # General hardware
        lsscsi
        sg3_utils
        smartmontools
        usbutils
        zram-generator
        
        # Multimedia & Bluetooth
        bluez bluez-utils
        alsa-plugins
        alsa-utils
        gst-plugin-pipewire
        pipewire-alsa
        pipewire-jack
        pipewire-pulse
        rtkit
        wireplumber

        # Gnome
        adwaita-icon-theme
        loupe
        evince
        file-roller
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
        iptables-nft
        thermald
        git
        reflector
        pacutils
        vim
        fastfetch
        snapper
        xclip
        laptop-detect
        flatpak
        ufw-extras
        glances
        tlp tlp-rdw
        earlyoom
        irqbalance
 
        # User Utilities
        kdeconnect
        rhythmbox
        libreoffice-fresh
        firefox

        # Devtools
        wget
        gcc
        gdb
        cmake
        clang
        nodejs
        npm
        nmap
        yad
        jupyterlab
        rocm-hip-sdk
        rocm-opencl-sdk
        hip-runtime-amd
        hipblas
        rocm-cmake
        docker
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
    tee > "/etc/hosts" << 'HOST'
127.0.0.1 localhost
127.0.1.1  ${CONFIG[HOSTNAME]}

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
HOST

    # Set root password
    echo "root:${CONFIG[PASSWORD]}" | chpasswd

    # Create user
    useradd -m -G wheel -s /bin/bash ${CONFIG[USERNAME]}
    echo "${CONFIG[USERNAME]}:${CONFIG[PASSWORD]}" | chpasswd
    
    # Configure sudo
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch-GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
    mkinitcpio -P
EOF
}

# Performance optimization function
function apply_optimizations() {

    info "Applying system optimizations..."
    arch-chroot /mnt /bin/bash << 'EOF'

    sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
    sed -i 's/^#Color/Color/' /etc/pacman.conf
    sed -i '/^# Misc options/a DisableDownloadTimeout\nILoveCandy' /etc/pacman.conf
    sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf

    cat > "/etc/systemd/system/reflector.service" << 'REFS'
[Unit]
Description=Pacman mirrorlist update
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 300
ExecStart=/usr/bin/reflector --country India --age 6 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

[Install]
WantedBy=multi-user.target
REFS

    # Refresh package databases
    pacman -Syy --noconfirm

    cat > "/usr/lib/systemd/zram-generator.conf" << 'ZCONF'
[zram0] 
compression-algorithm = zstd
zram-size = ram * 2
swap-priority = 100
fs-type = swap
ZCONF

EOF
}

function snapper_config() {
    
    SWAP_OFFSET=$(filefrag -v /mnt/swap/swapfile | awk '/ 0:/ {print $4}' | cut -d '.' -f 1)
    sed -i "/^GRUB_CMDLINE_LINUX=/s|\"$|resume=/swap/swapfile resume_offset=$SWAP_OFFSET\"|" /mnt/etc/default/grub
    sed -i 's/^HOOKS=(.*)/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck resume)/' /mnt/etc/mkinitcpio.conf

    arch-chroot /mnt /bin/bash << 'EOF'

    snapper -c root create-config /
    snapper -c home create-config /home

    cat > /etc/snapper/configs/root << SNAPR
TIMELINE_CREATE=yes
TIMELINE_LIMIT_HOURLY=2
TIMELINE_LIMIT_DAILY=5
SNAPR

    cat > /etc/snapper/configs/home << SNAPH
TIMELINE_CREATE=yes
TIMELINE_LIMIT_HOURLY=1
TIMELINE_LIMIT_DAILY=5
SNAPH

    cat > /etc/systemd/system/boot-snapshot.service << BSNAP
[Unit]
Description=Create system snapshot after boot
After=multi-user.target

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 300
ExecStart=/usr/bin/snapper -c root create -d "Boot root snapshot"
ExecStart=/usr/bin/snapper -c home create -d "Boot home snapshot"

[Install]
WantedBy=multi-user.target
BSNAP

    grub-mkconfig -o /boot/grub/grub.cfg
    mkinitcpio -P
EOF
}

# Services configuration function
function configure_services() {
    info "Configuring services..."

    arch-chroot /mnt /bin/bash << 'EOF'

    # Enable system services
    systemctl enable NetworkManager
    systemctl enable bluetooth.service
    systemctl enable thermald
    systemctl enable fstrim.timer
    systemctl enable reflector
    systemctl enable docker
    systemctl enable gdm
    systemctl enable snapper-timeline.timer
    systemctl enable boot-snapshot.service

    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 1714:1764/udp
    ufw allow 1714:1764/tcp
    ufw enable
    systemctl enable ufw

    systemctl enable tlp.service
    systemctl enable earlyoom
    systemctl enable irqbalance
EOF
}

function archinstall() {
    info "Starting Arch Linux installation script..."
    init_config

    # Main installation steps
    setup_disk
    setup_filesystems
    install_base_system
    configure_system
    apply_optimizations
    snapper_config
    configure_services
    umount -R /mnt
    success "Installation completed! You can now reboot your system."
}

function install_zsh() {
    # Install required packages
    echo "Installing required packages..."
    sudo pacman -S --noconfirm zsh zsh-completions zsh-autosuggestions zsh-syntax-highlighting fzf tldr

    # Install Oh My Zsh
    echo "Installing Oh My Zsh..."
    if [ ! -d ~/.oh-my-zsh ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    # Create comprehensive .zshrc
    cat > ~/.zshrc << 'EOL'
# Path to your oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Set theme
ZSH_THEME="bira"

# Plugins
plugins=(
  git
  archlinux
  zsh-autosuggestions
  zsh-syntax-highlighting
  sudo
  colorize
  colored-man-pages
)

# Oh My Zsh source
source $ZSH/oh-my-zsh.sh

# Autosuggestions configuration
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=245"

# Additional useful aliases
alias update='sudo pacman -Syu'
alias install='sudo pacman -S'
alias remove='sudo pacman -Rns'
alias cleanup='sudo pacman -Rns $(pacman -Qtdq)'

# Enhanced history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE

# Auto completion
autoload -Uz compinit
compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' menu select

# Optional: Add fzf if installed
[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
[ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh
EOL

    # Install additional Oh My Zsh plugins
    echo "Installing additional Oh My Zsh plugins..."
    ZSH_CUSTOM=~/.oh-my-zsh/custom
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    fi

    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    fi

    # Change default shell to Zsh
    echo "chsh -s $(which zsh)"
    echo "Please restart your session after steps."
}

function remove_zsh() {
uninstall_oh_my_zsh 
# Remove configuration files
rm -rf ~/.zshrc
rm -rf ~/.zsh*
rm -rf ~/.oh-my-zsh
rm -rf ~/.cache/zsh
rm -rf ~/.local/share/zsh

# Revert to default shell
chsh -s $(which bash)

# Remove Zsh packages
sudo pacman -Rns zsh zsh-completions zsh-autosuggestions zsh-syntax-highlighting

echo "Zsh and related configurations have been removed."
}

# User environment setup function
function usrsetup() {

# Check if yay is already installed
if command -v yay &> /dev/null; then
    echo "yay is already installed. Skipping installation."
else
    # Clone yay-bin from AUR
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -si
    cd ..
    rm -rf yay-bin
fi

    # Install user applications via yay
    yay -S --noconfirm --nodeps --nodebug \
        telegram-desktop-bin \
        vesktop-bin \
        youtube-music-bin \
        zoom \
        visual-studio-code-bin \
        vscodium-bin \
        wine \
        gnome-shell-extension-dash-to-dock \
        gpu-screen-recorder-gtk \
        notion-desktop-git \
        github-desktop-bin \
        docker-desktop \
        postman-bin

    # Configure Docker
    sudo usermod -aG docker "$USER"

    git config --global user.name "c0d3h01"
    git config --global user.email "harshalsawant2004h@gmail.com"
    ssh-keygen -t ed25519 -C "harshalsawant2004h@gmail.com" -f ~/.ssh/id_ed25519 -N ""
}

# Main execution function
function main() {
    case "$1" in
    "--install" | "-i")
        archinstall
        ;;

    "--setup" | "-s")
        usrsetup
        ;;

    "--zsh-i" | "-iz")
        install_zsh
        ;;

    "--zsh-r" | "-rz")
        remove_zsh
        ;;

    "--help" | "-h")
        show_help
        ;;

    "")
        echo "Error: No arguments provided"
        show_help
        exit 1
        ;;
    *)
        echo "Error: Unknown option: $1"
        show_help
        exit 1
        ;;
    esac

}

function show_help() {
    tee <<EOF
Usage: $(basename "$0") [OPTION]

Options:
    -i, --install (Arch install)
    -s, --setup (Arch usr setup)
    -iz, --zsh-i (Install ZSH)
    -rz, --zsh-r (Remove ZSH)
    -h, --help
EOF
}

# chown -R harsh:harsh android-sdk
# 

# Execute main function
main "$@"
