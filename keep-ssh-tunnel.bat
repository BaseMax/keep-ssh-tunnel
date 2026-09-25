@echo off
setlocal EnableExtensions

title Persistent SSH SOCKS5 Tunnel

REM ============================================================================
REM Configuration
REM Environment variables override these defaults.
REM ============================================================================

if not defined SSH_HOST set "SSH_HOST=85.208.255.3"
if not defined SSH_USER set "SSH_USER=root"
if not defined SSH_PORT set "SSH_PORT=22"

if not defined SSH_AUTH_MODE set "SSH_AUTH_MODE=auto"

if not defined SSH_KEY set "SSH_KEY=%USERPROFILE%\.ssh\id_ed25519"

if not defined SOCKS_HOST set "SOCKS_HOST=127.0.0.1"
if not defined SOCKS_PORT set "SOCKS_PORT=1080"

if not defined RECONNECT_DELAY set "RECONNECT_DELAY=5"

if not defined SERVER_ALIVE_INTERVAL set "SERVER_ALIVE_INTERVAL=30"
if not defined SERVER_ALIVE_COUNT_MAX set "SERVER_ALIVE_COUNT_MAX=3"
if not defined CONNECT_TIMEOUT set "CONNECT_TIMEOUT=10"

if not defined SSH_STRICT_HOST_KEY_CHECKING set "SSH_STRICT_HOST_KEY_CHECKING=accept-new"
if not defined SSH_KNOWN_HOSTS_FILE set "SSH_KNOWN_HOSTS_FILE=%USERPROFILE%\.ssh\known_hosts"

REM Used only in password mode.
if not defined PLINK_EXE set "PLINK_EXE=plink.exe"

REM ============================================================================
REM Authentication selection
REM ============================================================================
if /I not "%SSH_AUTH_MODE%"=="auto" goto AUTH_SELECTED

if defined SSH_PASSWORD (
    set "SSH_AUTH_MODE=password"
    goto AUTH_SELECTED
)

if exist "%SSH_KEY%" (
    set "SSH_AUTH_MODE=key"
    goto AUTH_SELECTED
)

set "SSH_AUTH_MODE=agent"

:AUTH_SELECTED

REM ============================================================================
REM Validation
REM ============================================================================
if not defined SSH_HOST (
    echo ERROR: SSH_HOST is empty.
    exit /b 1
)

if not defined SSH_USER (
    echo ERROR: SSH_USER is empty.
    exit /b 1
)

if /I "%SSH_AUTH_MODE%"=="password" goto CHECK_PASSWORD_AUTH

where ssh.exe >nul 2>&1

if errorlevel 1 (
    echo ERROR: Windows OpenSSH ssh.exe was not found.
    echo.
    echo Install "OpenSSH Client" from Windows Optional Features
    echo or place ssh.exe in PATH.
    exit /b 1
)

if /I "%SSH_AUTH_MODE%"=="key" (
    if not exist "%SSH_KEY%" (
        echo ERROR: SSH key does not exist:
        echo %SSH_KEY%
        exit /b 1
    )
)

goto START

:CHECK_PASSWORD_AUTH

if not defined SSH_PASSWORD (
    echo ERROR: SSH_AUTH_MODE=password but SSH_PASSWORD is empty.
    exit /b 1
)

"%PLINK_EXE%" -V >nul 2>&1

if errorlevel 1 (
    echo ERROR: Password mode requires PuTTY plink.exe.
    echo.
    echo Set:
    echo   set "PLINK_EXE=C:\Path\To\plink.exe"
    echo.
    echo Key authentication with Windows OpenSSH is recommended.
    exit /b 1
)

REM For unattended password auth, pin the server host key.
if not defined SSH_HOST_KEY (
    echo ERROR: SSH_HOST_KEY is required for unattended Plink password mode.
    echo.
    echo Set it to the SSH server fingerprint accepted by PuTTY, for example:
    echo   set "SSH_HOST_KEY=ssh-ed25519 255 SHA256:YOUR_FINGERPRINT"
    exit /b 1
)

goto START

REM ============================================================================
REM Start
REM ============================================================================
:START

