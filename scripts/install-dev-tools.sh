#!/usr/bin/env bash

set -uo pipefail

GROUP=''
UPGRADE=false
UPGRADE_SELECTED=false
DRY_RUN=false
MANAGER=''
INSTALLED_COUNT=0
SKIPPED_COUNT=0
UNAVAILABLE_COUNT=0
FAILED_COUNT=0
declare -a UNAVAILABLE_PACKAGES=()
declare -a FAILED_PACKAGES=()

usage() {
    cat <<'EOF'
Usage: bash scripts/install-dev-tools.sh [web|native|all] [--upgrade] [--dry-run]

Without a group, the installer prompts for a group and upgrade behavior.
--upgrade  Upgrade installed packages when updates are available.
--dry-run  Print package-manager commands without making changes.
EOF
}

while (($# > 0)); do
    case "$1" in
        web|native|all)
            if [[ -n "$GROUP" ]]; then
                printf 'Only one group may be selected.\n' >&2
                exit 2
            fi
            GROUP="$1"
            ;;
        --upgrade|-Upgrade)
            UPGRADE=true
            UPGRADE_SELECTED=true
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

if [[ -z "$GROUP" ]]; then
    if [[ ! -t 0 ]]; then
        printf 'Choose a group (web, native, or all) when running non-interactively.\n' >&2
        usage >&2
        exit 2
    fi

    printf 'Select the tools to install:\n  1. Web development\n  2. Native development (C/C++)\n  3. All tools\n'
    while true; do
        read -r -p 'Enter 1, 2, or 3: ' choice
        case "$choice" in
            1) GROUP='web'; break ;;
            2) GROUP='native'; break ;;
            3) GROUP='all'; break ;;
            *) printf 'Please enter 1, 2, or 3.\n' ;;
        esac
    done

    if [[ "$UPGRADE_SELECTED" == false ]]; then
        printf 'How should installed tools be handled?\n  1. Skip installed tools\n  2. Check for and install available upgrades\n'
        while true; do
            read -r -p 'Enter 1 or 2: ' choice
            case "$choice" in
                1) UPGRADE=false; break ;;
                2) UPGRADE=true; break ;;
                *) printf 'Please enter 1 or 2.\n' ;;
            esac
        done
    fi
fi

if [[ "${OSTYPE:-}" == darwin* ]]; then
    MANAGER='brew'
    if ! command -v brew >/dev/null 2>&1; then
        printf 'Homebrew is required on macOS. Install it from https://brew.sh and rerun this script.\n' >&2
        exit 1
    fi
elif [[ -r /etc/os-release ]]; then
    os_family=$(. /etc/os-release && printf '%s %s' "${ID:-}" "${ID_LIKE:-}")
    if [[ "$os_family" == *debian* || "$os_family" == *ubuntu* ]] && command -v apt-get >/dev/null 2>&1; then
        MANAGER='apt'
    else
        printf 'This Linux installer currently supports Debian/Ubuntu systems with APT. Detected: %s\n' "$os_family" >&2
        exit 1
    fi
else
    printf 'Unsupported operating system. Use the Windows batch installer, macOS with Homebrew, or Debian/Ubuntu with APT.\n' >&2
    exit 1
fi

package_spec() {
    local tool="$1"

    if [[ "$MANAGER" == brew ]]; then
        case "$tool" in
            git) printf 'formula|git' ;;
            github-cli) printf 'formula|gh' ;;
            dotnet) printf 'cask|dotnet-sdk' ;;
            python) printf 'formula|python@3.12' ;;
            node) printf 'formula|node' ;;
            vscode) printf 'cask|visual-studio-code' ;;
            docker) printf 'cask|docker' ;;
            azure-cli) printf 'formula|azure-cli' ;;
            postgresql) printf 'formula|postgresql@18' ;;
            mysql) printf 'formula|mysql' ;;
            cmake) printf 'formula|cmake' ;;
            llvm) printf 'formula|llvm' ;;
            mingw) printf 'formula|mingw-w64' ;;
            *) return 1 ;;
        esac
    else
        case "$tool" in
            git) printf 'package|git' ;;
            github-cli) printf 'package|gh' ;;
            dotnet) printf 'package|dotnet-sdk-8.0' ;;
            python) printf 'package|python3' ;;
            node) printf 'package|nodejs' ;;
            vscode) printf 'package|code' ;;
            docker) printf 'package|docker.io' ;;
            azure-cli) printf 'package|azure-cli' ;;
            postgresql) printf 'package|postgresql' ;;
            mysql) printf 'package|mysql-server' ;;
            cmake) printf 'package|cmake' ;;
            llvm) printf 'package|llvm' ;;
            mingw) printf 'package|mingw-w64' ;;
            *) return 1 ;;
        esac
    fi
}

