#!/usr/bin/env bash

# ssh-tunnel.sh
#
# Persistent SSH dynamic SOCKS5 tunnel.
#
# Authentication modes:
#   auto      SSH_PASSWORD -> password
#             SSH_KEY exists -> key
#             otherwise -> SSH agent
#
#   key       private key authentication
#   agent     ssh-agent authentication
#   password  sshpass authentication
#
# Example:
#   export SSH_HOST="85.208.255.3"
#   export SSH_USER="root"
#   ./ssh-tunnel.sh

set -u

###############################################################################
# Configuration
###############################################################################
SSH_HOST="${SSH_HOST:-85.208.255.3}"
SSH_USER="${SSH_USER:-root}"
SSH_PORT="${SSH_PORT:-22}"

SSH_AUTH_MODE="${SSH_AUTH_MODE:-auto}"

SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
SSH_PASSWORD="${SSH_PASSWORD:-}"

SOCKS_HOST="${SOCKS_HOST:-127.0.0.1}"
SOCKS_PORT="${SOCKS_PORT:-1080}"

RECONNECT_DELAY="${RECONNECT_DELAY:-5}"
MAX_RECONNECT_DELAY="${MAX_RECONNECT_DELAY:-60}"

SERVER_ALIVE_INTERVAL="${SERVER_ALIVE_INTERVAL:-30}"
SERVER_ALIVE_COUNT_MAX="${SERVER_ALIVE_COUNT_MAX:-3}"
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-10}"

# Reset exponential backoff after the tunnel remained alive this many seconds.
STABLE_RESET_AFTER="${STABLE_RESET_AFTER:-120}"

# Recommended:
#   yes        = server must already be in known_hosts
#   accept-new = automatically accepts new servers but rejects changed keys
#
# Avoid "no" except for temporary testing.
SSH_STRICT_HOST_KEY_CHECKING="${SSH_STRICT_HOST_KEY_CHECKING:-accept-new}"

SSH_KNOWN_HOSTS_FILE="${SSH_KNOWN_HOSTS_FILE:-$HOME/.ssh/known_hosts}"

###############################################################################
# Helpers
###############################################################################
log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

die() {
    log "ERROR: $*"
    exit 1
}

is_port() {
    case "$1" in
        ''|*[!0-9]*)
            return 1
            ;;
    esac

    [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

###############################################################################
# Validation
###############################################################################
command -v ssh >/dev/null 2>&1 ||
    die "OpenSSH 'ssh' was not found."

[ -n "$SSH_HOST" ] ||
    die "SSH_HOST is empty."

[ -n "$SSH_USER" ] ||
    die "SSH_USER is empty."

is_port "$SSH_PORT" ||
    die "Invalid SSH_PORT: $SSH_PORT"

is_port "$SOCKS_PORT" ||
    die "Invalid SOCKS_PORT: $SOCKS_PORT"

case "$RECONNECT_DELAY" in
    ''|*[!0-9]*)
        die "RECONNECT_DELAY must be an integer."
        ;;
esac

case "$MAX_RECONNECT_DELAY" in
    ''|*[!0-9]*)
        die "MAX_RECONNECT_DELAY must be an integer."
        ;;
esac

mkdir -p "$(dirname "$SSH_KNOWN_HOSTS_FILE")" 2>/dev/null || true

###############################################################################
# Select authentication
###############################################################################
AUTH_MODE="$SSH_AUTH_MODE"

if [ "$AUTH_MODE" = "auto" ]; then
    if [ -n "$SSH_PASSWORD" ]; then
        AUTH_MODE="password"
    elif [ -r "$SSH_KEY" ]; then
        AUTH_MODE="key"
    else
        AUTH_MODE="agent"
    fi
fi

case "$AUTH_MODE" in

    key)
        [ -r "$SSH_KEY" ] ||
            die "SSH key does not exist or cannot be read: $SSH_KEY"
        ;;

    agent)
        ;;

    password)
        [ -n "$SSH_PASSWORD" ] ||
            die "SSH_AUTH_MODE=password but SSH_PASSWORD is empty."

        command -v sshpass >/dev/null 2>&1 ||
            die "Password mode requires 'sshpass'. Key authentication is recommended."
        ;;

    *)
        die "Invalid SSH_AUTH_MODE: $AUTH_MODE"
        ;;
esac

###############################################################################
# SSH
###############################################################################
run_tunnel() {

    local common_options=(
        -N
        -T

        -D "${SOCKS_HOST}:${SOCKS_PORT}"

        -p "$SSH_PORT"

        -o "ServerAliveInterval=${SERVER_ALIVE_INTERVAL}"
        -o "ServerAliveCountMax=${SERVER_ALIVE_COUNT_MAX}"
        -o "ConnectTimeout=${CONNECT_TIMEOUT}"

        -o "TCPKeepAlive=yes"
        -o "ExitOnForwardFailure=yes"

        -o "StrictHostKeyChecking=${SSH_STRICT_HOST_KEY_CHECKING}"
        -o "UserKnownHostsFile=${SSH_KNOWN_HOSTS_FILE}"
    )

    case "$AUTH_MODE" in

        key)
            ssh \
                "${common_options[@]}" \
                -o BatchMode=yes \
                -o IdentitiesOnly=yes \
                -o PasswordAuthentication=no \
                -i "$SSH_KEY" \
                "${SSH_USER}@${SSH_HOST}"
            ;;

        agent)
            ssh \
                "${common_options[@]}" \
                -o BatchMode=yes \
                "${SSH_USER}@${SSH_HOST}"
            ;;

        password)
            SSHPASS="$SSH_PASSWORD" \
            sshpass -e ssh \
                "${common_options[@]}" \
                -o PubkeyAuthentication=no \
                -o "PreferredAuthentications=keyboard-interactive,password" \
                -o NumberOfPasswordPrompts=1 \
                "${SSH_USER}@${SSH_HOST}"
            ;;

    esac
}

###############################################################################
# Shutdown handling
###############################################################################
STOP_REQUESTED=0

shutdown() {
    STOP_REQUESTED=1
    log "Shutdown requested."
}

trap shutdown INT TERM HUP

###############################################################################
# Reconnect loop
###############################################################################
delay="$RECONNECT_DELAY"

log "SSH server: ${SSH_USER}@${SSH_HOST}:${SSH_PORT}"
log "SOCKS5 proxy: ${SOCKS_HOST}:${SOCKS_PORT}"
log "Authentication: ${AUTH_MODE}"
log "Starting persistent tunnel."

while [ "$STOP_REQUESTED" -eq 0 ]; do

    log "Connecting..."

    start_time="$(date +%s)"

    run_tunnel
    rc=$?

    end_time="$(date +%s)"
    duration=$((end_time - start_time))

    if [ "$STOP_REQUESTED" -ne 0 ]; then
        break
    fi

    log "SSH tunnel exited with code ${rc} after ${duration}s."

    # If connection was stable for a while, return to initial delay.
    if [ "$duration" -ge "$STABLE_RESET_AFTER" ]; then
        delay="$RECONNECT_DELAY"
    fi

    log "Reconnecting in ${delay}s..."
    sleep "$delay" || break

    # Exponential backoff for repeated quick failures.
    if [ "$duration" -lt "$STABLE_RESET_AFTER" ]; then
        next_delay=$((delay * 2))

        if [ "$next_delay" -gt "$MAX_RECONNECT_DELAY" ]; then
            next_delay="$MAX_RECONNECT_DELAY"
        fi

        delay="$next_delay"
    fi

done

log "SSH tunnel stopped."
exit 0
