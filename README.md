# archinstall

Automated Arch Linux installation script for quick and reproducible system setup.

## Features

- Interactive drive selection with safety confirmations
- Automatic partitioning and formatting (Btrfs + EFI)
- Installs essential base packages and tools
- Customizable via JSON config for hostname, timezone, users, etc.
- User creation with group and shell selection
- Automated basic system configuration (locale, hosts, etc.)
- Enables basic services (NetworkManager, firewalld)
- Logging of all actions

## Usage

1. **Clone the repository:**

   ```bash
   git clone https://github.com/c0d3h01/archinstall.git
   cd archinstall
   ```

2. **Customize your config:**

   Edit `config/user_config.json` to match your preferred hostname, timezone, and user accounts.

   Example:
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

   If `"drive": "auto"` is set, the script will prompt you to select a target disk.

4. **Reboot after completion.**

## Requirements

- Arch Linux live environment
- Internet connection
- Script auto-installs required tools (`jq`, `sgdisk`, `btrfs-progs`, etc.)

## Notes

- **Warning:** This script will wipe the selected drive.
- All actions are logged to `archinstall.log`.
- Review and adjust config and script as needed for custom requirements.

## License

MIT
