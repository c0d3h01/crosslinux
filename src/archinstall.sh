#!/usr/bin/env bash
# shellcheck disable=

set -euo pipefail

# ====== COLORS ======
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

LOGFILE="archinstall.log"

log()    { echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOGFILE"; }
ok()     { echo -e "${GREEN}[OK]${NC} $*"  | tee -a "$LOGFILE"; }
fail()   { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOGFILE"; exit 1; }

require_tools() {
    local missing_tools=()
    for tool in jq sgdisk btrfs mkfs.fat pacstrap arch-chroot reflector; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -ne 0 ]]; then
        log "The following required tools are missing: ${missing_tools[*]}"
        log "Attempting to install missing tools with pacman..."
        sudo pacman -Sy --noconfirm "${missing_tools[@]}" || fail "Failed to install required tools: ${missing_tools[*]}"
        # Re-check if installation succeeded, fail if not
        for tool in "${missing_tools[@]}"; do
            command -v "$tool" >/dev/null 2>&1 || fail "$tool is required but could not be installed automatically."
        done
    fi
}

CONFIG_JSON=""
load_config() {
    CONFIG_JSON=$(cat "${1:?Missing config file!}")
    for key in drive hostname users timezone locale; do
        jq -e ".${key}" <<< "$CONFIG_JSON" >/dev/null || fail "Config missing: $key"
    done
}

choose_drive() {
    # Only show real disks, not loop/rom, with size and model for clarity
    mapfile -t drives < <(lsblk -dno NAME,TYPE,SIZE,MODEL | awk '$2=="disk"{printf "/dev/%s (%s, %s)\n", $1, $3, $4}')
    if [[ ${#drives[@]} -eq 0 ]]; then
        fail "No drives found!"
    fi

    log "Available drives:"
    for i in "${!drives[@]}"; do
        echo "$((i+1)). ${drives[$i]}"
    done

    read -rp "Choose drive to install (default: 1): " idx
    idx=${idx:-1}
    if ! [[ "$idx" =~ ^[0-9]+$ ]] || (( idx < 1 || idx > ${#drives[@]} )); then
        fail "Invalid selection."
    fi
    DRIVE=$(echo "${drives[$((idx-1))]}" | awk '{print $1}')
    log "Selected drive: $DRIVE"

    # Confirm before wiping
    read -rp "WARNING: All data on $DRIVE will be lost. Are you sure? [y/N]: " confirm
    [[ "${confirm,,}" == "y" ]] || fail "Aborted by user."
}

setup_disk() {
    log "Wiping $DRIVE"
    wipefs -af "$DRIVE"
    sgdisk --zap-all "$DRIVE"
    sgdisk --clear "$DRIVE"
    sgdisk --new=1:0:+1G --typecode=1:ef00 --change-name=1:"EFI" \
           --new=2:0:0 --typecode=2:8300 --change-name=2:"ROOT" "$DRIVE"
    partprobe "$DRIVE"
    # Correctly handle partition naming for different device types
    if [[ "$DRIVE" =~ [0-9]$ ]]; then
        EFI_PART="${DRIVE}p1"
        ROOT_PART="${DRIVE}p2"
    else
        EFI_PART="${DRIVE}1"
        ROOT_PART="${DRIVE}2"
    fi
}

setup_filesystems() {
    mkfs.fat -F32 "$EFI_PART"
    mkfs.btrfs -L "ROOT" -n 16k -f "$ROOT_PART"
    mount "$ROOT_PART" /mnt
    for sub in @ @home @log @cache; do btrfs subvolume create /mnt/$sub; done
    umount /mnt
    mount -o "subvol=@,compress=zstd:3" "$ROOT_PART" /mnt
    mkdir -p /mnt/{home,boot/efi,var/log,var/cache}
    mount "$EFI_PART" /mnt/boot/efi
    mount -o "subvol=@home,compress=zstd:3" "$ROOT_PART" /mnt/home
    mount -o "subvol=@cache,compress=zstd:3" "$ROOT_PART" /mnt/var/cache
    mount -o "subvol=@log,compress=zstd:1" "$ROOT_PART" /mnt/var/log
}

install_base_system() {
    local base_packages=(
        base base-devel linux-lts linux-lts-headers linux-firmware
        btrfs-progs grub efibootmgr networkmanager firewalld
        zsh git reflector neovim sudo
    )
    pacstrap -K /mnt --needed "${base_packages[@]}"
}

configure_system() {
    genfstab -U /mnt >>/mnt/etc/fstab
    local TIMEZONE LOCALE HOSTNAME
    TIMEZONE=$(jq -r .timezone <<< "$CONFIG_JSON")
    LOCALE=$(jq -r .locale <<< "$CONFIG_JSON")
    HOSTNAME=$(jq -r .hostname <<< "$CONFIG_JSON")
    arch-chroot /mnt /bin/bash <<EOF
set -e
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts << HOSTS
127.0.0.1       localhost
::1             localhost
127.0.1.1       $HOSTNAME.localdomain $HOSTNAME
HOSTS
EOF
}

create_users() {
    local users_count
    users_count=$(jq '.users | length' <<< "$CONFIG_JSON")
    for ((i=0; i<users_count; i++)); do
        local username password groups shell
        username=$(jq -r ".users[$i].name" <<< "$CONFIG_JSON")
        password=$(jq -r ".users[$i].password" <<< "$CONFIG_JSON")
        groups=$(jq -r ".users[$i].groups // \"wheel\"" <<< "$CONFIG_JSON")
        shell=$(jq -r ".users[$i].shell // \"/bin/bash\"" <<< "$CONFIG_JSON")

        # Ensure all groups exist before user creation
        for grp in $(echo "$groups" | tr ',' ' '); do
            arch-chroot /mnt getent group "$grp" >/dev/null || arch-chroot /mnt groupadd "$grp"
        done

        # Create user and set password
        arch-chroot /mnt /bin/bash <<EOF
useradd -m -G $groups -s $shell $username
echo "$username:$password" | chpasswd
EOF
    done

    # Enable sudo for wheel group
    arch-chroot /mnt sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
}

install_bootloader() {
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    arch-chroot /mnt mkinitcpio -P
}

enable_services() {
    local services=(NetworkManager firewalld)
    for s in "${services[@]}"; do arch-chroot /mnt systemctl enable "$s"; done
}

main() {
    require_tools

    local config_file="${1:-config/user_config.json}"
    [[ -f "$config_file" ]] || fail "Config file '$config_file' not found."
    load_config "$config_file"

    DRIVE=$(jq -r .drive <<< "$CONFIG_JSON")
    [[ "$DRIVE" == "auto" ]] && choose_drive

    setup_disk
    setup_filesystems
    install_base_system
    configure_system
    create_users
    install_bootloader
    enable_services

    ok "Installation complete! You may now reboot."
}

main "$@"