# Project Architecture

## Structure

- `src/archinstall.sh`: Orchestrates the installation, modular functions for each step.
- `config/user_config.json`: All user/system config centralized in JSON.
- `docs/`: Documentation for users and contributors.
- `.github/workflows/`: CI setup for linting and validation.

## Adding Features

1. Add new JSON keys to `user_config.json` and update `load_config()` and relevant functions.
2. Create a new shell function in `src/archinstall.sh`.
3. Call your function from `main()` at the appropriate place.

## Best Practices

- Keep each function focused on a single task.
- Always log actions and errors.
- Validate user input and config before making changes.
- Document any new features in `README.md` and `docs/`.

## Contribution

- Fork, create a feature branch, PR to `main`.
- Ensure `checks.yml` passes before submitting PR.

## License

MIT