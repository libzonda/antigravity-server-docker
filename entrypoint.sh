#!/usr/bin/env bash
set -e

# Antigravity Server Docker Entrypoint
# Handles permissions (PUID/PGID), directory initialization,
# language_server presence checks, and server startup.

PUID=${PUID:-0}
PGID=${PGID:-0}

export AGY_HOME="${AGY_HOME:-/data}"
export AGY_PORT="${AGY_PORT:-8765}"
export AGY_BIND="${AGY_BIND:-0.0.0.0}"
export AGY_WORKSPACE_ROOT="${AGY_WORKSPACE_ROOT:-/workspace}"
export AGY_LANGUAGE_SERVER="${AGY_LANGUAGE_SERVER:-/opt/agy-server/language_server}"

# Determine HOME
export HOME="${HOME:-/data}"

echo "=========================================================="
echo " Starting Antigravity Server (Docker Container)"
echo " Version: $(agy-server version 2>/dev/null || echo 'unknown')"
echo " Port:    $AGY_PORT"
echo " Home:    $HOME"
echo " Workspace: $AGY_WORKSPACE_ROOT"
echo "=========================================================="

# Ensure directories exist
mkdir -p "$AGY_HOME" "$AGY_WORKSPACE_ROOT" "$(dirname "$AGY_LANGUAGE_SERVER")" "$HOME/.gemini"

# Determine if the invoked command requires language_server
NEED_LS="false"
if [ "$#" -eq 0 ]; then
    NEED_LS="true"
elif [ "$1" = "agy-server" ] && { [ "$#" -eq 1 ] || [ "${2:-}" = "serve" ]; }; then
    NEED_LS="true"
elif [ "$1" = "serve" ]; then
    NEED_LS="true"
fi

# Check if language_server binary exists; if missing and required, download it automatically
if [ "$NEED_LS" = "true" ] && [ ! -f "$AGY_LANGUAGE_SERVER" ]; then
    echo "[entrypoint] language_server binary not found at $AGY_LANGUAGE_SERVER."
    echo "[entrypoint] Downloading latest official Antigravity language_server..."
    if agy-server update --yes --force; then
        echo "[entrypoint] language_server successfully downloaded."
    else
        echo "[entrypoint] WARNING: Automatic download of language_server failed."
        echo "[entrypoint] Please ensure the container has internet access or mount a valid binary to $AGY_LANGUAGE_SERVER."
    fi
fi

if [ -f "$AGY_LANGUAGE_SERVER" ]; then
    chmod +x "$AGY_LANGUAGE_SERVER"
fi

# Handle non-root user execution if PUID is specified
if [ "$PUID" -ne 0 ]; then
    echo "[entrypoint] Configuring permissions for UID=$PUID, GID=$PGID..."
    
    # Create group if not present
    if ! getent group "$PGID" >/dev/null 2>&1; then
        groupadd -g "$PGID" agygroup 2>/dev/null || true
    fi
    # Create user if not present
    if ! getent passwd "$PUID" >/dev/null 2>&1; then
        useradd -u "$PUID" -g "$PGID" -d "$HOME" -s /bin/bash -M agyuser 2>/dev/null || true
    fi

    # Ensure ownership of mounted directories
    chown -R "$PUID:$PGID" "$AGY_HOME" "$AGY_WORKSPACE_ROOT" "$(dirname "$AGY_LANGUAGE_SERVER")" "$HOME/.gemini" 2>/dev/null || true

    if [ "$1" = "agy-server" ]; then
        exec gosu "$PUID:$PGID" "$@"
    elif [ "$#" -gt 0 ]; then
        exec gosu "$PUID:$PGID" "$@"
    else
        exec gosu "$PUID:$PGID" agy-server serve
    fi
fi

# Running as root
if [ "$1" = "agy-server" ]; then
    exec "$@"
elif [ "$#" -gt 0 ]; then
    exec "$@"
else
    exec agy-server serve
fi
