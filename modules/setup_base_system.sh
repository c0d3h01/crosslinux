#!/usr/bin/env bash

# -*- Base system installation function -*-
function install_base_system() {
    info "Installing base system..."

    info "Configuring pacman for iso installaton..."
    # -*- Pacman configure for arch-iso -*-
    sed -i 's/^#ParallelDownloads/ParallelDownloads/' "/etc/pacman.conf"
    sed -i '/^# Misc options/a DisableDownloadTimeout' "/etc/pacman.conf"

    # -*- Refresh package databases -*-
    pacman -Syy

    info "Running reflctor..."
    reflector --country India --age 10 --protocol https --sort rate --save "/etc/pacman.d/mirrorlist"

    local base_packages=(
        # -*- Core System -*-
        base              # Minimal package set to define a basic Arch Linux installation
        base-devel        # Basic tools to build Arch Linux packages
        linux-firmware    # Firmware files for Linux
        linux-lts         # The LTS Linux kernel and modules
        linux-lts-headers # Headers and scripts for building modules for the LTS Linux kernel

        # -*- Filesystem -*-
        btrfs-progs # Btrfs filesystem utilities

        # -*- Boot -*-
        grub       # GNU GRand Unified Bootloader
        efibootmgr # Linux user-space application to modify the EFI Boot Manager

        # -*- CPU & GPU Drivers -*-
        amd-ucode         # Microcode update image for AMD CPUs
        libva-mesa-driver # mesa with 32bit driver
        mesa              # Open-source OpenGL drivers
        vulkan-radeon     # Open-source Vulkan driver for AMD GPUs
        xf86-video-amdgpu # X.org amdgpu video driver
        xf86-video-ati    # X.org ati video driver
        xorg-server       # Xorg X server
        xorg-xinit        # X.Org initialisation program

        # -*- Network & firewall -*-
        networkmanager # Network connection manager and user applications
        firewalld      # Firewall daemon with D-Bus interface

        # -*- Multimedia & Bluetooth -*-
        bluez            # Daemons for the bluetooth protocol stack
        bluez-utils      # Development and debugging utilities for the bluetooth protocol stack
        pipewire         # Low-latency audio/video router and processor
        pipewire-pulse   # Low-latency audio/video router and processor - PulseAudio replacement
        pipewire-alsa    # Low-latency audio/video router and processor - ALSA configuration
        pipewire-jack    # Low-latency audio/video router and processor - JACK replacement
        wireplumber      # Session / policy manager implementation for PipeWire
        gstreamer        # Multimedia graph framework - core
        gst-libav        # Multimedia graph framework - libav plugin
        gst-plugins-base # Multimedia graph framework - base plugins
        gst-plugins-good # Multimedia graph framework - good plugins
        gst-plugins-bad  # Multimedia graph framework - bad plugins
        gst-plugins-ugly # Multimedia graph framework - ugly plugins

        # -*- Desktop environment [ Gnome ] -*-
        nautilus                 # Default file manager for GNOME
        sushi                    # A quick previewer for Nautilus
        totem                    # Movie player for the GNOME desktop based on GStreamer
        loupe                    # A simple image viewer for GNOME
        evince                   # Document viewer (PDF, PostScript, XPS, djvu, dvi, tiff, cbr, cbz, cb7, cbt)
        file-roller              # Create and modify archives
        rhythmbox                # Music playback and management application
        micro                    # Modern and intuitive terminal-based text editor
        gdm                      # Display manager and login screen
        gnome-settings-daemon    # GNOME Settings Daemon
        gnome-browser-connector  # Native browser connector for integration with extensions.gnome.org
        gnome-backgrounds        # Background images and data for GNOME
        gnome-session            # The GNOME Session Handler
        gnome-calculator         # GNOME Scientific calculator
        gnome-clocks             # gnome-clocks
        gnome-control-center     # GNOME's main interface to configure various aspects
        gnome-disk-utility       # Disk Management Utility for GNOME
        gnome-calendar           # Calendar application
        gnome-keyring            # Stores passwords and encryption keys
        gnome-nettool            # Graphical interface for various networking tools
        gnome-power-manager      # System power information and statistics
        gnome-screenshot         # Take pictures of your screen
        gnome-shell              # Next generation desktop shell
        gnome-themes-extra       # Extra Themes for GNOME Applications
        gnome-tweaks             # Graphical interface for advanced GNOME 3 settings (Tweak Tool)
        gnome-logs               # A log viewer for the systemd journal
        snapshot                 # Take pictures and videos
        gvfs                     # Virtual filesystem implementation for GIO
        gvfs-afc                 # Virtual filesystem implementation for GIO - AFC backend (Apple mobile devices)
        gvfs-gphoto2             # Virtual filesystem implementation for GIO - gphoto2 backend (PTP camera, MTP media player)
        gvfs-mtp                 # Virtual filesystem implementation for GIO - MTP backend (Android, media player)
        gvfs-nfs                 # Virtual filesystem implementation for GIO - NFS backend
        gvfs-smb                 # Virtual filesystem implementation for GIO - SMB/CIFS backend (Windows file sharing)
        xdg-desktop-portal-gnome # Backend implementation for xdg-desktop-portal for the GNOME desktop environment
        xdg-user-dirs-gtk        # Creates user dirs and asks to relocalize them

        # -*- Fonts -*-
        noto-fonts
        noto-fonts-cjk
        noto-fonts-emoji
        ttf-fira-code

        # -*- Essential System Utilities -*-
        kitty
        zram-generator
        git
        reflector
        pacutils
        fastfetch
        glances
        wget
        curl
        sshpass
        openssh
        inxi
        zsh
        cups
        snapper
        snap-pac
        grub-btrfs
        xclip
        neovim

        # -*- Development-tool -*-
        gcc
        glibc
        gdb
        cmake
        clang
        zig
        npm
        nodejs
        yarn
        docker
        docker-compose
        jdk-openjdk
        jupyterlab
        python
        python-virtualenv
        python-pip

        # -*- User Utilities -*-
        firefox
        discord
        qbittorrent
        telegram-desktop
    )
    pacstrap -K /mnt --needed "${base_packages[@]}"
}

export -f install_base_system
