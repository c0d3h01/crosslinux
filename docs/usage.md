# Usage Guide

## Requirements

- Arch Linux live ISO environment
- Internet connection
- Tools: `jq`, `sgdisk`, `btrfs-progs`, `mkfs.fat`, `pacstrap`, `arch-chroot`, `reflector`

## Steps

1. **Edit your configuration:**
   - Copy `config/user_config.json` and modify as needed.

2. **Boot from Arch ISO and get the repo:**
   ```bash
   git clone https://github.com/youruser/archinstall.git
   cd archinstall
   ```

3. **Run the installer:**
   ```bash
   sudo bash src/archinstall.sh config/user_config.json
   ```

4. **Follow any prompts for disk selection.**
5. **All output is logged to `archinstall.log`.**

## Customization

- Add users in the JSON.
- Change package lists in `src/archinstall.sh`.
- Extend with additional features as needed.

## Troubleshooting

- Check `archinstall.log` for errors.
- Ensure all required tools are installed (the script will fail if any are missing).
- If you encounter partition or mounting errors, verify you are running from a live ISO and the target drive is unmounted.

## Extending

- See `docs/architecture.md` for guidelines on adding modules, package sets, or services.