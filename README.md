# archinstall

[![archinstall Checks](https://github.com/c0d3h01/archinstall/actions/workflows/checks.yml/badge.svg)](https://github.com/c0d3h01/archinstall/actions/workflows/checks.yml)

Automated Arch Linux installation script for quick, reproducible system setup.

## Features

- Interactive, safe drive selection (with confirmation)
- Automatic partitioning (EFI + Btrfs)
- Installs Arch base system and essential tools
- Fully customizable via JSON config (hostname, users, locale, etc.)
- User creation with groups/shell setup
- Enables basic services (NetworkManager, firewalld)
- Actions are logged to `archinstall.log`

## Usage

1. **Clone the repository:**

   ```bash
   git clone https://github.com/c0d3h01/archinstall.git
   cd archinstall
   ```

2. **Edit your config:**

   Edit `config/user_config.json`:

   ```json
   {
     "drive": "auto",
     "hostname": "archbox",
     "timezone": "Asia/Kolkata",
     "locale": "en_IN.UTF-8",
     "users": [
       {
         "name": "username",
         "password": "your_password_here",
         "groups": "wheel,docker",
         "shell": "/bin/zsh"
       }
     ]
   }
   ```

3. **Run the installer:**

   ```bash
   chmod +x ./src/archinstall.sh
   sudo ./src/archinstall.sh config/user_config.json
   ```

   If `"drive": "auto"` is set, you'll be prompted to select the target disk.

4. **Reboot when finished.**

## Requirements

- Arch Linux live environment
- Internet connection
- Required tools will be auto-installed if missing (`jq`, `sgdisk`, etc.)

## Notes

- **Warning:** The selected drive will be wiped.
- All actions are logged.
- Review your config before proceeding.

## License

MIT