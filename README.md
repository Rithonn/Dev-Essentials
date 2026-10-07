# Dev Essentials Installer

This project provides setup scripts for Windows, macOS, and Debian/Ubuntu Linux development environments.

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

The Windows installer uses:

- `winget` when available
- `Chocolatey` as a fallback installer
- automatic Chocolatey installation if it is missing

The Bash installer uses Homebrew on macOS and APT on Debian/Ubuntu Linux.

## Windows quick start

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

## macOS and Linux quick start

The Bash installer supports macOS with Homebrew and Debian/Ubuntu Linux with APT. Install Homebrew first on macOS. On Linux, the script uses `sudo` for system package installation.

Run the interactive installer:

```sh
bash scripts/install-dev-tools.sh
```

You can also select a group and upgrade mode directly:

```sh
bash scripts/install-dev-tools.sh web
bash scripts/install-dev-tools.sh native --upgrade
bash scripts/install-dev-tools.sh all --dry-run
```

On Debian/Ubuntu, packages that are not available in the enabled APT repositories are reported as unavailable instead of adding external repositories automatically. Docker installs Docker Engine (`docker.io`), not Docker Desktop. WSL is Windows-only and is skipped.

## Customizing the package list

Edit [config/dev-tools.json](config/dev-tools.json) to add or remove Windows packages. The Homebrew and APT mappings for the Bash installer are maintained in [scripts/install-dev-tools.sh](scripts/install-dev-tools.sh).

## Project layout

- [scripts/install-dev-tools.bat](scripts/install-dev-tools.bat) — Windows launcher
- [scripts/install-dev-tools.ps1](scripts/install-dev-tools.ps1) — installer logic
- [scripts/install-dev-tools.sh](scripts/install-dev-tools.sh) — macOS and Debian/Ubuntu installer
- [config/dev-tools.json](config/dev-tools.json) — package configuration

## Testing

A basic automated test script is included in [tests/installer-tests.ps1](tests/installer-tests.ps1). It validates:

- the config file loads correctly
- the .NET SDK entry exists
- tool definitions are valid
- the install method resolves correctly to `winget` or `choco`

Run it with:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\installer-tests.ps1`
- `bash -n scripts/install-dev-tools.sh` to check Bash syntax

## Security considerations

- Windows installation requires Administrator privileges; Linux package installation uses `sudo`. These installers make system-level changes. Review the scripts and package list before running them, and only run a copy you trust.
- Packages are downloaded from configured `winget`, Chocolatey, Homebrew, or APT sources. Package versions are not pinned, so package contents and available versions may change over time, especially when using upgrade mode.
- If `winget` is unavailable, the installer downloads Chocolatey's install script over HTTPS and executes it. This bootstrap script is not pinned to a version or verified against a checksum by this project.
- The macOS installer requires Homebrew to be installed already. It does not bootstrap Homebrew.
- The launcher's `-ExecutionPolicy Bypass` and the Chocolatey bootstrap's process-scoped execution policy change apply only to the installer process; they do not permanently change the system or user's PowerShell policy.
- Do not add credentials, API keys, or other secrets to the repository or package configuration.

## Notes

- The installer is designed to be rerun; already-installed packages are skipped unless `-Upgrade` is specified.
- With `-Upgrade` on Windows or `--upgrade` on macOS/Linux, installed packages are checked and upgraded when the package manager reports an available update; missing packages are installed as usual.
- The script is tailored for .NET backend, web, cloud, and Python-based development workflows.