run_command() {
    if [[ "$DRY_RUN" == true ]]; then
        printf '[DRY RUN]'
        printf ' %q' "$@"
        printf '\n'
        return 0
    fi

    "$@"
}

run_privileged() {
    if [[ "$EUID" -eq 0 ]]; then
        run_command "$@"
    elif command -v sudo >/dev/null 2>&1; then
        run_command sudo "$@"
    else
        printf 'sudo is required to install system packages.\n' >&2
        return 1
    fi
}

is_installed() {
    local kind="$1"
    local package="$2"

    if [[ "$MANAGER" == brew ]]; then
        brew list "--$kind" --versions "$package" >/dev/null 2>&1
    else
        dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q '^install ok installed$'
    fi
}

process_tool() {
    local tool="$1"
    local label="$2"
    local spec kind package installed=false

    if [[ "$tool" == wsl ]]; then
        printf '[SKIP] WSL 2 is Windows-only; it is not needed on macOS/Linux.\n'
        ((SKIPPED_COUNT += 1))
        return
    fi

    if ! spec=$(package_spec "$tool"); then
        printf '[ERROR] No %s package mapping for %s.\n' "$MANAGER" "$label"
        FAILED_PACKAGES+=("$label")
        ((FAILED_COUNT += 1))
        return
    fi
    IFS='|' read -r kind package <<< "$spec"

    if [[ "$MANAGER" == apt && "$DRY_RUN" == false ]] && ! apt-cache show "$package" >/dev/null 2>&1; then
        printf '[UNAVAILABLE] %s (%s) is not in the enabled APT repositories; install its vendor repository or install it manually.\n' "$label" "$package"
        UNAVAILABLE_PACKAGES+=("$label")
        ((UNAVAILABLE_COUNT += 1))
        return
    fi

    printf '[CHECK] %s (%s)\n' "$label" "$package"
    if [[ "$DRY_RUN" == false ]] && is_installed "$kind" "$package"; then
        installed=true
    fi

    if [[ "$installed" == true && "$UPGRADE" == false ]]; then
        printf '[SKIP] %s is already installed.\n' "$label"
        ((SKIPPED_COUNT += 1))
        return
    fi

    if [[ "$MANAGER" == brew ]]; then
        if [[ "$installed" == true ]]; then
            local outdated
            if ! outdated=$(brew outdated "--$kind" --quiet "$package"); then
                printf '[ERROR] Could not check for updates to %s.\n' "$label" >&2
                FAILED_PACKAGES+=("$label")
                ((FAILED_COUNT += 1))
                return
            fi
            if [[ -z "$outdated" ]]; then
                printf '[SKIP] %s is already up to date.\n' "$label"
                ((SKIPPED_COUNT += 1))
                return
            fi
            printf '[UPGRADE] Updating %s with Homebrew...\n' "$label"
            if run_command brew upgrade "--$kind" "$package"; then
                ((INSTALLED_COUNT += 1))
            else
                FAILED_PACKAGES+=("$label")
                ((FAILED_COUNT += 1))
            fi
        else
            printf '[INSTALL] Installing %s with Homebrew...\n' "$label"
            if run_command brew install "--$kind" "$package"; then
                ((INSTALLED_COUNT += 1))
            else
                FAILED_PACKAGES+=("$label")
                ((FAILED_COUNT += 1))
            fi
        fi
    elif [[ "$installed" == true ]]; then
        printf '[UPGRADE] Checking for updates to %s with APT...\n' "$label"
        if run_privileged apt-get install --only-upgrade -y "$package"; then
            ((INSTALLED_COUNT += 1))
        else
            FAILED_PACKAGES+=("$label")
            ((FAILED_COUNT += 1))
        fi
    else
        printf '[INSTALL] Installing %s with APT...\n' "$label"
        if run_privileged apt-get install -y "$package"; then
            ((INSTALLED_COUNT += 1))
        else
            FAILED_PACKAGES+=("$label")
            ((FAILED_COUNT += 1))
        fi
    fi
}

