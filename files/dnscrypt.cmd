@echo off
title DNSCrypt Control
setlocal EnableDelayedExpansion
set "dnsCryptDir=%windir%\DNSCrypt"
NET SESSION >nul 2>&1
if %errorLevel% neq 0 (
echo * Administrator rights required!
goto exit
)
:menu
cls
echo.
echo  DDDD   N   N   SSS   CCC  RRRR   Y   Y  PPPP  TTTTT
echo  D   D  NN  N  S     C     R   R   Y Y   P   P   T
echo  D   D  N N N   SSS  C     RRRR     Y    PPPP    T
echo  D   D  N  NN      S C     R R      Y    P       T
echo  DDDD   N   N  SSSS   CCC  R  R     Y    P       T
echo      sevcator.github.io - github.com/DNSCrypt
echo.
echo 1. Start service
echo 2. Stop service
echo 3. Restart service
echo 4. Uninstall
echo 5. Exit
echo.
set /p choice="- Choice: "
if "%choice%"=="1" goto startService
if "%choice%"=="2" goto stopService
if "%choice%"=="3" goto restartService
if "%choice%"=="4" goto uninstall
if "%choice%"=="5" goto exit
goto menu

:startService
cls
echo.
"%dnsCryptDir%\dnscrypt-proxy.exe" -service start >nul 2>&1
net start dnscrypt-proxy >nul 2>&1
echo - Service has been started!
timeout /t 2 /nobreak >nul 2>&1
goto menu

:stopService
cls
echo.
"%dnsCryptDir%\dnscrypt-proxy.exe" -service stop >nul 2>&1
net stop dnscrypt-proxy >nul 2>&1
sc stop dnscrypt-proxy >nul 2>&1
echo - Service has been stopped!
timeout /t 2 /nobreak >nul 2>&1
goto menu

:restartService
cls
echo.
"%dnsCryptDir%\dnscrypt-proxy.exe" -service stop >nul 2>&1
net stop dnscrypt-proxy >nul 2>&1
sc stop dnscrypt-proxy >nul 2>&1
timeout /t 1 /nobreak >nul 2>&1
"%dnsCryptDir%\dnscrypt-proxy.exe" -service start >nul 2>&1
net start dnscrypt-proxy >nul 2>&1
echo - Service has been restarted!
timeout /t 2 /nobreak >nul 2>&1
goto menu

:uninstall
cls
echo.
set /p confirm="- [Y/N] Are you want to uninstall? "
if /i not "%confirm%"=="Y" goto menu
powershell -NoProfile -ExecutionPolicy Bypass -File "%dnsCryptDir%\uninstall.ps1"
dnsCryptDir%\dnscrypt-proxy.exe" -service stop >nul 2>&1
dnsCryptDir%\dnscrypt-proxy.exe" -service uninstall >nul 2>&1
timeout /t 3 /nobreak >nul 2>&1
net stop dnscrypt-proxy >nul 2>&1
sc stop dnscrypt-proxy >nul 2>&1
sc delete dnscrypt-proxy >nul 2>&1
msg * DNSCrypt has been uninstalled
rmdir /s /q "%dnsCryptDir%" >nul 2>&1
goto exit

:exit
