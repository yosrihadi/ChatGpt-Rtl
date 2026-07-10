@echo off
REM ============================================================================
REM ChatGpt RTL Patch - One-click installer for Windows
REM
REM ============================================================================
REM Double-click this file to install. No PowerShell or admin needed.
REM Patched Chatgpt copy goes to %LOCALAPPDATA%\Programs\Chatgpt-RT-AI.
REM A "Chatgpt" shortcut is created on Desktop and in Start Menu.
REM The original Codex (under WindowsApps) is NOT modified.
REM ============================================================================

setlocal
cd /d "%~dp0"

echo.
echo ============================================================
echo   ChatGpt RTL Patch - Installer
echo   https://www.facebook.com/yosrihadi
echo ============================================================
echo.

where node.exe >nul 2>&1
if errorlevel 1 (
    echo [!] Node.js is not installed.
    echo     Install it from https://nodejs.org/ and run this again.
    echo.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0patch.ps1" -Install %*
set EXITCODE=%ERRORLEVEL%

echo.
if %EXITCODE% NEQ 0 (
    echo [X] Install failed with exit code %EXITCODE%.
) else (
    echo [+] Done. Click "ChatGpt" on your Desktop or in Start Menu.
)

echo.
pause
exit /b %EXITCODE%
