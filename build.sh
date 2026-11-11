#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Antigravity Server Docker Build Script
# Supports automatic tag detection, upstream version updating, and multi-tagging.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBMODULE_DIR="${SCRIPT_DIR}/antigravity-server"

# Default configuration
DEFAULT_IMAGE_NAME="antigravity-server"
IMAGE_NAME="${IMAGE_NAME:-$DEFAULT_IMAGE_NAME}"
DOWNLOAD_LS="false"
PUSH_IMAGE="false"
NO_CACHE=""
CHECK_ONLY="false"
TARGET_TAG=""
MODE="latest" # "latest", "tag", "current"

# ANSI Color codes
BOLD=$'\033[1m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
CYAN=$'\033[36m'
DIM=$'\033[90m'
NC=$'\033[0m'

info()  { printf "${CYAN}${BOLD}[INFO]${NC} %s\n" "$*"; }
ok()    { printf "${GREEN}${BOLD}[OK]${NC}   %s\n" "$*"; }
warn()  { printf "${YELLOW}${BOLD}[WARN]${NC} %s\n" "$*"; }
error() { printf "${RED}${BOLD}[ERR]${NC}  %s\n" "$*" >&2; }
die()   { error "$*"; exit 1; }

usage() {
    cat <<EOF
${BOLD}Antigravity Server Docker Build Script${NC}

Usage:
  ./build.sh [options]

Options:
  --latest            (Default) Fetch upstream git tags, checkout the newest tag, and build.
  --tag <TAG>         Checkout and build a specific git tag (e.g. --tag v0.2.65).
  --current           Build the currently checked-out code in antigravity-server without switching.
  --check             Check if a newer tag is available upstream without building.
  --pull-ls           Pre-download the official Google language_server during Docker build
                      (makes the image fully offline-ready; image size will increase by ~170MB).
  --push              Push the built image and tags to remote Docker registry.
  --image <NAME>      Set custom image name (default: ${DEFAULT_IMAGE_NAME}).
  --no-cache          Pass --no-cache to docker build.
  -h, --help          Show this help message.

Examples:
  ./build.sh                     # Automatically fetch and build the latest tag
  ./build.sh --tag v0.2.65       # Build specific version v0.2.65
  ./build.sh --check             # Check for new upstream releases
  ./build.sh --pull-ls --push    # Build self-contained image and push
EOF
}

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --latest)
            MODE="latest"
            shift
            ;;
        --tag)
            [[ -n "${2:-}" ]] || die "Option --tag requires a tag argument (e.g. --tag v0.2.65)"
            MODE="tag"
            TARGET_TAG="$2"
            shift 2
            ;;
        --current)
            MODE="current"
            shift
            ;;
        --check)
            CHECK_ONLY="true"
            shift
            ;;
        --pull-ls)
            DOWNLOAD_LS="true"
            shift
            ;;
        --push)
            PUSH_IMAGE="true"
            shift
            ;;
        --image)
            [[ -n "${2:-}" ]] || die "Option --image requires an image name argument"
            IMAGE_NAME="$2"
            shift 2
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Unknown option: $1 (Run ./build.sh --help for options)"
            ;;
    esac
done

# Pre-flight check: ensure docker is installed
command -v docker >/dev/null 2>&1 || die "docker command not found. Please install Docker first."
[[ -d "$SUBMODULE_DIR/.git" || -f "$SUBMODULE_DIR/.git" ]] || die "antigravity-server directory is missing or not a git repository."

# Fetch latest tags from remote repository
info "Fetching remote git tags from upstream repository..."
(
    cd "$SUBMODULE_DIR"
    git fetch --tags origin --quiet 2>/dev/null || warn "Could not fetch remote tags (continuing with local tags)..."
)

# Discover tags
CURRENT_REF=$(cd "$SUBMODULE_DIR" && git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD)
LATEST_TAG=$(cd "$SUBMODULE_DIR" && git tag -l --sort=-v:refname | head -n 1)

[[ -n "$LATEST_TAG" ]] || die "No git tags found in antigravity-server repository."

info "Current checked-out version : ${YELLOW}${CURRENT_REF}${NC}"
info "Latest available upstream tag: ${GREEN}${LATEST_TAG}${NC}"

