#!/usr/bin/env bash

function setup_filesystems() {
    # -*- Format partitions -*-
    mkfs.fat -F32 "${CONFIG[EFI_PART]}"
    mkfs.btrfs -L "ROOT" -n 16k -f "${CONFIG[ROOT_PART]}"

    # -*- Mount root partition temporarily -*-
    mount "${CONFIG[ROOT_PART]}" /mnt

    # -*- Create subvolumes -*-
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@log
    btrfs subvolume create /mnt/@cache

    # -*- Unmount and remount with subvolumes -*-
    umount /mnt
    mount -o "subvol=@,nodatacow" "${CONFIG[ROOT_PART]}" /mnt

    # -*- Create necessary directories -*-
    mkdir -p /mnt/home /mnt/boot/efi /mnt/var/log /mnt/var/cache

    # -*- Mount EFI and home subvolumes -*-
    mount "${CONFIG[EFI_PART]}" /mnt/boot/efi
    mount -o "subvol=@home,nodatacow" "${CONFIG[ROOT_PART]}" /mnt/home
    mount -o "subvol=@cache,nodatacow" "${CONFIG[ROOT_PART]}" /mnt/var/cache
    mount -o "subvol=@log,nodatacow" "${CONFIG[ROOT_PART]}" /mnt/var/log
}

export -f setup_filesystems
