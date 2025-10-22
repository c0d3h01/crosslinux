# Linux Installation Script

Automated Linux installation script with modular architecture supporting Ubuntu, Arch Linux, and Fedora.

## Usage

```bash
sudo ./install.sh
```

## Features

- **Modular Design**: Separated functions into individual modules
- **Multi-Distribution**: Supports Ubuntu, Arch Linux, and Fedora
- **Complete Setup**: Partitioning, filesystem, packages, configuration, services
- **GNOME Desktop**: Full GNOME desktop environment
- **Error Handling**: Comprehensive error handling and recovery

## Structure

```txt
archinstall/
├── install.sh                    # Main installer script
└── lib/                          # Modular library
    ├── core/                     # Core utilities
    │   ├── logging.sh           # Logging system
    │   ├── config.sh            # Configuration management
    │   ├── errors.sh             # Error handling
    │   └── utils.sh              # Utility functions
    ├── disk/                     # Disk operations
    │   ├── partition.sh         # Partitioning functions
    │   └── filesystem.sh        # Filesystem management
    ├── install/                  # Installation modules
    │   ├── packages.sh          # Package installation
    │   └── bootloader.sh        # Bootloader installation
    ├── config/                   # Configuration modules
    │   ├── system.sh            # System configuration
    │   └── desktop.sh           # Desktop configuration
    └── services/                 # Service modules
        ├── network.sh           # Network services
        ├── desktop.sh           # Desktop services
        └── system.sh             # System services
```

## Requirements

- Root access
- Internet connection
- Minimum 20GB free space
- UEFI system recommended

## Installation Process

1. **System Detection**: Automatically detects Ubuntu/Arch/Fedora
2. **Configuration**: Interactive setup
3. **Partitioning**: GPT partitioning with UEFI support (Arch/Ubuntu) or existing partitions (Fedora)
4. **Filesystem**: Btrfs (Arch), Ext4 (Ubuntu), or existing (Fedora)
5. **Packages**: Essential packages and GNOME desktop
6. **Configuration**: System and desktop setup
7. **Services**: Network, desktop, and system services
8. **Bootloader**: GRUB installation (Arch/Ubuntu) or existing bootloader (Fedora)

## Modules

### Core Modules

- **Logging**: Color-coded output, progress indicators
- **Configuration**: Interactive setup, persistence
- **Error Handling**: Comprehensive error recovery
- **Utilities**: System detection, user interaction

### Disk Modules

- **Partitioning**: GPT partitioning, UEFI support
- **Filesystem**: Btrfs subvolumes, Ext4 support

### Installation Modules

- **Packages**: Distribution-specific package installation
- **Bootloader**: GRUB installation and configuration

### Configuration Modules

- **System**: Timezone, locale, users, sudo
- **Desktop**: GNOME setup, GDM configuration

### Service Modules

- **Network**: NetworkManager, firewall
- **Desktop**: GDM, audio services
- **System**: Essential system services

## Customization

Each module can be used independently for custom installations:

```bash
# Load specific modules
source lib/core/logging.sh
source lib/disk/partition.sh

# Use functions
log_info "Starting custom installation"
create_arch_partitions "/dev/nvme0n1"
```
