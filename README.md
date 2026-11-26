# Antigravity Server Docker

[English](README.md) · [简体中文](README_zh-CN.md)

Production-ready Docker containerization for [antigravity-server](https://github.com/AFSlayer/antigravity-server) (Google Antigravity self-hosted reverse proxy), featuring **pre-built multi-arch images, automated upstream tracking, and seamless upgrades**.

[![Build and Publish Docker Images](https://github.com/libzonda/antigravity-server-docker/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/libzonda/antigravity-server-docker/actions/workflows/docker-publish.yml)
[![Monitor Upstream Release](https://github.com/libzonda/antigravity-server-docker/actions/workflows/monitor-upstream.yml/badge.svg)](https://github.com/libzonda/antigravity-server-docker/actions/workflows/monitor-upstream.yml)
[![GHCR](https://img.shields.io/badge/ghcr.io-libzonda%2Fantigravity--server-blue?logo=github)](https://github.com/libzonda/antigravity-server-docker/pkgs/container/antigravity-server)
[![Docker Hub](https://img.shields.io/badge/docker%20hub-libzonda%2Fantigravity--server-2496ED?logo=docker&logoColor=white)](https://hub.docker.com/r/libzonda/antigravity-server)
[![Latest Tag](https://img.shields.io/badge/version-v0.2.78-brightgreen.svg)](https://github.com/AFSlayer/antigravity-server/releases/tag/v0.2.78)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/AFSlayer/antigravity-server/blob/main/LICENSE)

---

## 🌟 Core Features

- 📦 **Ready-to-Use Multi-Arch Images**: Pre-built `linux/amd64` and `linux/arm64` images published to GHCR and Docker Hub, automatically synced with upstream releases—no local Go toolchain or compilation required;
- 📱 **100+ Mobile & Desktop UX Patches**: Compatible with Antigravity 2.34–2.35+, restoring touch-friendly message actions, project `(+)` buttons, mobile agent picker, context window indicator, iOS keyboard/IME handling, and WebSocket RPC relay compression;
- 🔗 **Remote Proxies & Headless OAuth**: Includes an opaque-origin Sidecar UI sandbox (`/__agy/sidecar/`), localhost dev-server preview relay (`/__agy/api/loopback-fetch`), remote plugin/MCP OAuth callback relay (`/__agy/api/oauth-callback`), and built-in Google sign-in (`/__agy/signin`);
- ⚡ **Dual-Layer Automated Maintenance**:
  - **Outer layer**: Upstream releases are monitored hourly by GitHub Actions (or updated locally via `./update.sh`);
  - **Inner layer**: Automatically downloads Google `language_server` on first boot, checks for upstream `language_server` updates daily, and recycles memory during idle windows;
- 🛡️ **Lightweight & Secure**: Built on `debian:bookworm-slim` (~68MB base footprint) with statically linked Go binaries, `PUID`/`PGID` privilege dropping, PBKDF2-SHA256 passwords, and IP brute-force rate limiting.

> [!NOTE]
> Since Antigravity 2.34.0, upstream `antigravity-server` no longer supports attaching to a local desktop app (desktop companion mode). Running `agy-server serve` headlessly—such as via this Docker container—is the primary supported deployment method.

---

## 🚀 Quick Start

### Option 1: Pull Pre-Built Image with Docker Compose (Recommended — No Build)

Create a project directory and save the following as `docker-compose.yml` (no repository clone or local build required):

```yaml
services:
  antigravity-server:
    # GitHub Container Registry (or switch to Docker Hub: libzonda/antigravity-server:latest)
    # Pin a specific version if preferred, e.g. ghcr.io/libzonda/antigravity-server:v0.2.78
    image: ghcr.io/libzonda/antigravity-server:latest
    container_name: antigravity-server
    restart: unless-stopped
    ports:
      - "8765:8765"
    environment:
      - AGY_PORT=8765
      - AGY_BIND=0.0.0.0
      - AGY_WORKSPACE_ROOT=/workspace
      # Optional: static login password (auto-generated and printed in logs if empty)
      - AGY_PASSWORD=
      # Optional: public HTTPS domain when behind a reverse proxy (e.g. https://agy.example.com)
      - AGY_PUBLIC_URL=
      # Optional: trusted reverse proxy CIDR (e.g. 127.0.0.1/32)
      - AGY_TRUSTED_PROXIES=
      # Optional: map host UID/GID to avoid root-owned files (e.g. 1000)
      - PUID=0
      - PGID=0
    volumes:
      - ./data:/data
      - ./workspace:/workspace
      - ./gemini:/data/.gemini
      - ./opt-ls:/opt/agy-server
    healthcheck:
      test: ["CMD-SHELL", "curl -fsSL http://127.0.0.1:8765/favicon.ico || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 15s
```

Start the service:
```bash
docker compose up -d
```

If you left `AGY_PASSWORD` empty, check the auto-generated password in the container logs:
```bash
docker logs antigravity-server
```

Upgrade to the latest release anytime:
```bash
docker compose pull && docker compose up -d
```

Once running, open `http://<your-server-ip>:8765` in your browser.

#### Alternative: `docker run`
```bash
docker run -d \
  --name antigravity-server \
  --restart unless-stopped \
  -p 8765:8765 \
  -v $(pwd)/data:/data \
  -v $(pwd)/workspace:/workspace \
  -v $(pwd)/gemini:/data/.gemini \
  -v $(pwd)/opt-ls:/opt/agy-server \
  -e AGY_PASSWORD=YourStrongPassword123! \
  ghcr.io/libzonda/antigravity-server:latest
```

---

### Option 2: Build Locally from Source (Optional)

If you prefer compiling from source or customizing the build:

1. **Clone the repository (with submodules)**:
   ```bash
   git clone --recurse-submodules https://github.com/libzonda/antigravity-server-docker.git
   cd antigravity-server-docker
   ```
2. **Build the local image** (auto-fetches the latest upstream tag):
   ```bash
   ./build.sh
   ```
3. **Configure environment variables (optional)**:
   ```bash
   cp .env.example .env
   ```
   Edit `.env` to set `AGY_PORT`, `AGY_PASSWORD`, `PUID`/`PGID`, etc.
4. **Start with the repository's local `docker-compose.yml`**:
   ```bash
   docker compose up -d
   ```

---

## 🔑 Google Account Sign-In (Headless Docker)

After the container starts, sign in to your Google Account using one of the following methods:

### Method A: Web UI One-Time Code Flow (Recommended)
1. Open `http://<your-server-ip>:8765` in your browser;
2. Navigate to **Settings → Account** and click **Sign In**;
3. You will be redirected to `/__agy/signin`. Click the Google authorization link;
4. Authorize with your Google account and copy the one-time verification code shown on the final screen;
5. Paste the code back into the web page to complete sign-in.

### Method B: Copy Existing Token from Desktop
If you have already signed in on a desktop machine, copy your existing OAuth token into the mounted `./gemini` directory:
```bash
cp ~/.gemini/jetski-standalone-oauth-token ./gemini/jetski-standalone-oauth-token
```

---

## 📁 Volume Persistence

The Compose setup mounts four directories to preserve state across upgrades and container recreations:

| Host Path | Container Path | Purpose |
| :--- | :--- | :--- |
| `./data` | `/data` | Access password verifier, sessions, CSRF token, and server config |
| `./workspace` | `/workspace` | Project directory where the Agent reads, creates, and edits code |
| `./gemini` | `/data/.gemini` | Google OAuth token (`jetski-standalone-oauth-token`), custom skills & rules |
| `./opt-ls` | `/opt/agy-server` | Google `language_server` binary (~200–240MB; persisted to avoid re-downloading) |

---

## ⚙️ Environment Variables

| Variable | Default | Description |
| :--- | :--- | :--- |
| `AGY_PORT` | `8765` | Server listening port inside the container (keep `8765` for healthcheck; remap host side via `ports`) |
| `AGY_BIND` | `0.0.0.0` | Listen IP address inside the container |
| `AGY_PASSWORD` | *(Generated)* | Web UI access password (printed to logs on first boot if omitted) |
| `AGY_PUBLIC_URL` | *(Empty)* | Public domain URL when behind a reverse proxy (e.g. `https://agy.example.com`) |
| `AGY_TRUSTED_PROXIES` | *(Empty)* | Trusted reverse proxy CIDRs (e.g. `127.0.0.1/32` behind Caddy/Nginx) |
| `AGY_WORKSPACE_ROOT` | `/workspace` | Workspace root directory inside the container |
| `AGY_SESSION_DAYS` | `30` | Login session lifetime in days |
| `AGY_WS_RELAY` | `on` | Set to `off` / `0` / `false` / `no` to pass `/connect-websocket` through without compression relay |
| `AGY_DISABLE_PATCHES` | *(Empty)* | Comma-separated list of patch IDs to disable (e.g. `websocket-transport-default`) |
| `PUID` / `PGID` | `0` (root) | Host user/group ID mapping to avoid root-owned files on mounted volumes |

---

## 🌐 Production Reverse Proxy Configuration

When serving over HTTPS, ensure **buffering is disabled** (required for real-time SSE token streaming), **WebSocket upgrades are enabled** (for `/connect-websocket`), and `Host` / `X-Forwarded-Host` headers remain intact (so WebSocket `Origin` checks match). Remember to set `AGY_PUBLIC_URL` and `AGY_TRUSTED_PROXIES` in your environment.

### Nginx Example
```nginx
server {
    listen 443 ssl http2;
    server_name agy.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # Allow large chunked streaming uploads
    client_max_body_size 0;

    location / {
        proxy_pass http://127.0.0.1:8765;
        proxy_http_version 1.1;

        # WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Disable buffering for real-time token streaming (Required)
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 86400s;

        # Forward client IP & host
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Caddy Example
```caddyfile
agy.example.com {
    encode zstd gzip

    reverse_proxy 127.0.0.1:8765 {
        flush_interval -1
    }
}
```

---

## 🔄 Local Build & Upgrade Scripts

If you deploy using **Option 2 (Local Build)**, `build.sh` and `update.sh` manage upstream tracking and container restarts:

### 1. Check for Upstream Updates
```bash
./build.sh --check
```

### 2. One-Click Update & Container Restart
```bash
./update.sh
```
This script fetches upstream tags, checks out the latest release, rebuilds `antigravity-server:latest` and versioned tags, and restarts containers via `docker compose up -d`.

> **Tip**: Schedule `./update.sh` via `crontab` for unattended local builds:
> ```cron
> 0 3 * * * cd /path/to/antigravity-server-docker && ./update.sh >> update.log 2>&1
> ```

### 3. Build a Specific Version
```bash
./build.sh --tag v0.2.78
```

### 4. Build Script Options
| Flag | Description |
| :--- | :--- |
| `--latest` | (Default) Fetch remote tags, check out the latest upstream version, and build |
| `--tag <TAG>` | Check out and build a specific Git tag (e.g. `--tag v0.2.78`) |
| `--current` | Build using the currently checked-out code without switching tags |
| `--check` | Check whether a newer upstream tag exists without building |
| `--pull-ls` | Pre-download Google `language_server` (~200–240MB) during Docker build for offline readiness |
| `--push` | Push built image tags to a remote registry |
| `--image <NAME>` | Set custom image name (default: `antigravity-server`) |
| `--no-cache` | Build without Docker cache |

---

## 🤖 Automated CI/CD (GitHub Actions)

This repository maintains pre-built images automatically using two coordinated GitHub Actions workflows:

1. **[Monitor Upstream Release](.github/workflows/monitor-upstream.yml)** (`monitor-upstream.yml`):
   - Checks [`AFSlayer/antigravity-server`](https://github.com/AFSlayer/antigravity-server) every hour (`cron: '20 * * * *'`) for new releases or tags;
   - When a new version appears, automatically updates the `antigravity-server` submodule, refreshes README version badges, pushes a commit to `main`, and dispatches `docker-publish.yml`;
   - Supports manual runs via `workflow_dispatch` (including an optional `force_update` flag).

2. **[Build and Publish Docker Images](.github/workflows/docker-publish.yml)** (`docker-publish.yml`):
   - Triggered automatically on pushes to `main`/`master`, `v*` tags, `workflow_dispatch`, or `workflow_call` from `monitor-upstream.yml`;
   - Builds multi-architecture images (`linux/amd64`, `linux/arm64`) and publishes `:latest`, `:vX.Y.Z`, and `:X.Y.Z` tags to **GHCR** (`ghcr.io/libzonda/antigravity-server`) and **Docker Hub**;
   - Automatically syncs [`DOCKERHUB.md`](DOCKERHUB.md) as the Docker Hub repository overview.

### Configuring GitHub Secrets (for Docker Hub in Forks)
To also push images to your own Docker Hub repository from a fork, add these secrets in **Settings → Secrets and variables → Actions**:

| Secret Name | Required | Description |
| :--- | :---: | :--- |
| `DOCKERHUB_USERNAME` | Yes | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | Yes | Your Docker Hub Personal Access Token (PAT) |
| `DOCKERHUB_REPO` | No | Custom repository name (defaults to `${DOCKERHUB_USERNAME}/antigravity-server`) |

> **Note**: GHCR (`ghcr.io`) authenticates automatically via `GITHUB_TOKEN`. If Docker Hub secrets are not set, the workflow safely skips Docker Hub and publishes to GHCR only.

---

## ℹ️ Notes & Limitations

- **Built-in Browser Use**: This lightweight container runs Google's standalone `language_server` headlessly without Electron or Chromium, so Antigravity's built-in WebView browser automation (`webview_browser` / `browser_subagent`) is **not** available in this image. Side-panel previews of localhost dev servers started by the Agent still work automatically via `/__agy/api/loopback-fetch`.
- **First Startup**: On a fresh deployment without a pre-populated `./opt-ls` directory, the entrypoint automatically downloads Google's official `language_server` (~200–240MB) before starting the web server. Keep `./opt-ls:/opt/agy-server` mounted so container updates do not re-download it.
