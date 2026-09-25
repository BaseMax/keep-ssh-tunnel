# keep-ssh-tunnel

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnu-bash\&logoColor=white)](keep-ssh-tunnel.sh)
[![Windows](https://img.shields.io/badge/Windows-Batch-0078D6?logo=windows\&logoColor=white)](keep-ssh-tunnel.bat)
[![GitHub](https://img.shields.io/badge/GitHub-BaseMax%2Fkeep--ssh--tunnel-181717?logo=github)](https://github.com/BaseMax/keep-ssh-tunnel)

A small, dependency-light utility for maintaining a **persistent SSH dynamic SOCKS5 tunnel** on Linux, macOS, and Windows.

`keep-ssh-tunnel` automatically reconnects when the SSH connection drops and supports authentication using:

* SSH private keys
* `ssh-agent`
* Password authentication
* Automatic authentication-mode selection

The resulting local SOCKS5 proxy can be used by browsers, command-line tools, development environments, and other applications that support SOCKS proxies.

---

## Features

* Persistent SSH SOCKS5 tunnel
* Automatic reconnection
* Linux support
* macOS support
* Windows support
* SSH private-key authentication
* SSH-agent authentication
* Optional password authentication
* Configurable SSH hostname/IP
* Configurable SSH username
* Configurable SSH port
* Configurable SOCKS bind address and port
* SSH keepalive support
* Connection timeout handling
* Forwarding failure detection
* SSH host-key verification
* Configurable `known_hosts` file
* Environment-variable based configuration
* No hardcoded credentials required
* Bash exponential reconnect backoff
* Graceful shutdown handling on Linux/macOS
* Windows OpenSSH support
* PuTTY/Plink password-authentication support on Windows

---

## How It Works

The scripts use SSH dynamic port forwarding:

```text
-D 127.0.0.1:1080
```

This creates a local SOCKS proxy:

```text
Application
    |
    v
127.0.0.1:1080
    |
    | SOCKS5
    v
SSH Client
    |
    | Encrypted SSH connection
    v
SSH Server
    |
    v
Internet / Remote Network
```

If the SSH connection is interrupted, the script detects the termination and starts another connection automatically.

---

## Repository Files

```text
keep-ssh-tunnel/
├── keep-ssh-tunnel.sh
├── keep-ssh-tunnel.bat
├── README.md
└── LICENSE
```

### `keep-ssh-tunnel.sh`

For:

* Linux
* macOS
* other Unix-like systems with Bash and OpenSSH

### `keep-ssh-tunnel.bat`

For:

* Windows 10
* Windows 11
* Windows Server
* other Windows environments with OpenSSH Client

Password mode on Windows uses PuTTY's `plink.exe`.

---

# Quick Start

## Linux / macOS

Clone the repository:

```bash
git clone https://github.com/BaseMax/keep-ssh-tunnel.git
cd keep-ssh-tunnel
```

Make the script executable:

```bash
chmod +x keep-ssh-tunnel.sh
```

Configure your SSH server:

```bash
export SSH_HOST="your-server.example.com"
export SSH_USER="your-user"
export SSH_PORT="22"
export SSH_AUTH_MODE="key"
export SSH_KEY="$HOME/.ssh/id_ed25519"
```

Run:

```bash
./keep-ssh-tunnel.sh
```

Your SOCKS5 proxy will be available by default at:

```text
127.0.0.1:1080
```

---

## Windows

Clone the repository:

```bat
git clone https://github.com/BaseMax/keep-ssh-tunnel.git
cd keep-ssh-tunnel
```

Configure the connection:

```bat
set "SSH_HOST=your-server.example.com"
set "SSH_USER=your-user"
set "SSH_PORT=22"
set "SSH_AUTH_MODE=key"
set "SSH_KEY=%USERPROFILE%\.ssh\id_ed25519"
```

Run:

```bat
keep-ssh-tunnel.bat
```

The SOCKS5 proxy will be available by default at:

```text
127.0.0.1:1080
```

---

# Configuration

Configuration is performed with environment variables.

## Common Variables

| Variable                       | Default                       | Description                                          |
| ------------------------------ | ----------------------------- | ---------------------------------------------------- |
| `SSH_HOST`                     | Script default                | SSH server hostname or IP address                    |
| `SSH_USER`                     | Script default                | SSH username                                         |
| `SSH_PORT`                     | `22`                          | SSH server port                                      |
| `SSH_AUTH_MODE`                | `auto`                        | Authentication mode                                  |
| `SSH_KEY`                      | `~/.ssh/id_ed25519`           | SSH private-key path                                 |
| `SSH_PASSWORD`                 | empty                         | SSH password when password authentication is enabled |
| `SOCKS_HOST`                   | `127.0.0.1`                   | Local SOCKS proxy bind address                       |
| `SOCKS_PORT`                   | `1080`                        | Local SOCKS proxy port                               |
| `RECONNECT_DELAY`              | `5`                           | Initial reconnect delay in seconds                   |
| `SERVER_ALIVE_INTERVAL`        | `30`                          | SSH keepalive interval                               |
| `SERVER_ALIVE_COUNT_MAX`       | `3`                           | Maximum unanswered SSH keepalives                    |
| `CONNECT_TIMEOUT`              | `10`                          | SSH connection timeout                               |
| `SSH_STRICT_HOST_KEY_CHECKING` | `accept-new`                  | SSH host-key verification behavior                   |
| `SSH_KNOWN_HOSTS_FILE`         | platform SSH default location | Custom `known_hosts` file                            |

The Unix implementation additionally supports:

| Variable              | Default | Description                                                       |
| --------------------- | ------- | ----------------------------------------------------------------- |
| `MAX_RECONNECT_DELAY` | `60`    | Maximum reconnect delay                                           |
| `STABLE_RESET_AFTER`  | `120`   | Seconds a connection must survive before reconnect backoff resets |

The Windows password implementation additionally supports:

| Variable       | Default     | Description                              |
| -------------- | ----------- | ---------------------------------------- |
| `PLINK_EXE`    | `plink.exe` | Path to PuTTY Plink                      |
| `SSH_HOST_KEY` | none        | Expected SSH server host-key fingerprint |

---

# Authentication Modes

`SSH_AUTH_MODE` supports:

```text
auto
key
agent
password
```

## `auto`

The scripts automatically select an authentication mechanism.

On Linux/macOS, the selection is effectively:

```text
SSH_PASSWORD configured
        |
       yes
        v
    password

otherwise, readable SSH_KEY exists
        |
       yes
        v
       key

otherwise
        |
        v
      agent
```

Windows follows the same general selection logic.

For production and unattended use, explicitly setting the desired mode is recommended.

---

# Private-Key Authentication

Private-key authentication is the recommended configuration for unattended SSH tunnels.

## Linux / macOS

```bash
export SSH_HOST="server.example.com"
export SSH_USER="tunnel"
export SSH_PORT="22"

export SSH_AUTH_MODE="key"
export SSH_KEY="$HOME/.ssh/id_ed25519"

export SOCKS_HOST="127.0.0.1"
export SOCKS_PORT="1080"

./keep-ssh-tunnel.sh
```

## Windows

```bat
set "SSH_HOST=server.example.com"
set "SSH_USER=tunnel"
set "SSH_PORT=22"

set "SSH_AUTH_MODE=key"
set "SSH_KEY=%USERPROFILE%\.ssh\id_ed25519"

set "SOCKS_HOST=127.0.0.1"
set "SOCKS_PORT=1080"

keep-ssh-tunnel.bat
```

---

# Generating an SSH Key

If you do not already have a key:

```bash
ssh-keygen -t ed25519
```

Windows OpenSSH supports the same command:

```powershell
ssh-keygen -t ed25519
```

The default key paths are typically:

### Linux / macOS

```text
~/.ssh/id_ed25519
~/.ssh/id_ed25519.pub
```

### Windows

```text
%USERPROFILE%\.ssh\id_ed25519
%USERPROFILE%\.ssh\id_ed25519.pub
```

Install the public key on your SSH server before running the tunnel.

On Linux/macOS, when `ssh-copy-id` is available:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@server.example.com
```

Alternatively, add the public key manually to:

```text
~/.ssh/authorized_keys
```

on the remote server.

---

# SSH Agent Authentication

Using an SSH agent is useful when the private key has a passphrase and you do not want the tunnel process to handle it directly.

## Linux / macOS

Start an agent if necessary:

```bash
eval "$(ssh-agent -s)"
```

Add the key:

```bash
ssh-add "$HOME/.ssh/id_ed25519"
```

Configure the tunnel:

```bash
export SSH_HOST="server.example.com"
export SSH_USER="tunnel"
export SSH_PORT="22"
export SSH_AUTH_MODE="agent"

./keep-ssh-tunnel.sh
```

---

## Windows SSH Agent

Open PowerShell as Administrator:

```powershell
Set-Service ssh-agent -StartupType Automatic
Start-Service ssh-agent
```

Add the private key:

```powershell
ssh-add "$env:USERPROFILE\.ssh\id_ed25519"
```

Then run:

```bat
set "SSH_HOST=server.example.com"
set "SSH_USER=tunnel"
set "SSH_PORT=22"
set "SSH_AUTH_MODE=agent"

keep-ssh-tunnel.bat
```

---

# Password Authentication

Password authentication is supported, but SSH keys or an SSH agent are preferable for unattended tunnels.

Passwords stored in environment variables may be visible to processes, debugging tools, shell history, logs, or other software depending on the operating system and configuration.

Do not commit passwords to this repository.

---

## Linux / macOS Password Authentication

The Unix script uses `sshpass`.

Install it using your operating system's package manager.

Then configure:

```bash
export SSH_HOST="server.example.com"
export SSH_USER="tunnel"
export SSH_PORT="22"

export SSH_AUTH_MODE="password"
export SSH_PASSWORD="your-password"

./keep-ssh-tunnel.sh
```

The password is passed to `sshpass` through the `SSHPASS` environment variable.

---

## Windows Password Authentication

Windows password mode uses PuTTY's `plink.exe`.

Configure:

```bat
set "SSH_HOST=server.example.com"
set "SSH_USER=tunnel"
set "SSH_PORT=22"

set "SSH_AUTH_MODE=password"
set "SSH_PASSWORD=your-password"

set "PLINK_EXE=C:\Program Files\PuTTY\plink.exe"

set "SSH_HOST_KEY=ssh-ed25519 255 SHA256:YOUR_SERVER_FINGERPRINT"

keep-ssh-tunnel.bat
```

`SSH_HOST_KEY` is required in unattended password mode so Plink can verify that it is connecting to the intended SSH server.

Do not blindly copy an unknown fingerprint. Verify the server's SSH host key through a trusted channel first.

---

# SOCKS5 Configuration

By default:

```text
SOCKS_HOST=127.0.0.1
SOCKS_PORT=1080
```

This creates:

```text
socks5://127.0.0.1:1080
```

You can change the port:

### Linux / macOS

```bash
export SOCKS_PORT="8080"
./keep-ssh-tunnel.sh
```

### Windows

```bat
set "SOCKS_PORT=8080"
keep-ssh-tunnel.bat
```

---

# Testing the Tunnel

A simple test is to send an HTTP request through the SOCKS proxy.

Using `curl`:

```bash
curl --socks5-hostname 127.0.0.1:1080 https://ifconfig.me
```

Windows:

```bat
curl.exe --socks5-hostname 127.0.0.1:1080 https://ifconfig.me
```

Using:

```text
--socks5-hostname
```

instead of:

```text
--socks5
```

also routes hostname resolution through the SOCKS proxy.

This can help avoid local DNS resolution outside the tunnel.

---

# Browser Configuration

Applications supporting SOCKS5 can normally use:

```text
Proxy Type: SOCKS5
Host:       127.0.0.1
Port:       1080
```

Where supported, enable remote DNS resolution through the SOCKS proxy.

---

# Reconnection

The primary purpose of this project is to keep the SSH tunnel available despite temporary connection failures.

## Linux / macOS

The Bash implementation includes reconnect backoff.

The first retry uses:

```text
RECONNECT_DELAY
```

Repeated short-lived failures increase the delay up to:

```text
MAX_RECONNECT_DELAY
```

For example:

```text
5s
10s
20s
40s
60s
60s
...
```

If the tunnel remains alive for at least:

```text
STABLE_RESET_AFTER
```

seconds, the reconnect delay resets to the initial value.

With the defaults:

```text
RECONNECT_DELAY=5
MAX_RECONNECT_DELAY=60
STABLE_RESET_AFTER=120
```

---

## Windows

The Windows batch implementation reconnects after:

```text
RECONNECT_DELAY
```

seconds whenever the SSH process exits.

Default:

```text
5 seconds
```

---

# SSH Keepalive

The scripts configure SSH keepalive messages.

Defaults:

```text
ServerAliveInterval=30
ServerAliveCountMax=3
```

This means the SSH client periodically checks whether the server is still reachable and eventually terminates a dead connection so the reconnect loop can establish a new one.

The scripts also enable:

```text
TCPKeepAlive=yes
ExitOnForwardFailure=yes
```

`ExitOnForwardFailure=yes` prevents the script from treating SSH as successfully connected when the local SOCKS forwarding socket could not be created.

---

# Host-Key Verification

The default configuration uses:

```text
StrictHostKeyChecking=accept-new
```

This automatically accepts a host key for a server that has never been seen before, while rejecting a server whose previously stored host key unexpectedly changes.

For stricter environments, use:

```bash
export SSH_STRICT_HOST_KEY_CHECKING="yes"
```

or Windows:

```bat
set "SSH_STRICT_HOST_KEY_CHECKING=yes"
```

The server must then already exist in your `known_hosts` file.

Never disable host-key verification permanently simply to suppress an SSH warning.

A changed host key can be legitimate after a server rebuild, but it can also indicate that you are connecting to a different server or that the connection is being intercepted.

---

# Security Recommendations

For unattended production usage:

1. Prefer SSH keys instead of passwords.
2. Use a dedicated SSH account for tunneling.
3. Avoid using `root` unless it is genuinely necessary.
4. Protect private-key file permissions.
5. Keep the SOCKS proxy bound to `127.0.0.1`.
6. Verify SSH host keys.
7. Never commit passwords or private keys.
8. Restrict the remote SSH account to only the permissions it needs.
9. Disable SSH password authentication on the server when possible.
10. Regularly update your SSH client and server software.

A dedicated account such as:

```text
tunnel
```

is generally preferable to an unrestricted administrative account.

---

# Important SOCKS Bind Warning

The default:

```text
127.0.0.1:1080
```

only accepts connections originating from the local computer.

This is intentional.

Changing:

```text
SOCKS_HOST=127.0.0.1
```

to:

```text
SOCKS_HOST=0.0.0.0
```

can expose the SOCKS proxy to other computers that can reach your machine.

Do this only when you understand the security implications and have appropriate firewall/access controls.

---

# Environment Configuration Examples

## Linux / macOS

Create your own startup/configuration file if desired:

```bash
#!/usr/bin/env bash

export SSH_HOST="server.example.com"
export SSH_USER="tunnel"
export SSH_PORT="22"

export SSH_AUTH_MODE="key"
export SSH_KEY="$HOME/.ssh/id_ed25519"

export SOCKS_HOST="127.0.0.1"
export SOCKS_PORT="1080"

export RECONNECT_DELAY="5"
export MAX_RECONNECT_DELAY="60"

exec ./keep-ssh-tunnel.sh
```

Protect it appropriately:

```bash
chmod 700 start-tunnel.sh
```

Run:

```bash
./start-tunnel.sh
```

---

## Windows

Create a separate `start-tunnel.bat`:

```bat
@echo off

set "SSH_HOST=server.example.com"
set "SSH_USER=tunnel"
set "SSH_PORT=22"

set "SSH_AUTH_MODE=key"
set "SSH_KEY=%USERPROFILE%\.ssh\id_ed25519"

set "SOCKS_HOST=127.0.0.1"
set "SOCKS_PORT=1080"

set "RECONNECT_DELAY=5"

call keep-ssh-tunnel.bat
```

Then run:

```bat
start-tunnel.bat
```

Do not store `SSH_PASSWORD` in a committed configuration file.

---

# Running in the Background

## Linux

You can use your preferred service manager, such as `systemd`, to run the tunnel automatically after boot.

A minimal example:

```ini
[Unit]
Description=Persistent SSH SOCKS5 Tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=YOUR_LOCAL_USER
Environment=SSH_HOST=server.example.com
Environment=SSH_USER=tunnel
Environment=SSH_PORT=22
Environment=SSH_AUTH_MODE=key
Environment=SOCKS_HOST=127.0.0.1
Environment=SOCKS_PORT=1080
ExecStart=/path/to/keep-ssh-tunnel/keep-ssh-tunnel.sh
Restart=no

[Install]
WantedBy=multi-user.target
```

The script already performs its own reconnect loop, so an additional aggressive service-manager restart loop is normally unnecessary.

Adjust paths and users for your environment.

---

# macOS

The script can be managed with `launchd` if you want it to start automatically after login or boot.

Make sure the process has access to the required private key or SSH agent.

For simple interactive usage:

```bash
./keep-ssh-tunnel.sh
```

is sufficient.

---

# Windows Startup

On Windows, the script can be started manually:

```bat
keep-ssh-tunnel.bat
```

or configured through Windows Task Scheduler if automatic startup is required.

When using Task Scheduler, ensure that:

* `ssh.exe` is available
* the SSH key path is correct
* the task account can read the SSH key
* environment variables are configured for the task
* the local SOCKS port is not already in use

---

# Stopping the Tunnel

## Linux / macOS

Press:

```text
Ctrl+C
```

The Bash script handles termination signals and exits its reconnect loop.

## Windows

Press:

```text
Ctrl+C
```

and terminate the batch process when prompted if necessary.

---

# Troubleshooting

## `ssh: command not found`

Install OpenSSH Client.

Verify:

```bash
ssh -V
```

Windows:

```bat
ssh.exe -V
```

---

## `Permission denied (publickey)`

Check:

* SSH username
* private-key path
* public key installation on the server
* `authorized_keys` permissions
* SSH server configuration

Test SSH directly:

```bash
ssh -i ~/.ssh/id_ed25519 user@server.example.com
```

---

## `Address already in use`

Another application is already listening on your configured SOCKS port.

Check port `1080`, terminate the existing process, or choose another port:

```bash
export SOCKS_PORT="1081"
```

Windows:

```bat
set "SOCKS_PORT=1081"
```

---

## Host key verification failed

The SSH host key stored locally does not match the server.

Do not immediately disable host-key checking.

Verify whether:

* the server was rebuilt
* its SSH keys were intentionally regenerated
* DNS/IP information changed
* you are actually connecting to the intended host

Only replace the stored key after verifying the new fingerprint.

---

## Password mode fails on Linux/macOS

Make sure `sshpass` is installed:

```bash
sshpass -V
```

Key authentication is recommended instead.

---

## Password mode fails on Windows

Make sure PuTTY/Plink is installed and available:

```bat
plink.exe -V
```

Or configure its absolute path:

```bat
set "PLINK_EXE=C:\Program Files\PuTTY\plink.exe"
```

You must also configure the trusted SSH host fingerprint:

```bat
set "SSH_HOST_KEY=ssh-ed25519 255 SHA256:YOUR_SERVER_FINGERPRINT"
```

---

# Example Output

A normal Linux/macOS session looks similar to:

```text
[2026-01-01 12:00:00] SSH server: tunnel@server.example.com:22
[2026-01-01 12:00:00] SOCKS5 proxy: 127.0.0.1:1080
[2026-01-01 12:00:00] Authentication: key
[2026-01-01 12:00:00] Starting persistent tunnel.
[2026-01-01 12:00:00] Connecting...
```

If the connection is lost:

```text
[2026-01-01 12:10:42] SSH tunnel exited with code 255 after 642s.
[2026-01-01 12:10:42] Reconnecting in 5s...
[2026-01-01 12:10:47] Connecting...
```

---

# Requirements

## Linux / macOS

Required:

* Bash
* OpenSSH Client

For password mode:

* `sshpass`

## Windows

For key/agent modes:

* Windows OpenSSH Client

For password mode:

* PuTTY `plink.exe`

---

# Contributing

Contributions are welcome.

If you find a bug or have an improvement:

1. Fork the repository.
2. Create a feature branch.
3. Make your changes.
4. Test on the relevant operating system.
5. Commit the changes.
6. Push your branch.
7. Open a pull request.

Repository:

https://github.com/BaseMax/keep-ssh-tunnel

Issues:

https://github.com/BaseMax/keep-ssh-tunnel/issues

Pull requests:

https://github.com/BaseMax/keep-ssh-tunnel/pulls

---

## Copyright

**Copyright © 2026 Seyyed Ali Mohammadiyeh.**

Licensed under the GNU General Public License v3.0.
