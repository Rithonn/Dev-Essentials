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

### Native development (C and C++)

- Git
- GitHub CLI
- Visual Studio Code
- CMake
- LLVM
- MinGW

## Package managers

The installer uses:

- `winget` when available
- `Chocolatey` as a fallback installer
- automatic Chocolatey installation if it is missing

## Quick start

1. Open a Windows terminal in this folder.
2. Run one of the following:
   - `scripts\install-dev-tools.bat` for the default web setup
   - `scripts\install-dev-tools.bat web`
   - `scripts\install-dev-tools.bat native`
   - `scripts\install-dev-tools.bat all`
3. Wait for the installation process to finish.
4. Restart the terminal if prompted.

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

## Notes

- This is safe to run repeatedly.
- Already-installed packages are skipped automatically.
- The script is tailored for .NET backend, web, cloud, and Python-based development workflows.
