#!/usr/bin/env bash

function coustom_configuration() {
    arch-chroot /mnt /bin/bash <<EOF
    # -*- Create zram configuration file for systemd zram generator -*-
    cat > "/etc/systemd/zram-generator.conf" << ZRAM
[zram0]
compression-algorithm = zstd
zram-size = ram * 2
swap-priority = 1000
fs-type = swap
ZRAM

    cat > "/etc/sysctl.d/99-vm-zram-parameters.conf" << SYSCTL
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
SYSCTL

    # Configure pacman with parallel downloads, color output, multilib repo, and extra options
    sed -i 's/^#ParallelDownloads/ParallelDownloads/' "/etc/pacman.conf" 
    sed -i 's/^#Color/Color/' "/etc/pacman.conf"
    sed -i '/^# Misc options/a DisableDownloadTimeout\nILoveCandy' "/etc/pacman.conf"
    sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' "/etc/pacman.conf"

    # -*- Set zsh as default shell for the user -*-
    chsh -s /bin/zsh ${CONFIG[USERNAME]}

    # -*- Enable additional services -*-
    systemctl enable \
    NetworkManager \
    bluetooth \
    fstrim.timer \
    gdm \
    dbus \
    lm_sensors \
    avahi-daemon \
    docker \
    systemd-timesyncd \
    snapper-timeline.timer snapper-cleanup.timer

    systemctl --user enable pipewire wireplumber
EOF
}

export -f coustom_configuration
