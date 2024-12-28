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
        [HOSTNAME]="world"
        [USERNAME]="harsh"
        [PASSWORD]="$PASSWORD"
        [TIMEZONE]="Asia/Kolkata"
        [LOCALE]="en_IN.UTF-8"
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

# Disk preparation function
function setup_disk() {    
    # Safety confirmation
    read -p "WARNING: This will erase ${CONFIG[DRIVE]}. Continue? (y/N)" -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && error "Operation cancelled by user"

    # Disk preparation
    sgdisk --zap-all "${CONFIG[DRIVE]}"
    sgdisk --clear "${CONFIG[DRIVE]}"
    
    # Alignment
    sgdisk --set-alignment=4096 "${CONFIG[DRIVE]}"

    # Minimalist, partitioning
    sgdisk --new=1:0:+1G \
        --typecode=1:ef00 \
        --change-name=1:"EFI" \
        --new=2:0:0 \
        --typecode=2:8300 \
        --change-name=2:"ROOT" \
        --attributes=2:set:2 \
        "${CONFIG[DRIVE]}"

    # Verify and update partition table
    sgdisk --verify "${CONFIG[DRIVE]}" || error "Partition verification failed"
    partprobe "${CONFIG[DRIVE]}"
}

function setup_filesystems() {
    # Format
    mkfs.fat -F32 "${CONFIG[EFI_PART]}"
    mkfs.btrfs -f -L ROOT \
    -n 32k \
    -m dup \
    "${CONFIG[ROOT_PART]}"

    # Mount root partition
    mount "${CONFIG[ROOT_PART]}" /mnt

    # Define subvolumes
    local subvolumes=("@" "@home" "@srv" "@cache" "@log" "@tmp")

    # Change to mount point
    pushd /mnt >/dev/null

    # Create subvolumes with loops
    for subvol in "${subvolumes[@]}"; do
        btrfs subvolume create "$subvol"
    done

    # Return to previous directory
    popd >/dev/null

    # Unmount root partition
    umount /mnt

    # Mount
    mount -o "noatime,compress=zstd:1,discard=async,ssd,space_cache=v2,autodefrag,subvol=@" "${CONFIG[ROOT_PART]}" /mnt

    # Create necessary mount points dirs
    mkdir -p /mnt/{root,home,srv,snapshots,var/{cache,log},tmp,boot/efi}

    # Mount subvolumes
    mount -o "noatime,compress=zstd:1,discard=async,ssd,space_cache=v2,autodefrag,subvol=@root" "${CONFIG[ROOT_PART]}" /mnt/root
    mount -o "noatime,compress=zstd:1,discard=async,ssd,space_cache=v2,autodefrag,subvol=@home" "${CONFIG[ROOT_PART]}" /mnt/home
    mount -o "noatime,compress=zstd:1,discard=async,ssd,space_cache=v2,autodefrag,subvol=@srv" "${CONFIG[ROOT_PART]}" /mnt/srv
    mount -o "noatime,compress=zstd:1,discard=async,ssd,space_cache=v2,autodefrag,subvol=@snapshots" "${CONFIG[ROOT_PART]}" /mnt/snapshots
    mount -o "noatime,compress=zstd:1,discard=async,ssd,space_cache=v2,autodefrag,subvol=@cache" "${CONFIG[ROOT_PART]}" /mnt/var/cache
    mount -o "noatime,compress=zstd:1,discard=async,ssd,space_cache=v2,autodefrag,subvol=@log" "${CONFIG[ROOT_PART]}" /mnt/var/log
    mount -o "noatime,compress=zstd:1,discard=async,ssd,space_cache=v2,autodefrag,subvol=@tmp" "${CONFIG[ROOT_PART]}" /mnt/tmp

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
        linux-firmware sof-firmware
        linux linux-headers
        linux-lts linux-lts-headers

        # CPU & GPU Drivers
        amd-ucode xf86-video-amdgpu
        libva-mesa-driver libva-utils mesa lib32-mesa
        vulkan-radeon lib32-vulkan-radeon vulkan-headers
        xorg-server xorg-xinit xf86-input-libinput

        # Essential System Utilities
        networkmanager grub efibootmgr
        btrfs-progs noto-fonts pacutils
        thermald git reflector
        neovim fastfetch neofetch timeshift
        xclip laptop-detect zram-generator
        flatpak glances ufw-extras nano

        # Multimedia & Bluetooth
        bluez bluez-utils

        # Essential User Utilities
        kdeconnect rhythmbox libreoffice-fresh
        kitty firefox

        ninja gcc gdb cmake clang nodejs npm php nmap
        python python-pip python-scikit-learn
        python-numpy python-pandas
        python-scipy python-matplotlib
    )
    pacstrap -K /mnt --needed "${base_packages[@]}"
}

