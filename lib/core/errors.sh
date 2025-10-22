#!/usr/bin/env bash
# -*- Core Error Handling Module -*-

# Error codes
readonly ERR_GENERAL=1
readonly ERR_PERMISSION=2
readonly ERR_NETWORK=3
readonly ERR_DISK=4
readonly ERR_PACKAGE=5
readonly ERR_SERVICE=6
readonly ERR_CONFIG=7
readonly ERR_VALIDATION=8

# Error messages
declare -A ERROR_MESSAGES
ERROR_MESSAGES[$ERR_GENERAL]="General error occurred"
ERROR_MESSAGES[$ERR_PERMISSION]="Permission denied - run as root"
ERROR_MESSAGES[$ERR_NETWORK]="Network error - check internet connection"
ERROR_MESSAGES[$ERR_DISK]="Disk operation failed"
ERROR_MESSAGES[$ERR_PACKAGE]="Package installation failed"
ERROR_MESSAGES[$ERR_SERVICE]="Service configuration failed"
ERROR_MESSAGES[$ERR_CONFIG]="Configuration error"
ERROR_MESSAGES[$ERR_VALIDATION]="Validation failed"

# Set error trap
set_error_trap() {
    trap 'handle_error $LINENO $?' ERR
}

# Handle errors
handle_error() {
    local line_number=$1
    local exit_code=$2
    
    log_error "Script failed at line $line_number with exit code $exit_code"
    
    # Cleanup on error
    cleanup_on_error
    
    # Show error message
    if [ -n "${ERROR_MESSAGES[$exit_code]}" ]; then
        log_error "${ERROR_MESSAGES[$exit_code]}"
    fi
    
    exit $exit_code
}

# Cleanup on error
cleanup_on_error() {
    log_warning "Performing cleanup on error..."
    
    # Unmount filesystems if mounted
    if mount | grep -q "/mnt"; then
        log_info "Unmounting filesystems..."
        umount -R /mnt 2>/dev/null || true
    fi
    
    # Remove temporary files
    rm -f /tmp/install_config.conf 2>/dev/null || true
    
    log_info "Cleanup completed"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root"
        exit $ERR_PERMISSION
    fi
}

# Check internet connection
check_network() {
    if ! ping -c 1 google.com &> /dev/null; then
        log_error "No internet connection detected"
        exit $ERR_NETWORK
    fi
}

# Check disk space
check_disk_space() {
    local required_space=${1:-1048576}  # 1GB in KB
    
    local available_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt "$required_space" ]; then
        log_warning "Low disk space detected. Available: ${available_space}KB, Required: ${required_space}KB"
    fi
}

# Retry function
retry() {
    local max_attempts=$1
    local delay=$2
    local command="${@:3}"
    
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        log_debug "Attempt $attempt/$max_attempts: $command"
        
        if eval "$command"; then
            log_success "Command succeeded on attempt $attempt"
            return 0
        else
            log_warning "Command failed on attempt $attempt"
            if [ $attempt -lt $max_attempts ]; then
                log_info "Retrying in $delay seconds..."
                sleep $delay
            fi
        fi
        
        ((attempt++))
    done
    
    log_error "Command failed after $max_attempts attempts"
    return 1
}

# Safe execution with error handling
safe_exec() {
    local command="$*"
    local description=${1:-"Command"}
    
    log_debug "Executing: $command"
    
    if eval "$command"; then
        log_success "$description completed successfully"
        return 0
    else
        log_error "$description failed"
        return 1
    fi
}

# Export functions
export -f set_error_trap handle_error cleanup_on_error check_root check_network check_disk_space retry safe_exec
