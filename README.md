# archinstall

Professional, JSON-driven Advanced Arch Linux Installation Script

---

## Overview

**archinstall** is a modular Bash script designed to automate Arch Linux installation using a JSON config. It supports disk setup, Btrfs subvolumes, multi-user creation, system configuration, and more.  
It is suitable for personal, professional, and reproducible deployments.

---

## Directory Structure

```
.
├── src/                  # Main scripts
│   └── archinstall.sh
├── config/             # Example configs
│   └── user_config.json
├── docs/                 # Documentation
│   ├── architecture.md
│   └── usage.md
├── .github/
│   └── workflows/
│       └── checks.yml
├── LICENSE
├── README.md
└── .gitignore
```

---

## Quick Start

1. **Edit or copy** `config/user_config.json` to set your installation preferences.
2. **Boot from Arch ISO**, and download the script and config:
    ```bash
    git clone https://github.com/youruser/archinstall.git
    cd archinstall
    sudo bash src/archinstall.sh config/user_config.json
    ```
3. **Review the log:** Output is saved to `archinstall.log`.
4. **See `docs/usage.md`** for advanced options and troubleshooting.

---

## Features

- JSON-based configuration for users, drive, locale, timezone, etc.
- Auto/manual disk selection and full Btrfs setup
- Multi-user creation with custom groups/shells
- Modular, extensible Bash code
- Logging and error handling
- Easy to add new features (services, DEs, package sets)

---

## Contributing

PRs welcome! See `docs/architecture.md` for guidelines.

---

## License

MIT License