# System configuration function
function configure_system() {
    info "Configuring system..."

    # Generate fstab
    genfstab -U /mnt >>/mnt/etc/fstab

    # Chroot and configure
    arch-chroot /mnt /bin/bash <<EOF
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
    tee > /etc/hosts <<'HOST'
127.0.0.1  localhost
::1        localhost ip6-localhost ip6-loopback
ff02::1    ip6-allnodes
ff02::2    ip6-allrouters
127.0.1.1  ${CONFIG[HOSTNAME]}
HOST

    # Set root password
    echo "root:${CONFIG[PASSWORD]}" | chpasswd

    # Create user
    useradd -m -G wheel,audio,video,network,storage -s /bin/bash ${CONFIG[USERNAME]}
    echo "${CONFIG[USERNAME]}:${CONFIG[PASSWORD]}" | chpasswd
    
    # Configure sudo
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
    mkinitcpio -P
EOF
}

# Performance optimization function
function apply_optimizations() {
    info "Applying system optimizations..."
    arch-chroot /mnt /bin/bash <<'EOF'
# Selects the optimal scheduler for each drive type (HDD, SSD, NVMe)
    tee "/usr/lib/udev/rules.d/60-ioschedulers.rules" <<'IOSCHED'
# HDD
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"

# SSD
ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"

# NVMe SSD
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
IOSCHED

# Sets SATA and IDE HDDs to maximum performance
    tee "/usr/lib/udev/rules.d/69-hdparm.rules" <<'HDPARM'
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", \
    RUN+="/usr/bin/hdparm -B 254 -S 0 /dev/%k"
HDPARM

    tee "/usr/lib/systemd/zram-generator.conf" <<'ZCONF'
[zram0] 
compression-algorithm = zstd lz4 (type=huge)
zram-size = ram
swap-priority = 100
fs-type = swap
ZCONF

# Sets ZRAM swappiness to a more aggressive value so cache is more likely to swap to ZRAM
    tee "/usr/lib/udev/rules.d/30-zram.rules" <<'ZRULES'
TEST!="/dev/zram0", GOTO="zram_end"
SYSCTL{vm.swappiness}="150"
LABEL="zram_end"
ZRULES

    sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
    sed -i 's/^#Color/Color/' /etc/pacman.conf
    sed -i '/^# Misc options/a DisableDownloadTimeout\nILoveCandy' /etc/pacman.conf
    sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf

    # Refresh package databases
    pacman -Syy --noconfirm

EOF
}

# Desktop Environment GNOME
function desktop_install() {
    arch-chroot /mnt /bin/bash <<'EOF'
    pacman -S --needed --noconfirm \    
    gnome gnome-tweaks gnome-terminal
    
    pacman -Rns --noconfirm \
    gnome-tour gnome-user-docs \
    gnome-weather gnome-music \
    epiphany yelp malcontent \
    gnome-software \
    gnome-contacts gnome-calendar \
    gnome-shell-extensions

    systemctl enable gdm
EOF
}

# Services configuration function
function configure_services() {
    info "Configuring services..."
    arch-chroot /mnt /bin/bash <<'EOF'
    # Enable system services
    systemctl enable NetworkManager
    systemctl enable bluetooth.service
    systemctl enable fstrim.timer
    systemctl enable thermald
    systemctl enable ufw
    ufw allow 1714:1764/udp
    ufw allow 1714:1764/tcp
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
    desktop_install
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
    echo "Manaul setup ->..."
    echo ""
    echo "chsh -s $(which zsh)"
    echo "Please restart your session after steps." 
    # sudo chown -R harsh:harsh android-sdk
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
    yay -S --noconfirm \
        telegram-desktop-bin \
        vesktop-bin youtube-music-bin \
        zoom visual-studio-code-bin wine \
        gnome-shell-extension-dash-to-dock
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

# Execute main function
main "$@"
