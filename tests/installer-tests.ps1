Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw "Assertion failed: $Message"
    }
}

function Assert-Equal {
    param(
        [object]$Actual,
        [object]$Expected,
        [string]$Message
    )

    if ($Actual -ne $Expected) {
        throw "Assertion failed: $Message. Expected '$Expected' but got '$Actual'."
    }
}

$scriptPath = Join-Path $PSScriptRoot '..\scripts\install-dev-tools.ps1'
. $scriptPath

$config = Get-InstallerConfig
Assert-True ($config.tools.Count -ge 1) 'The config should define at least one tool.'

$netTool = $config.tools | Where-Object { $_.name -eq '.NET SDK' }
Assert-True ((@($netTool).Count -gt 0)) 'The .NET SDK tool should be in the configuration.'

Assert-True ((Validate-ToolDefinition -Tool $netTool[0]) -eq $true) 'The .NET SDK definition should be valid.'

$method = Resolve-InstallMethod -WingetAvailable $true -ChocoAvailable $true
Assert-Equal $method 'winget' 'When winget is available it should be chosen first.'

$fallbackMethod = Resolve-InstallMethod -WingetAvailable $false -ChocoAvailable $true
Assert-Equal $fallbackMethod 'choco' 'When winget is unavailable it should fall back to Chocolatey.'

$noMethod = Resolve-InstallMethod -WingetAvailable $false -ChocoAvailable $false
Assert-Equal $noMethod 'none' 'When no package manager is available the installer should report none.'

$installAction = Resolve-PackageAction -IsInstalled $false -UpgradeExisting $true
Assert-Equal $installAction 'install' 'Missing packages should still be installed when upgrade mode is enabled.'

$skipAction = Resolve-PackageAction -IsInstalled $true
Assert-Equal $skipAction 'skip' 'Installed packages should be skipped when upgrade mode is disabled.'

$upgradeAction = Resolve-PackageAction -IsInstalled $true -UpgradeExisting $true
Assert-Equal $upgradeAction 'upgrade' 'Installed packages should be upgraded when upgrade mode is enabled.'

$webTools = Get-ToolsForGroup -Config $config -GroupName 'web'
Assert-True (($webTools.Count -gt 0)) 'The web group should include at least one tool.'

$postgresTool = $webTools | Where-Object { $_.name -eq 'PostgreSQL' }
Assert-True ((@($postgresTool).Count -eq 1)) 'PostgreSQL should be included in the web group.'
Assert-True ((Validate-ToolDefinition -Tool $postgresTool[0]) -eq $true) 'The PostgreSQL definition should be valid.'

$mysqlTool = $webTools | Where-Object { $_.name -eq 'MySQL Server' }
Assert-True ((@($mysqlTool).Count -eq 1)) 'MySQL Server should be included in the web group.'
Assert-True ((Validate-ToolDefinition -Tool $mysqlTool[0]) -eq $true) 'The MySQL Server definition should be valid.'

$nativeTools = Get-ToolsForGroup -Config $config -GroupName 'native'
Assert-True (($nativeTools.Count -gt 0)) 'The native group should include at least one tool.'

$wslTool = $nativeTools | Where-Object { $_.name -eq 'WSL 2 with Ubuntu' }
Assert-True ((@($wslTool).Count -eq 1)) 'WSL 2 with Ubuntu should be included in the native group.'
Assert-True ((Validate-ToolDefinition -Tool $wslTool[0]) -eq $true) 'The WSL 2 installer definition should be valid.'

$allTools = Get-ToolsForGroup -Config $config -GroupName 'all'
Assert-True (($allTools.Count -ge $webTools.Count)) 'The all group should include all tools.'

$singleFailureResult = @('Git')
Assert-True ((@($singleFailureResult).Count -eq 1)) 'Single-item failure results should still be treated as arrays.'

$alreadyInstalledOutput = @(
    'This package is already installed.',
    'Use --upgrade to upgrade it instead.'
)
Assert-True ((Test-InstallFailureIsAlreadyInstalled -Output $alreadyInstalledOutput) -eq $true) 'The installer should recognize already-installed output from the package manager.'

Write-Host 'Installer tests passed.' -ForegroundColor Green
