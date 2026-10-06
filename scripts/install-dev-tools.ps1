param(
    [string]$Group = 'web'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-NormalizedGroupName {
    param(
        [string]$GroupName = 'web'
    )

    if ([string]::IsNullOrWhiteSpace($GroupName)) {
        return 'web'
    }

    return $GroupName.Trim().ToLowerInvariant()
}

function Get-InstallerConfig {
    $scriptRoot = $PSScriptRoot
    $configPath = Join-Path $scriptRoot '..\config\dev-tools.json'
    $configPath = [System.IO.Path]::GetFullPath($configPath)

    if (-not (Test-Path $configPath)) {
        throw "Configuration file not found: $configPath"
    }

    try {
        $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
    }
    catch {
        throw "Failed to parse config file: $configPath. Check the JSON syntax."
    }

    if (-not $config.tools) {
        throw 'The config file does not contain a valid tools array.'
    }

    return $config
}

function Validate-ToolDefinition {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Tool
    )

    if (-not $Tool.name) {
        return $false
    }

    return ($Tool.winget -or $Tool.choco)
}

function Get-ToolsForGroup {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Config,
        [string]$GroupName = 'web'
    )

    $normalizedGroup = Get-NormalizedGroupName -GroupName $GroupName
    if ($normalizedGroup -eq 'all') {
        return @($Config.tools)
    }

    $selectedTools = @()
    foreach ($tool in @($Config.tools)) {
        $groups = @()
        if ($tool.groups) {
            $groups = @($tool.groups)
        }

        foreach ($group in $groups) {
            if ((($group -as [string]).Trim().ToLowerInvariant()) -eq $normalizedGroup) {
                $selectedTools += $tool
                break
            }
        }
    }

    return $selectedTools
}

function Resolve-InstallMethod {
    param(
        [bool]$WingetAvailable = $false,
        [bool]$ChocoAvailable = $false
    )

    if ($WingetAvailable) {
        return 'winget'
    }

    if ($ChocoAvailable) {
        return 'choco'
    }

    return 'none'
}

function Install-Chocolatey {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        return
    }

    Write-Host '[INFO] Chocolatey not found. Installing it now...' -ForegroundColor Yellow
    $installScript = 'https://community.chocolatey.org/install.ps1'

    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString($installScript))
    }
    catch {
        throw "Failed to install Chocolatey. Please install it manually from https://chocolatey.org/install and rerun this script."
    }

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        throw 'Chocolatey installation did not complete successfully.'
    }
}

function Ensure-Winget {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        return $true
    }

    return $false
}

function Test-WingetPackageInstalled {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId
    )

    $output = winget list --id $PackageId --exact --accept-source-agreements --accept-package-agreements 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    return ($output | Select-String -Pattern [regex]::Escape($PackageId) -Quiet)
}

function Test-ChocoPackageInstalled {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageName
    )

    $output = choco list --local-only --exact --limit-output 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    return ($output | Select-String -Pattern "^$([regex]::Escape($PackageName))$" -Quiet)
}

function Test-InstallFailureIsAlreadyInstalled {
    param(
        [AllowEmptyCollection()]
        [string[]]$Output
    )

    if (-not $Output) {
        return $false
    }

    $combinedText = ($Output | Out-String).ToLowerInvariant()
    $knownMessages = @(
        'already installed',
        'already exists',
        'is already installed',
        'already present',
        'was already installed',
        'this package is already installed'
    )

    foreach ($message in $knownMessages) {
        if ($combinedText.Contains($message)) {
            return $true
        }
    }

    return $false
}

function Install-WithWinget {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Package
    )

    $packageName = $Package.name
    $packageId = $Package.winget

    if (-not $packageId) {
        throw "The package '$packageName' is missing a winget ID."
    }

    Write-Host "[CHECK] $packageName ($packageId)" -ForegroundColor DarkYellow

    if (Test-WingetPackageInstalled -PackageId $packageId) {
        Write-Host "[SKIP] $packageName is already installed." -ForegroundColor Green
        return $true
    }

    Write-Host "[INSTALL] Installing $packageName via winget..." -ForegroundColor Yellow

    try {
        $installOutput = & winget install --id $packageId --exact --accept-source-agreements --accept-package-agreements 2>&1 | Tee-Object -Variable wingetOutput

        if ($LASTEXITCODE -ne 0) {
            if (Test-WingetPackageInstalled -PackageId $packageId) {
                Write-Host "[SKIP] $packageName is already installed on this machine." -ForegroundColor Green
                return $true
            }

            if (Test-InstallFailureIsAlreadyInstalled -Output @($wingetOutput)) {
                Write-Host "[SKIP] $packageName is already installed on this machine." -ForegroundColor Green
                return $true
            }

            throw "winget exited with code $LASTEXITCODE"
        }
    }
    catch {
        Write-Host "[ERROR] Failed to install $packageName via winget. $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }

    Write-Host "[OK] $packageName installed successfully." -ForegroundColor Green
    return $true
}

