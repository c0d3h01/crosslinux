#!/usr/bin/env bash

function setup_disk() {
    # -*- Wipe and prepare the disk -*-
    wipefs -af "${CONFIG[DRIVE]}"
    sgdisk --zap-all "${CONFIG[DRIVE]}"

    # -*- Create fresh GPT -*-
    sgdisk --clear "${CONFIG[DRIVE]}"

    # -*- Create partitions -*-
    sgdisk \
        --new=1:0:+1G --typecode=1:ef00 --change-name=1:"EFI" \
        --new=2:0:0 --typecode=2:8300 --change-name=2:"ROOT" \
        "${CONFIG[DRIVE]}"

    # -*- Reload the partition table -*-
    partprobe "${CONFIG[DRIVE]}"

    sleep 2  # Wait for partition table to be recognized
}

export -f setup_disk
