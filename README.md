# Dev Essentials Installer

This project gives a developer a one-click Windows setup for .NET and web development work. It is designed to install the essentials without manual setup.

## Included tooling

The installer supports multiple setup groups:

### Web development

- Git
- GitHub CLI
- .NET SDK
- Python
- Node.js LTS
- Visual Studio Code
- Docker Desktop
- Azure CLI
- PostgreSQL
- MySQL Server

### Native development (C and C++)

- Git
- GitHub CLI
- Visual Studio Code
- CMake
- LLVM
- MinGW
- WSL 2 with Ubuntu

## Package managers

The installer uses:

- `winget` when available
- `Chocolatey` as a fallback installer
- automatic Chocolatey installation if it is missing

## Quick start

1. Open a Windows terminal in this folder.
2. Run `scripts\install-dev-tools.bat` and choose a tool group and upgrade behavior from the prompts.
   You can also run a group directly:
   - `scripts\install-dev-tools.bat web`
   - `scripts\install-dev-tools.bat native`
   - `scripts\install-dev-tools.bat all`
   - `scripts\install-dev-tools.bat web -Upgrade` to upgrade installed tools where updates are available
3. Wait for the installation process to finish.
4. Restart the terminal if prompted.

The native setup enables WSL 2 and installs Ubuntu. Windows may require a restart before WSL is ready; the first Ubuntu launch will prompt you to create a Linux user account.

## Customizing the package list

Edit [config/dev-tools.json](config/dev-tools.json) to add or remove packages. Each entry can define a `winget` package ID and a `choco` package name.

## Project layout

- [scripts/install-dev-tools.bat](scripts/install-dev-tools.bat) — Windows launcher
- [scripts/install-dev-tools.ps1](scripts/install-dev-tools.ps1) — installer logic
- [config/dev-tools.json](config/dev-tools.json) — package configuration

## Testing

A basic automated test script is included in [tests/installer-tests.ps1](tests/installer-tests.ps1). It validates:

- the config file loads correctly
- the .NET SDK entry exists
- tool definitions are valid
- the install method resolves correctly to `winget` or `choco`

Run it with:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\installer-tests.ps1`

## Security considerations

- The installer requires Administrator privileges and makes system-level changes. Review the scripts and package list before running them, and only run a copy you trust.
- Packages are downloaded from the configured `winget` or Chocolatey sources. Package versions are not pinned, so package contents and available versions may change over time, especially when using `-Upgrade`.
- If `winget` is unavailable, the installer downloads Chocolatey's install script over HTTPS and executes it. This bootstrap script is not pinned to a version or verified against a checksum by this project.
- The launcher's `-ExecutionPolicy Bypass` and the Chocolatey bootstrap's process-scoped execution policy change apply only to the installer process; they do not permanently change the system or user's PowerShell policy.
- Do not add credentials, API keys, or other secrets to the repository or package configuration.

## Notes

- The installer is designed to be rerun; already-installed packages are skipped unless `-Upgrade` is specified.
- With `-Upgrade`, installed packages are checked and upgraded when the package manager reports an available update; missing packages are installed as usual.
- The script is tailored for .NET backend, web, cloud, and Python-based development workflows.
