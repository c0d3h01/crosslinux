#!/usr/bin/env bash
#
# shellcheck disable=SC1078
# shellcheck disable=SC2162
# shellcheck disable=SC1079
# shellcheck disable=SC1009
# shellcehck disable=SC1072
# shellcheck disable=SC1073
#
# ==============================================================================
# Automated Arch Linux Installation Personal Setup Script
# ==============================================================================

set -euxo pipefail

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
    local subvolumes=("@" "@home" "@root" "@srv" "@cache" "@log" "@tmp" "@snapshots")

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
    mount -o "noatime,compress=zstd,discard=async,ssd,space_cache=v2,subvol=@" "${CONFIG[ROOT_PART]}" /mnt

    # Create necessary mount points dirs
    mkdir -p /mnt/{home,root,srv,var/{cache,log},tmp,boot/efi,snapshots}

    # Mount subvolumes
    mount -o "noatime,compress=zstd,discard=async,ssd,space_cache=v2,subvol=@home" "${CONFIG[ROOT_PART]}" /mnt/home
    mount -o "noatime,compress=zstd,discard=async,ssd,space_cache=v2,subvol=@root" "${CONFIG[ROOT_PART]}" /mnt/root
    mount -o "noatime,compress=zstd,discard=async,ssd,space_cache=v2,subvol=@srv" "${CONFIG[ROOT_PART]}" /mnt/srv
    mount -o "noatime,compress=zstd,discard=async,ssd,space_cache=v2,subvol=@snapshots" "${CONFIG[ROOT_PART]}" /mnt/snapshots
    mount -o "noatime,compress=zstd,discard=async,ssd,space_cache=v2,subvol=@cache" "${CONFIG[ROOT_PART]}" /mnt/var/cache
    mount -o "noatime,compress=zstd,discard=async,ssd,space_cache=v2,subvol=@log" "${CONFIG[ROOT_PART]}" /mnt/var/log
    mount -o "noatime,compress=zstd,discard=async,ssd,space_cache=v2,subvol=@tmp" "${CONFIG[ROOT_PART]}" /mnt/tmp

    # Mount EFI partition
    mount "${CONFIG[EFI_PART]}" /mnt/boot/efi
}

# Base system installation function
function install_base_system() {
    info "Installing base system..."
    
    reflector --country India --age 6 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

    # Pacman configure for arch-iso
    sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
    sed -i 's/^#Color/Color/' /etc/pacman.conf
    sed -i '/^# Misc options/a DisableDownloadTimeout\nILoveCandy' /etc/pacman.conf
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
        amd-ucode mesa-vdpau
        libva-mesa-driver libva-utils mesa lib32-mesa
        vulkan-radeon lib32-vulkan-radeon vulkan-headers
        xf86-video-amdgpu xf86-video-ati xf86-input-libinput
        xorg-server xorg-xinit

        # Essential System Utilities
        networkmanager grub efibootmgr nohang
        btrfs-progs bash-completion noto-fonts
        htop vim fastfetch nodejs npm thermald
        git xclip laptop-detect kitty reflector
        flatpak htop glances ufw-extras timeshift
        ninja gcc gdb cmake clang rsync zram-generator

        # Multimedia & Bluetooth
        bluez bluez-utils
        pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber
        
        # Daily Usage Needs
        zed kdeconnect rhythmbox libreoffice-fresh
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
    useradd -m -G wheel -s /bin/bash ${CONFIG[USERNAME]}
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

    reflector --country India --age 6 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

    sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
    sed -i 's/^#Color/Color/' /etc/pacman.conf
    sed -i '/^# Misc options/a DisableDownloadTimeout\nILoveCandy' /etc/pacman.conf
    sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf

    # Refresh package databases
    pacman -Syy --noconfirm

    tee "/usr/lib/systemd/zram-generator.conf" <<'ZRAM'
[zram0]
compression-algorithm = zstd lz4 (type=huge)
zram-size = ram
swap-priority = 100
fs-type = swap
ZRAM

    tee "/usr/lib/udev/rules.d/30-zram.rules" <<'ZRULE'
TEST!="/dev/zram0", GOTO="zram_end"

# Since ZRAM stores all pages in compressed form in RAM, we should prefer
# preempting anonymous pages more than a page (file) cache.  Preempting file
# pages may not be desirable because a process may want to access a file at any
# time, whereas if it is preempted, it will cause an additional read cycle from
# the disk.
SYSCTL{vm.swappiness}="150"

LABEL="zram_end"
ZRULE

EOF
}

# Desktop Environment GNOME
function desktop_install() {
    arch-chroot /mnt /bin/bash <<'EOF'
    pacman -S --needed --noconfirm \
    gnome gnome-tweaks gnome-terminal

    # Remove gnome bloat's & enable gdm
    pacman -Rns --noconfirm \
    gnome-tour gnome-user-docs \
    gnome-weather gnome-music \
    epiphany yelp malcontent \
    gnome-software
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
    systemctl enable nohang
    systemctl enable thermald
    systemctl enable ufw
    ufw allow 1714:1764/udp
    ufw allow 1714:1764/tcp
    ufw reload
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
        telegram-desktop-bin flutter-bin \
        vesktop-bin youtube-music-bin \
        zoom visual-studio-code-bin wine \
        gnome-shell-extension-pop-shell-git

    # Set up variables
    # Bash configuration
sed -i '$a\
\
alias pi="sudo pacman -S"\
alias po="sudo pacman -Rns"\
alias update="sudo pacman -Syyu --needed --noconfirm && yay --noconfirm"\
alias clean="yay -Scc --noconfirm"\
alias la="ls -la"\
\
# Use bash-completion, if available\
[[ $PS1 && -f /usr/share/bash-completion/bash_completion ]] &&\
    . /usr/share/bash-completion/bash_completion\
\
export CHROME_EXECUTABLE=$(which brave)\
export PATH=$PATH:/opt/platform-tools:/opt/android-ndk' ~/.bashrc

echo "Configuration updated for shell."

    # sudo chown -R harsh:harsh android-sdk
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
    -i, --install
    -s, --setup
    -h, --help
EOF
}

# Execute main function
main "$@"
