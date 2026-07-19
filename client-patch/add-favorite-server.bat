@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: ============================================================
:: CS 1.6 favorites patch (overwrite, non-Steam only)
:: 1) Put this folder into CS root (where cstrike.exe is)
:: 2) Run this bat inside client-patch
:: ============================================================

:: ---- Server address (env vars override these defaults) ----
if not defined CS16_SERVER_HOST  set "CS16_SERVER_HOST=CHANGE_ME_PUBLIC_IP_OR_HOST"
if not defined CS16_SERVER_PORT  set "CS16_SERVER_PORT=27015"
if not defined CS16_SERVER_NAME  set "CS16_SERVER_NAME=XuanHe CS1.6 Server"

set "CS16_SERVER_ADDRESS=%CS16_SERVER_HOST%:%CS16_SERVER_PORT%"

:: Parent of client-patch = CS root (or launcher folder)
set "CS_ROOT=%~dp0.."
for %%I in ("%CS_ROOT%") do set "CS_ROOT=%%~fI"

:: If platform is missing, search one level of subfolders
if not exist "%CS_ROOT%\platform\config" (
  for /d %%D in ("%CS_ROOT%\*") do (
    if exist "%%~fD\platform\config" (
      set "CS_ROOT=%%~fD"
      goto :RootReady
    )
    if exist "%%~fD\hl.exe" if exist "%%~fD\cstrike" (
      set "CS_ROOT=%%~fD"
      goto :RootReady
    )
  )
)
:RootReady

echo.
echo ========================================
echo   CS 1.6 Favorites Patch (OVERWRITE)
echo ========================================
echo   Name : %CS16_SERVER_NAME%
echo   Addr : %CS16_SERVER_ADDRESS%
echo   Root : %CS_ROOT%
echo ========================================
echo.

if "%CS16_SERVER_HOST%"=="CHANGE_ME_PUBLIC_IP_OR_HOST" (
  echo [ERROR] Edit CS16_SERVER_HOST in this bat first.
  echo         Use your public IP, not 127.0.0.1 for friends.
  echo.
  pause
  exit /b 1
)

if "%CS16_SERVER_HOST%"=="127.0.0.1" (
  echo [WARN] Host is 127.0.0.1 - only this PC can connect.
  echo.
)

if not exist "%CS_ROOT%\cstrike.exe" if not exist "%CS_ROOT%\hl.exe" (
  echo [ERROR] cstrike.exe / hl.exe not found.
  echo         Put client-patch into CS root, then run again.
  echo         Detected: %CS_ROOT%
  echo.
  pause
  exit /b 1
)

echo [NOTE] Quit CS 1.6 completely, then press any key.
echo [NOTE] Favorites will be OVERWRITTEN. Backups: *.vdf.bak
echo.
pause

set "PATCHED=0"
set "FAILED=0"

if not exist "%CS_ROOT%\platform\config" mkdir "%CS_ROOT%\platform\config" >nul 2>&1
if not exist "%CS_ROOT%\config" mkdir "%CS_ROOT%\config" >nul 2>&1

call :PatchVdf "%CS_ROOT%\platform\config\ServerBrowser.vdf"
call :PatchVdf "%CS_ROOT%\config\ServerBrowser.vdf"
call :PatchVdf "%CS_ROOT%\config\rev_ServerBrowser.vdf"

echo.
echo ----------------------------------------
echo Done: wrote %PATCHED% file(s), failed %FAILED%.
echo.
echo Next:
echo   1. Open CS 1.6
echo   2. Find Servers -^> Favorites
echo.
echo If still empty, check file:
echo   notepad "%CS_ROOT%\platform\config\ServerBrowser.vdf"
echo It must contain your IP:port
echo ----------------------------------------
echo.
pause
exit /b 0

:PatchVdf
set "VDF=%~1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_patch-vdf.ps1" -VdfPath "%VDF%" -ServerName "%CS16_SERVER_NAME%" -ServerAddress "%CS16_SERVER_ADDRESS%"
if errorlevel 1 (
  set /a FAILED+=1
  echo [FAIL] %VDF%
) else (
  set /a PATCHED+=1
  echo [OK]   %VDF%
)
goto :eof
