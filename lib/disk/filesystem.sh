#!/usr/bin/env bash
# -*- Filesystem Management Module -*-

# Format EFI partition
format_efi_partition() {
    local partition=$1
    log_info "Formatting EFI partition: $partition"
    
    if safe_exec "mkfs.fat -F32 $partition"; then
        log_success "EFI partition formatted"
    else
        log_error "Failed to format EFI partition"
        return 1
    fi
}

# Format ext4 partition
format_ext4_partition() {
    local partition=$1
    local label=$2
    log_info "Formatting ext4 partition: $partition (label: $label)"
    
    if safe_exec "mkfs.ext4 -L $label $partition"; then
        log_success "Ext4 partition formatted"
    else
        log_error "Failed to format ext4 partition"
        return 1
    fi
}

# Format btrfs partition
format_btrfs_partition() {
    local partition=$1
    local label=$2
    log_info "Formatting btrfs partition: $partition (label: $label)"
    
    if safe_exec "mkfs.btrfs -L $label -n 16k -f $partition"; then
        log_success "Btrfs partition formatted"
    else
        log_error "Failed to format btrfs partition"
        return 1
    fi
}

# Mount root partition
mount_root_partition() {
    local partition=$1
    local mount_point=${2:-"/mnt"}
    
    log_info "Mounting root partition: $partition -> $mount_point"
    
    if safe_exec "mount $partition $mount_point"; then
        log_success "Root partition mounted"
    else
        log_error "Failed to mount root partition"
        return 1
    fi
}

# Create btrfs subvolumes
create_btrfs_subvolumes() {
    local mount_point=${1:-"/mnt"}
    log_info "Creating btrfs subvolumes"
    
    # Create subvolumes
    local subvolumes=("@home" "@log" "@cache" "@snapshots")
    
    for subvol in "${subvolumes[@]}"; do
        if safe_exec "btrfs subvolume create $mount_point/$subvol"; then
            log_success "Created subvolume: $subvol"
        else
            log_error "Failed to create subvolume: $subvol"
            return 1
        fi
    done
}

# Unmount and remount with subvolumes
remount_with_subvolumes() {
    local partition=$1
    local mount_point=${2:-"/mnt"}
    
    log_info "Remounting with subvolumes"
    
    # Unmount
    if safe_exec "umount $mount_point"; then
        log_success "Unmounted root partition"
    else
        log_error "Failed to unmount root partition"
        return 1
    fi
    
    # Remount with subvolumes
    if safe_exec "mount -o subvol=@,nodatacow,compress=zstd $partition $mount_point"; then
        log_success "Remounted with subvolumes"
    else
        log_error "Failed to remount with subvolumes"
        return 1
    fi
}

# Create mount directories
create_mount_directories() {
    local mount_point=${1:-"/mnt"}
    log_info "Creating mount directories"
    
    local directories=("home" "boot/efi" "var/log" "var/cache" ".snapshots")
    
    for dir in "${directories[@]}"; do
        if safe_exec "mkdir -p $mount_point/$dir"; then
            log_success "Created directory: $dir"
        else
            log_error "Failed to create directory: $dir"
            return 1
        fi
    done
}

# Mount EFI partition
mount_efi_partition() {
    local partition=$1
    local mount_point=${2:-"/mnt/boot/efi"}
    
    log_info "Mounting EFI partition: $partition -> $mount_point"
    
    if safe_exec "mount $partition $mount_point"; then
        log_success "EFI partition mounted"
    else
        log_error "Failed to mount EFI partition"
        return 1
    fi
}

# Mount btrfs subvolumes
mount_btrfs_subvolumes() {
    local partition=$1
    local mount_point=${2:-"/mnt"}
    
    log_info "Mounting btrfs subvolumes"
    
    # Mount home subvolume
    if safe_exec "mount -o subvol=@home,nodatacow,compress=zstd $partition $mount_point/home"; then
        log_success "Home subvolume mounted"
    else
        log_error "Failed to mount home subvolume"
        return 1
    fi
    
    # Mount cache subvolume
    if safe_exec "mount -o subvol=@cache,nodatacow,compress=zstd $partition $mount_point/var/cache"; then
        log_success "Cache subvolume mounted"
    else
        log_error "Failed to mount cache subvolume"
        return 1
    fi
    
    # Mount log subvolume
    if safe_exec "mount -o subvol=@log,nodatacow,compress=zstd $partition $mount_point/var/log"; then
        log_success "Log subvolume mounted"
    else
        log_error "Failed to mount log subvolume"
        return 1
    fi
    
    # Mount snapshots subvolume
    if safe_exec "mount -o subvol=@snapshots,nodatacow,compress=zstd $partition $mount_point/.snapshots"; then
        log_success "Snapshots subvolume mounted"
    else
        log_error "Failed to mount snapshots subvolume"
        return 1
    fi
}

# Setup Arch Linux filesystem
setup_arch_filesystem() {
    local efi_partition=$1
    local root_partition=$2
    local mount_point=${3:-"/mnt"}
    
    log_info "Setting up Arch Linux filesystem"
    
    # Format partitions
    format_efi_partition "$efi_partition" || return 1
    format_btrfs_partition "$root_partition" "ROOT" || return 1
    
    # Mount root partition
    mount_root_partition "$root_partition" "$mount_point" || return 1
    
    # Create subvolumes
    create_btrfs_subvolumes "$mount_point" || return 1
    
    # Unmount and remount with subvolumes
    remount_with_subvolumes "$root_partition" "$mount_point" || return 1
    
    # Create mount directories
    create_mount_directories "$mount_point" || return 1
    
    # Mount EFI partition
    mount_efi_partition "$efi_partition" "$mount_point/boot/efi" || return 1
    
    # Mount btrfs subvolumes
    mount_btrfs_subvolumes "$root_partition" "$mount_point" || return 1
    
    log_success "Arch Linux filesystem setup completed"
}

# Setup Ubuntu filesystem
setup_ubuntu_filesystem() {
    local efi_partition=$1
    local root_partition=$2
    local home_partition=$3
    local mount_point=${4:-"/mnt"}
    
    log_info "Setting up Ubuntu filesystem"
    
    # Format partitions
    format_efi_partition "$efi_partition" || return 1
    format_ext4_partition "$root_partition" "ROOT" || return 1
    format_ext4_partition "$home_partition" "HOME" || return 1
    
    # Mount partitions
    mount_root_partition "$root_partition" "$mount_point" || return 1
    mount_efi_partition "$efi_partition" "$mount_point/boot/efi" || return 1
    mount_root_partition "$home_partition" "$mount_point/home" || return 1
    
    log_success "Ubuntu filesystem setup completed"
}

# Export functions
export -f format_efi_partition format_ext4_partition format_btrfs_partition mount_root_partition
export -f create_btrfs_subvolumes remount_with_subvolumes create_mount_directories mount_efi_partition
export -f mount_btrfs_subvolumes setup_arch_filesystem setup_ubuntu_filesystem
