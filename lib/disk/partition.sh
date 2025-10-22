#!/usr/bin/env bash
# -*- Disk Partitioning Module -*-

# Wipe disk
wipe_disk() {
    local drive=$1
    log_info "Wiping disk: $drive"
    
    if safe_exec "wipefs -af $drive"; then
        log_success "Disk wiped successfully"
    else
        log_error "Failed to wipe disk"
        return 1
    fi
}

# Clear partition table
clear_partition_table() {
    local drive=$1
    log_info "Clearing partition table: $drive"
    
    if safe_exec "sgdisk --zap-all $drive"; then
        log_success "Partition table cleared"
    else
        log_error "Failed to clear partition table"
        return 1
    fi
}

# Create GPT partition table
create_gpt_table() {
    local drive=$1
    log_info "Creating GPT partition table: $drive"
    
    if safe_exec "sgdisk --clear $drive"; then
        log_success "GPT partition table created"
    else
        log_error "Failed to create GPT partition table"
        return 1
    fi
}

# Create EFI partition
create_efi_partition() {
    local drive=$1
    local size=${2:-"1G"}
    
    log_info "Creating EFI partition: $drive (${size})"
    
    if safe_exec "sgdisk --new=1:0:+${size} --typecode=1:ef00 --change-name=1:EFI $drive"; then
        log_success "EFI partition created"
    else
        log_error "Failed to create EFI partition"
        return 1
    fi
}

# Create root partition
create_root_partition() {
    local drive=$1
    local size=${2:-"50G"}
    
    log_info "Creating root partition: $drive (${size})"
    
    if safe_exec "sgdisk --new=2:0:+${size} --typecode=2:8300 --change-name=2:ROOT $drive"; then
        log_success "Root partition created"
    else
        log_error "Failed to create root partition"
        return 1
    fi
}

# Create home partition
create_home_partition() {
    local drive=$1
    
    log_info "Creating home partition: $drive (remaining space)"
    
    if safe_exec "sgdisk --new=3:0:0 --typecode=3:8300 --change-name=3:HOME $drive"; then
        log_success "Home partition created"
    else
        log_error "Failed to create home partition"
        return 1
    fi
}

# Reload partition table
reload_partition_table() {
    local drive=$1
    log_info "Reloading partition table: $drive"
    
    if safe_exec "partprobe $drive"; then
        sleep 2  # Wait for partition table to be recognized
        log_success "Partition table reloaded"
    else
        log_error "Failed to reload partition table"
        return 1
    fi
}

# Create Arch Linux partitions
create_arch_partitions() {
    local drive=$1
    log_info "Creating Arch Linux partitions on: $drive"
    
    # Wipe and prepare disk
    wipe_disk "$drive" || return 1
    clear_partition_table "$drive" || return 1
    create_gpt_table "$drive" || return 1
    
    # Create partitions
    create_efi_partition "$drive" "1G" || return 1
    create_root_partition "$drive" "0" || return 1  # Use remaining space
    
    # Reload partition table
    reload_partition_table "$drive" || return 1
    
    log_success "Arch Linux partitions created successfully"
}

# Create Ubuntu partitions
create_ubuntu_partitions() {
    local drive=$1
    log_info "Creating Ubuntu partitions on: $drive"
    
    # Wipe and prepare disk
    wipe_disk "$drive" || return 1
    clear_partition_table "$drive" || return 1
    create_gpt_table "$drive" || return 1
    
    # Create partitions
    create_efi_partition "$drive" "512M" || return 1
    create_root_partition "$drive" "50G" || return 1
    create_home_partition "$drive" || return 1
    
    # Reload partition table
    reload_partition_table "$drive" || return 1
    
    log_success "Ubuntu partitions created successfully"
}

# List partitions
list_partitions() {
    local drive=$1
    log_info "Partitions on $drive:"
    lsblk "$drive"
}

# Get partition path
get_partition_path() {
    local drive=$1
    local partition_number=$2
    
    if [[ "$drive" =~ nvme ]]; then
        echo "${drive}p${partition_number}"
    else
        echo "${drive}${partition_number}"
    fi
}

# Export functions
export -f wipe_disk clear_partition_table create_gpt_table create_efi_partition create_root_partition
export -f create_home_partition reload_partition_table create_arch_partitions create_ubuntu_partitions
export -f list_partitions get_partition_path
