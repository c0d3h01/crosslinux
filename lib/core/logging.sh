#!/usr/bin/env bash
# -*- Core Logging Module -*-

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Logging levels
readonly LOG_LEVEL_ERROR=0
readonly LOG_LEVEL_WARNING=1
readonly LOG_LEVEL_INFO=2
readonly LOG_LEVEL_DEBUG=3

# Default log level
LOG_LEVEL=${LOG_LEVEL:-2}

# Logging functions
log_error() {
    if [ $LOG_LEVEL -ge $LOG_LEVEL_ERROR ]; then
        echo -e "${RED}[ERROR]${NC} $*" >&2
    fi
}

log_warning() {
    if [ $LOG_LEVEL -ge $LOG_LEVEL_WARNING ]; then
        echo -e "${YELLOW}[WARNING]${NC} $*" >&2
    fi
}

log_info() {
    if [ $LOG_LEVEL -ge $LOG_LEVEL_INFO ]; then
        echo -e "${BLUE}[INFO]${NC} $*"
    fi
}

log_success() {
    if [ $LOG_LEVEL -ge $LOG_LEVEL_INFO ]; then
        echo -e "${GREEN}[SUCCESS]${NC} $*"
    fi
}

log_debug() {
    if [ $LOG_LEVEL -ge $LOG_LEVEL_DEBUG ]; then
        echo -e "${PURPLE}[DEBUG]${NC} $*"
    fi
}

log_step() {
    if [ $LOG_LEVEL -ge $LOG_LEVEL_INFO ]; then
        echo -e "${CYAN}[STEP]${NC} $*"
    fi
}

# Progress indicator
show_progress() {
    local current=$1
    local total=$2
    local description=${3:-"Processing"}
    
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
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

# Spinner for long operations
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Export functions
export -f log_error log_warning log_info log_success log_debug log_step show_progress spinner