function Install-WithChoco {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Package
    )

    $packageName = $Package.name
    $packageId = $Package.choco

    if (-not $packageId) {
        throw "The package '$packageName' is missing a Chocolatey package name."
    }

    Write-Host "[CHECK] $packageName ($packageId)" -ForegroundColor DarkYellow

    if (Test-ChocoPackageInstalled -PackageName $packageId) {
        Write-Host "[SKIP] $packageName is already installed." -ForegroundColor Green
        return $true
    }

    Write-Host "[INSTALL] Installing $packageName via Chocolatey..." -ForegroundColor Yellow

    try {
        $installOutput = & choco install $packageId -y --verbose 2>&1 | Tee-Object -Variable chocoOutput

        if ($LASTEXITCODE -ne 0) {
            if (Test-ChocoPackageInstalled -PackageName $packageId) {
                Write-Host "[SKIP] $packageName is already installed on this machine." -ForegroundColor Green
                return $true
            }

            if (Test-InstallFailureIsAlreadyInstalled -Output @($chocoOutput)) {
                Write-Host "[SKIP] $packageName is already installed on this machine." -ForegroundColor Green
                return $true
            }

            throw "choco exited with code $LASTEXITCODE"
        }
    }
    catch {
        Write-Host "[ERROR] Failed to install $packageName via Chocolatey. $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }

    Write-Host "[OK] $packageName installed successfully." -ForegroundColor Green
    return $true
}

function Install-Package {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Package
    )

    $packageName = $Package.name
    $failedPackages = @()

    try {
        if (Ensure-Winget) {
            $installed = Install-WithWinget -Package $Package
        }
        else {
            Install-Chocolatey
            $installed = Install-WithChoco -Package $Package
        }

        if (-not $installed) {
            $failedPackages += $packageName
        }
    }
    catch {
        Write-Host "[ERROR] Unexpected failure for ${packageName}: $($_.Exception.Message)" -ForegroundColor Red
        $failedPackages += $packageName
    }

    Write-Host ''
    return @($failedPackages)
}

function Run-Installer {
    param(
        [string]$GroupName = 'web'
    )

    $config = Get-InstallerConfig
    $failedPackages = @()
    $requestedGroup = Get-NormalizedGroupName -GroupName $GroupName

    if ($requestedGroup -notin @('web', 'native', 'all')) {
        throw "Unsupported installer group '$GroupName'. Use one of: web, native, all."
    }

    $selectedTools = Get-ToolsForGroup -Config $config -GroupName $requestedGroup
    if ($selectedTools.Count -eq 0) {
        throw "No tools are configured for the '$requestedGroup' group."
    }

    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ' Dev Essentials Installer' -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan
    $configPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\config\dev-tools.json'))
    Write-Host "Loading configuration from: $configPath" -ForegroundColor DarkCyan
    Write-Host "Selected installer group: $requestedGroup" -ForegroundColor Magenta

    $totalPackages = @($selectedTools).Count
    Write-Host "Found $totalPackages packages to validate." -ForegroundColor Cyan

    foreach ($tool in $selectedTools) {
        if (-not (Validate-ToolDefinition -Tool $tool)) {
            Write-Warning "Skipping package '$($tool.name)' because it is missing both winget and Chocolatey IDs."
            continue
        }

        $packageResult = Install-Package -Package $tool
        if (@($packageResult).Count -gt 0) {
            $failedPackages += @($packageResult)
        }
    }

    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ' Installation Summary' -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan

    if ($failedPackages.Count -gt 0) {
        Write-Host '[SUMMARY] Some installations failed:' -ForegroundColor Red
        foreach ($item in $failedPackages) {
            Write-Host "  - $item" -ForegroundColor Red
        }
        Write-Host 'You may need to restart your terminal or rerun the installer after fixing the failed package(s).' -ForegroundColor Yellow
        exit 1
    }

    Write-Host "[SUMMARY] All requested tools for the '$requestedGroup' group are installed or already present." -ForegroundColor Green
    Write-Host 'You may need to reopen your terminal before using newly installed tools.' -ForegroundColor Yellow
    exit 0
}

if ($MyInvocation.InvocationName -ne '.') {
    Run-Installer -GroupName $Group
}