printf '========================================\n Dev Essentials Installer (%s)\n========================================\n' "$MANAGER"
printf 'Selected installer group: %s\n' "$GROUP"
if [[ "$UPGRADE" == true ]]; then
    printf 'Upgrade mode: enabled\n'
else
    printf 'Upgrade mode: disabled; installed packages will be skipped\n'
fi

if [[ "$MANAGER" == apt && "$DRY_RUN" == false ]]; then
    printf '[INFO] Refreshing APT package indexes...\n'
    if ! run_privileged apt-get update; then
        printf '[ERROR] Failed to refresh APT package indexes.\n' >&2
        exit 1
    fi
fi

case "$GROUP" in
    web)
        process_tool git 'Git'
        process_tool github-cli 'GitHub CLI'
        process_tool dotnet '.NET SDK'
        process_tool python 'Python'
        process_tool node 'Node.js LTS'
        process_tool vscode 'Visual Studio Code'
        process_tool docker 'Docker'
        process_tool azure-cli 'Azure CLI'
        process_tool postgresql 'PostgreSQL'
        process_tool mysql 'MySQL Server'
        ;;
    native)
        process_tool git 'Git'
        process_tool github-cli 'GitHub CLI'
        process_tool vscode 'Visual Studio Code'
        process_tool cmake 'CMake'
        process_tool llvm 'LLVM'
        process_tool mingw 'MinGW-w64'
        process_tool wsl 'WSL 2 with Ubuntu'
        ;;
    all)
        process_tool git 'Git'
        process_tool github-cli 'GitHub CLI'
        process_tool dotnet '.NET SDK'
        process_tool python 'Python'
        process_tool node 'Node.js LTS'
        process_tool vscode 'Visual Studio Code'
        process_tool docker 'Docker'
        process_tool azure-cli 'Azure CLI'
        process_tool postgresql 'PostgreSQL'
        process_tool mysql 'MySQL Server'
        process_tool cmake 'CMake'
        process_tool llvm 'LLVM'
        process_tool mingw 'MinGW-w64'
        process_tool wsl 'WSL 2 with Ubuntu'
        ;;
esac

printf '========================================\n Installation Summary\n========================================\n'
printf '[SUMMARY] Installed or upgraded: %d; skipped: %d; unavailable: %d; failed: %d\n' \
    "$INSTALLED_COUNT" "$SKIPPED_COUNT" "$UNAVAILABLE_COUNT" "$FAILED_COUNT"
if ((${#UNAVAILABLE_PACKAGES[@]} > 0)); then
    printf '[SUMMARY] Configure a vendor repository or install these manually: %s\n' "${UNAVAILABLE_PACKAGES[*]}"
fi
if ((${#FAILED_PACKAGES[@]} > 0)); then
    printf '[SUMMARY] Failed packages: %s\n' "${FAILED_PACKAGES[*]}" >&2
    exit 1
fi

if [[ "$DRY_RUN" == true ]]; then
    printf '[SUMMARY] Dry run complete; no packages were changed.\n'
elif ((UNAVAILABLE_COUNT > 0)); then
    printf '[SUMMARY] Finished with packages unavailable from the configured repositories.\n'
else
    printf '[SUMMARY] All supported package actions completed.\n'
fi