@echo off
setlocal EnableExtensions
rem ============================================================
rem  AstrBot Portable launcher
rem  - Resolves the drive letter dynamically (works on any
rem    removable media / any mount point).
rem  - Redirects all runtime writes into this folder.
rem  - Set ASTRBOT_PORTABLE_USE_SYSTEM_TMP=1 to use the host's
rem    system temp directory instead (faster for plugin installs).
rem ============================================================

rem %~dp0 always ends with a backslash; strip it for clean joins.
set "PORTABLE_ROOT=%~dp0"
if "%PORTABLE_ROOT:~-1%"=="\" set "PORTABLE_ROOT=%PORTABLE_ROOT:~0,-1%"

rem AstrBot resolves every data path from ASTRBOT_ROOT.
set "ASTRBOT_ROOT=%PORTABLE_ROOT%"
set "PATH=%PORTABLE_ROOT%\python;%PORTABLE_ROOT%\python\Scripts;%PATH%"

if not defined ASTRBOT_PORTABLE_USE_SYSTEM_TMP (
    if not exist "%PORTABLE_ROOT%\data\temp\system" mkdir "%PORTABLE_ROOT%\data\temp\system" >nul 2>&1
    set "TMP=%PORTABLE_ROOT%\data\temp\system"
    set "TEMP=%PORTABLE_ROOT%\data\temp\system"
)

if not exist "%PORTABLE_ROOT%\data" mkdir "%PORTABLE_ROOT%\data" >nul 2>&1
cd /d "%PORTABLE_ROOT%"

echo ============================================================
echo   AstrBot Portable
echo   Root : %PORTABLE_ROOT%
echo   WebUI: http://127.0.0.1:6185
echo   All data stays inside this folder.
echo   Stop with Ctrl+C before unplugging the drive.
echo ============================================================

"%PORTABLE_ROOT%\python\python.exe" main.py %*
endlocal & exit /b %ERRORLEVEL%
