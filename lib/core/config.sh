#!/usr/bin/env bash
# -*- Core Configuration Module -*-

# Global configuration array
declare -A CONFIG

# Default configuration values
DEFAULT_CONFIG=(
    [HOSTNAME]="linuxbox"
    [USERNAME]="user"
    [TIMEZONE]="Asia/Kolkata"
    [LOCALE]="en_US.UTF-8"
    [CPU_VENDOR]="amd"
    [GPU_VENDOR]="amd"
    [UBUNTU_VERSION]="24.04"
    [LOG_LEVEL]="2"
)

# Initialize configuration with defaults
init_config_defaults() {
    log_info "Initializing configuration with defaults..."
    
    for key in "${!DEFAULT_CONFIG[@]}"; do
        CONFIG[$key]="${DEFAULT_CONFIG[$key]}"
    done
    
    log_success "Configuration defaults loaded"
}

# Load configuration from file
load_config_file() {
    local config_file=${1:-"/tmp/install_config.conf"}
    
    if [ -f "$config_file" ]; then
        log_info "Loading configuration from $config_file"
        source "$config_file"
        log_success "Configuration loaded from file"
    else
        log_warning "Configuration file $config_file not found, using defaults"
        init_config_defaults
    fi
}

# Save configuration to file
save_config_file() {
    local config_file=${1:-"/tmp/install_config.conf"}
    
    log_info "Saving configuration to $config_file"
    
    cat > "$config_file" << EOF
# Installation Configuration
# Generated on $(date)

EOF
    
    for key in "${!CONFIG[@]}"; do
        echo "CONFIG[$key]=\"${CONFIG[$key]}\"" >> "$config_file"
    done
    
    log_success "Configuration saved to $config_file"
}

# Interactive configuration
interactive_config() {
    log_info "Starting interactive configuration..."
    
    # Get password
    while true; do
        read -s -p "Enter password for root and user: " password
        echo
        read -s -p "Confirm password: " confirm_password
        echo
        if [ "$password" = "$confirm_password" ]; then
            CONFIG[PASSWORD]="$password"
            break
        else
            log_error "Passwords do not match. Try again."
        fi
    done
    
    # Get drive selection
    echo "Available drives:"
    lsblk -d -o NAME,SIZE,TYPE | grep disk
    read -p "Enter drive to install to (e.g., /dev/nvme0n1): " drive
    CONFIG[DRIVE]="$drive"
    
    # Get hostname
    read -p "Enter hostname (default: ${CONFIG[HOSTNAME]}): " hostname
    CONFIG[HOSTNAME]="${hostname:-${CONFIG[HOSTNAME]}}"
    
    # Get username
    read -p "Enter username (default: ${CONFIG[USERNAME]}): " username
    CONFIG[USERNAME]="${username:-${CONFIG[USERNAME]}}"
    
    # Get timezone
    read -p "Enter timezone (default: ${CONFIG[TIMEZONE]}): " timezone
    CONFIG[TIMEZONE]="${timezone:-${CONFIG[TIMEZONE]}}"
    
    # Get locale
    read -p "Enter locale (default: ${CONFIG[LOCALE]}): " locale
    CONFIG[LOCALE]="${locale:-${CONFIG[LOCALE]}}"
    
    # Set partition paths
    if [[ "${CONFIG[DRIVE]}" =~ nvme ]]; then
        CONFIG[EFI_PART]="${CONFIG[DRIVE]}p1"
        CONFIG[ROOT_PART]="${CONFIG[DRIVE]}p2"
        CONFIG[HOME_PART]="${CONFIG[DRIVE]}p3"
    else
        CONFIG[EFI_PART]="${CONFIG[DRIVE]}1"
        CONFIG[ROOT_PART]="${CONFIG[DRIVE]}2"
        CONFIG[HOME_PART]="${CONFIG[DRIVE]}3"
    fi
    
    log_success "Interactive configuration completed"
}

# Get configuration value
get_config() {
    local key=$1
    local default=${2:-""}
    echo "${CONFIG[$key]:-$default}"
}

# Set configuration value
set_config() {
    local key=$1
    local value=$2
    CONFIG[$key]="$value"
    log_debug "Set CONFIG[$key] = $value"
}

# Display current configuration
show_config() {
    log_info "Current configuration:"
    for key in "${!CONFIG[@]}"; do
        if [ "$key" != "PASSWORD" ]; then
            echo "  $key: ${CONFIG[$key]}"
        else
            echo "  $key: [HIDDEN]"
        fi
    done
}

# Export functions
export -f init_config_defaults load_config_file save_config_file interactive_config
export -f get_config set_config show_config