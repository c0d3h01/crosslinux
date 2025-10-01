#!/usr/bin/env bash

# -*- System configuration function -*-
function configure_system() {
    info "Configuring system..."

    # -*- Generate fstab -*-
    genfstab -U /mnt >>/mnt/etc/fstab

    # -*- Chroot and configure -*-
    arch-chroot /mnt /bin/bash <<EOF
    # Set timezone and synchronize hardware clock
    ln -sf /usr/share/zoneinfo/${CONFIG[TIMEZONE]} "/etc/localtime"

    # Synchronizes system time with hardware clock, using UTC
    hwclock --systohc
    
    # Configure system locale specified locale generation file
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
127.0.0.1 localhost
::1 localhost
127.0.0.2 ${CONFIG[HOSTNAME]}
HOSTS

    # Set root password using chpasswd (securely)
    echo "root:${CONFIG[PASSWORD]}" | chpasswd

    # Create new user account
    useradd -m -G wheel -s /bin/bash ${CONFIG[USERNAME]}

    # Set user password
    echo "${CONFIG[USERNAME]}:${CONFIG[PASSWORD]}" | chpasswd
    
    # Enable sudo access for wheel group members
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' "/etc/sudoers"

    # -*- Install GRUB bootloader for UEFI systems -*-
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB

    # -*- Generate GRUB configuration file -*-
    grub-mkconfig -o /boot/grub/grub.cfg

    # -*- Regenerate initramfs for all kernels -*-
    mkinitcpio -P
EOF
}

export -f configure_system
