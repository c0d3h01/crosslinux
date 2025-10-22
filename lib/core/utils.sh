#!/usr/bin/env bash
# -*- Core Utilities Module -*-

# Detect distribution
detect_distro() {
    if [ -f /etc/arch-release ]; then
        echo "arch"
    elif [ -f /etc/debian_version ]; then
        echo "ubuntu"
    elif [ -f /etc/fedora-release ]; then
        echo "fedora"
    else
        echo "unknown"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get system information
get_system_info() {
    log_info "System Information:"
    echo "  OS: $(uname -s)"
    echo "  Kernel: $(uname -r)"
    echo "  Architecture: $(uname -m)"
    echo "  Distribution: $(detect_distro)"
    echo "  Uptime: $(uptime -p)"
    echo "  Memory: $(free -h | awk 'NR==2{print $2}')"
    echo "  Disk: $(df -h / | awk 'NR==2{print $2}')"
}

# Generate random password
generate_password() {
    local length=${1:-16}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# Create temporary directory
create_temp_dir() {
    local temp_dir=$(mktemp -d)
    echo "$temp_dir"
}

# Cleanup temporary directory
cleanup_temp_dir() {
    local temp_dir=$1
    if [ -n "$temp_dir" ] && [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
        log_debug "Cleaned up temporary directory: $temp_dir"
    fi
}

# Wait for user input
wait_for_user() {
    local message=${1:-"Press Enter to continue..."}
    read -p "$message"
}

# Confirm action
confirm() {
    local message=$1
    local default=${2:-"n"}
    
    if [ "$default" = "y" ]; then
        read -p "$message (Y/n): " response
        response=${response:-y}
    else
        read -p "$message (y/N): " response
        response=${response:-n}
    fi
    
    [[ "$response" =~ ^[Yy]$ ]]
}

# Show progress bar
progress_bar() {
    local current=$1
    local total=$2
    local width=${3:-50}
    local description=${4:-"Progress"}
    
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${BLUE}[INFO]${NC} %s [%s%s] %d%% (%d/%d)" \
        "$description" \
        "$(printf "%*s" $filled | tr ' ' '=')" \
        "$(printf "%*s" $empty | tr ' ' '-')" \
        "$percent" \
        "$current" \
        "$total"
    
    if [ $current -eq $total ]; then
        echo
    fi
}

# Countdown timer
countdown() {
    local seconds=$1
    local message=${2:-"Waiting"}
    
    while [ $seconds -gt 0 ]; do
        printf "\r${YELLOW}[INFO]${NC} %s: %d seconds remaining..." "$message" $seconds
        sleep 1
        ((seconds--))
    done
    echo
}

# Check if running in terminal
is_terminal() {
    [ -t 1 ]
}

# Get terminal size
get_terminal_size() {
    if is_terminal; then
        echo "$(tput cols) $(tput lines)"
    else
        echo "80 24"
    fi
}

# Print separator line
print_separator() {
    local char=${1:-"="}
    local width=${2:-80}
    printf "%*s\n" $width | tr ' ' "$char"
}

# Print header
print_header() {
    local title=$1
    local width=${2:-80}
    
    print_separator "=" $width
    printf "%*s\n" $(((width + ${#title}) / 2)) "$title"
    print_separator "=" $width
}

# Print menu
print_menu() {
    local title=$1
    shift
    local options=("$@")
    
    print_header "$title"
    for i in "${!options[@]}"; do
        echo "$((i+1)). ${options[i]}"
    done
    echo
}

# Get user choice
get_user_choice() {
    local max=$1
    local prompt=${2:-"Enter your choice"}
    
    while true; do
        read -p "$prompt (1-$max): " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$max" ]; then
            echo $choice
            return
        else
            log_error "Invalid choice. Please enter a number between 1 and $max."
        fi
    done
}

# Export functions
export -f detect_distro command_exists get_system_info generate_password create_temp_dir cleanup_temp_dir
export -f wait_for_user confirm progress_bar countdown is_terminal get_terminal_size print_separator print_header print_menu get_user_choice