# If check-only requested
if [[ "$CHECK_ONLY" == "true" ]]; then
    if [[ "$CURRENT_REF" == "$LATEST_TAG" ]]; then
        ok "Local repository is already on the latest tag (${LATEST_TAG})."
        exit 0
    else
        warn "A newer tag is available: ${LATEST_TAG} (current: ${CURRENT_REF}). Run './build.sh --latest' to update and build."
        exit 10
    fi
fi

# Switch git ref according to mode
case "$MODE" in
    latest)
        if [[ "$CURRENT_REF" != "$LATEST_TAG" ]]; then
            info "Switching antigravity-server to latest tag: ${GREEN}${LATEST_TAG}${NC}..."
            (
                cd "$SUBMODULE_DIR"
                git checkout --quiet "$LATEST_TAG"
            )
            ok "Switched to ${LATEST_TAG}."
        else
            ok "Already on the latest tag (${LATEST_TAG})."
        fi
        BUILD_VERSION="$LATEST_TAG"
        ;;
    tag)
        info "Switching antigravity-server to requested tag: ${YELLOW}${TARGET_TAG}${NC}..."
        (
            cd "$SUBMODULE_DIR"
            git checkout --quiet "$TARGET_TAG"
        ) || die "Failed to checkout tag: $TARGET_TAG"
        ok "Switched to ${TARGET_TAG}."
        BUILD_VERSION="$TARGET_TAG"
        ;;
    current)
        BUILD_VERSION="$CURRENT_REF"
        info "Building with current checkout: ${BUILD_VERSION}..."
        ;;
esac

# Prepare Docker tags
TAGS=("-t" "${IMAGE_NAME}:latest")
TAGS+=("-t" "${IMAGE_NAME}:${BUILD_VERSION}")

# If tag starts with 'v' (e.g. v0.2.65), also add tag without 'v' (e.g. 0.2.65)
if [[ "$BUILD_VERSION" =~ ^v[0-9] ]]; then
    CLEAN_VER="${BUILD_VERSION#v}"
    TAGS+=("-t" "${IMAGE_NAME}:${CLEAN_VER}")
fi

echo ""
echo "=========================================================="
echo " Starting Docker Build for Antigravity Server"
echo " Version        : ${BUILD_VERSION}"
echo " Image Name     : ${IMAGE_NAME}"
echo " Pre-download LS: ${DOWNLOAD_LS}"
echo "=========================================================="
echo ""

# Execute Docker build
DOCKER_CMD=(
    docker build
    -f "${SCRIPT_DIR}/Dockerfile"
    "${SCRIPT_DIR}"
    --build-arg "VERSION=${BUILD_VERSION}"
    --build-arg "DOWNLOAD_LS=${DOWNLOAD_LS}"
    "${TAGS[@]}"
)

if [[ -n "$NO_CACHE" ]]; then
    DOCKER_CMD+=("$NO_CACHE")
fi

info "Executing: ${DOCKER_CMD[*]}"
"${DOCKER_CMD[@]}"

echo ""
ok "Docker image successfully built!"
echo ""
echo "Tagged images:"
for (( i=0; i<${#TAGS[@]}; i+=2 )); do
    echo "  - ${TAGS[i+1]}"
done

# Push if requested
if [[ "$PUSH_IMAGE" == "true" ]]; then
    info "Pushing tags to remote registry..."
    for (( i=0; i<${#TAGS[@]}; i+=2 )); do
        IMG="${TAGS[i+1]}"
        info "Pushing ${IMG}..."
        docker push "$IMG"
    done
    ok "All tags pushed successfully."
fi

echo ""
echo "----------------------------------------------------------"
echo " Quick Start:"
echo "   1. Using docker-compose (Recommended):"
echo "      docker compose up -d"
echo ""
echo "   2. Using docker run directly:"
echo "      docker run -d --name antigravity-server \\"
echo "        -p 8765:8765 \\"
echo "        -v \$(pwd)/data:/data \\"
echo "        -v \$(pwd)/workspace:/workspace \\"
echo "        -e AGY_PASSWORD=your_secret_password \\"
echo "        ${IMAGE_NAME}:latest"
echo "----------------------------------------------------------"