echo.
echo ===============================================================
echo Persistent SSH SOCKS5 Tunnel
echo ===============================================================
echo SSH server : %SSH_USER%@%SSH_HOST%:%SSH_PORT%
echo SOCKS proxy: %SOCKS_HOST%:%SOCKS_PORT%
echo Auth mode  : %SSH_AUTH_MODE%
echo ===============================================================
echo.

:RECONNECT

echo [%date% %time%] Connecting SSH tunnel...

if /I "%SSH_AUTH_MODE%"=="key" goto CONNECT_KEY
if /I "%SSH_AUTH_MODE%"=="agent" goto CONNECT_AGENT
if /I "%SSH_AUTH_MODE%"=="password" goto CONNECT_PASSWORD

echo ERROR: Unknown SSH_AUTH_MODE "%SSH_AUTH_MODE%"
exit /b 1

REM ============================================================================
REM Key authentication
REM ============================================================================
:CONNECT_KEY

ssh.exe ^
    -N ^
    -T ^
    -D "%SOCKS_HOST%:%SOCKS_PORT%" ^
    -p "%SSH_PORT%" ^
    -i "%SSH_KEY%" ^
    -o BatchMode=yes ^
    -o IdentitiesOnly=yes ^
    -o PasswordAuthentication=no ^
    -o ServerAliveInterval=%SERVER_ALIVE_INTERVAL% ^
    -o ServerAliveCountMax=%SERVER_ALIVE_COUNT_MAX% ^
    -o ConnectTimeout=%CONNECT_TIMEOUT% ^
    -o TCPKeepAlive=yes ^
    -o ExitOnForwardFailure=yes ^
    -o StrictHostKeyChecking=%SSH_STRICT_HOST_KEY_CHECKING% ^
    -o UserKnownHostsFile="%SSH_KNOWN_HOSTS_FILE%" ^
    "%SSH_USER%@%SSH_HOST%"

set "SSH_EXIT_CODE=%ERRORLEVEL%"
goto CONNECTION_LOST


REM ============================================================================
REM ssh-agent authentication
REM ============================================================================
:CONNECT_AGENT

ssh.exe ^
    -N ^
    -T ^
    -D "%SOCKS_HOST%:%SOCKS_PORT%" ^
    -p "%SSH_PORT%" ^
    -o BatchMode=yes ^
    -o ServerAliveInterval=%SERVER_ALIVE_INTERVAL% ^
    -o ServerAliveCountMax=%SERVER_ALIVE_COUNT_MAX% ^
    -o ConnectTimeout=%CONNECT_TIMEOUT% ^
    -o TCPKeepAlive=yes ^
    -o ExitOnForwardFailure=yes ^
    -o StrictHostKeyChecking=%SSH_STRICT_HOST_KEY_CHECKING% ^
    -o UserKnownHostsFile="%SSH_KNOWN_HOSTS_FILE%" ^
    "%SSH_USER%@%SSH_HOST%"

set "SSH_EXIT_CODE=%ERRORLEVEL%"
goto CONNECTION_LOST


REM ============================================================================
REM Password authentication using PuTTY Plink
REM ============================================================================
:CONNECT_PASSWORD

"%PLINK_EXE%" ^
    -ssh ^
    -batch ^
    -N ^
    -T ^
    -D "%SOCKS_HOST%:%SOCKS_PORT%" ^
    -P "%SSH_PORT%" ^
    -l "%SSH_USER%" ^
    -pw "%SSH_PASSWORD%" ^
    -hostkey "%SSH_HOST_KEY%" ^
    "%SSH_HOST%"

set "SSH_EXIT_CODE=%ERRORLEVEL%"
goto CONNECTION_LOST


REM ============================================================================
REM Reconnect
REM ============================================================================
:CONNECTION_LOST

echo.
echo [%date% %time%] SSH exited with code %SSH_EXIT_CODE%.
echo [%date% %time%] Reconnecting in %RECONNECT_DELAY% seconds...
echo.

timeout /t %RECONNECT_DELAY% /nobreak >nul

goto RECONNECT
