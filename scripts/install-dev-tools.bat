@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%install-dev-tools.ps1"

:: Check if the script is running as administrator.
>nul 2>&1 net session
if errorlevel 1 (
    echo [ERROR] This installer needs Administrator privileges.
    echo Please right-click this file and choose "Run as administrator".
    echo Then rerun the installer.
    echo.
    pause
    exit /b 1
)

where powershell >nul 2>nul
if errorlevel 1 (
    echo PowerShell was not found. Please install Windows PowerShell or PowerShell 7 and try again.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*

if errorlevel 1 (
    echo.
    echo Installation failed. Review the output above and try again.
    pause
    exit /b %errorlevel%
)

echo.
echo Setup complete.
pause
exit /b 0
