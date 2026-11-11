#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Antigravity Server One-Click Updater
# Checks upstream tags, updates source code, rebuilds Docker image,
# and restarts docker compose service with zero manual intervention.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORCE="false"
RESTART="auto"

# Colors
BOLD=$'\033[1m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
CYAN=$'\033[36m'
NC=$'\033[0m'

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force|-f)
            FORCE="true"
            shift
            ;;
        --no-restart)
            RESTART="false"
            shift
            ;;
        -h|--help)
            echo "Usage: ./update.sh [--force] [--no-restart]"
            echo "  --force       Rebuild and restart even if already on the latest tag"
            echo "  --no-restart  Only build the updated image without restarting containers"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

printf "${CYAN}${BOLD}[INFO]${NC} Checking for Antigravity Server upstream updates...\n"

if "${SCRIPT_DIR}/build.sh" --check; then
    if [[ "$FORCE" != "true" ]]; then
        printf "${GREEN}${BOLD}[OK]${NC} Server is already running on the latest version. Use './update.sh --force' to force rebuild.\n"
        exit 0
    else
        printf "${YELLOW}${BOLD}[INFO]${NC} Force flag set. Proceeding with rebuild...\n"
    fi
else
    printf "${CYAN}${BOLD}[INFO]${NC} New version detected! Proceeding to build...\n"
fi

# Run build for latest tag
"${SCRIPT_DIR}/build.sh" --latest

# If docker compose is installed and configured, restart container
if [[ "$RESTART" != "false" ]] && command -v docker >/dev/null 2>&1; then
    if docker compose version >/dev/null 2>&1 && [[ -f "${SCRIPT_DIR}/docker-compose.yml" ]]; then
        printf "\n${CYAN}${BOLD}[INFO]${NC} Restarting container service via Docker Compose...\n"
        (
            cd "${SCRIPT_DIR}"
            docker compose up -d
        )
        printf "${GREEN}${BOLD}[OK]${NC} Service restarted successfully with updated image!\n"
    fi
fi
