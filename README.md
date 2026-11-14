# Antigravity Server Docker

[English](README.md) · [简体中文](README_zh-CN.md)

Production-ready Docker containerization for [antigravity-server](https://github.com/AFSlayer/antigravity-server) (Google Antigravity self-hosted reverse proxy), featuring **automated upstream version tracking and seamless zero-downtime upgrades**.

[![Build and Publish Docker Images](https://github.com/libzonda/antigravity-server-docker/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/libzonda/antigravity-server-docker/actions/workflows/docker-publish.yml)
[![Monitor Upstream Release](https://github.com/libzonda/antigravity-server-docker/actions/workflows/monitor-upstream.yml/badge.svg)](https://github.com/libzonda/antigravity-server-docker/actions/workflows/monitor-upstream.yml)
[![GHCR](https://img.shields.io/badge/ghcr.io-libzonda%2Fantigravity--server-blue?logo=github)](https://github.com/libzonda/antigravity-server-docker/pkgs/container/antigravity-server)
[![Latest Tag](https://img.shields.io/badge/version-v0.2.70-brightgreen.svg)](https://github.com/AFSlayer/antigravity-server/releases/tag/v0.2.70)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/AFSlayer/antigravity-server/blob/main/LICENSE)

---

## 🌟 Core Features

- 🔄 **Automated Version Tracking & Upgrades**: Built-in `build.sh` and `update.sh` scripts automatically detect new upstream Git tags, switch versions, and build Docker images seamlessly;
- 📦 **Out-of-the-box Deployment**: Includes a robust `docker-compose.yml` with built-in health checks, chunked streaming upload support, and headless Google OAuth relay;
- ⚡ **Dual-layer Automated Maintenance**:
  - **Outer layer**: Follows `antigravity-server` patches and releases via `./update.sh`;
  - **Inner layer**: Automatically downloads Google `language_server` on startup and recycles memory during daily idle windows;
- 🛡️ **Lightweight & Secure**: Built on Debian Slim with statically linked Go binaries, supporting `PUID`/`PGID` privilege dropping (image footprint is only ~68MB);
- 📱 **Complete Mobile Touch UX**: Includes 61 runtime patches addressing mobile touch interaction, visual viewport keyboard tracking, CJK IME composition protection, and scroll avalanche prevention.

---

## 🚀 Quick Start

### 1. Clone the Repository (with Submodules)
```bash
git clone --recurse-submodules https://github.com/libzonda/antigravity-server-docker.git
cd antigravity-server-docker
```

### 2. Build the Docker Image
Run the build script, which automatically checks out the latest upstream tag and compiles:
```bash
./build.sh
```

### 3. Configure Environment Variables (Optional)
Copy the configuration template:
```bash
cp .env.example .env
```
Edit `.env` to configure your port or static password:
```env
AGY_PORT=8765
AGY_PASSWORD=YourStrongPassword123!
```
> Note: If `AGY_PASSWORD` is omitted, a random secure password will be generated automatically on first boot and printed in the container logs.

### 4. Start the Service
```bash
docker compose up -d
```
Once started, open `http://<your-server-ip>:8765` in your browser.

---

## 🔄 Version Upgrades & Maintenance

The project is designed with an automated version detection and upgrade workflow to stay up to date with upstream releases:

### 1. Check for New Versions
```bash
./build.sh --check
```
*Example output:*
- Already up-to-date: `[OK] Local repository is already on the latest tag (v0.2.65).`
- New version available: `[WARN] A newer tag is available: v0.2.66 (current: v0.2.65).`

### 2. One-click Update & Container Restart (Recommended)
Run the `update.sh` script:
```bash
./update.sh
```
This script will:
1. Fetch latest upstream Git tags;
2. Check out the latest source code and build the updated image (e.g. `antigravity-server:v0.2.66` and `:latest`);
3. Re-run `docker compose up -d` to recreate and restart containers smoothly.

> **Tip**: You can schedule `./update.sh` via `crontab` for unattended automatic updates:
> ```cron
> # Automatically check for updates daily at 3:00 AM
> 0 3 * * * cd /path/to/antigravity-server-docker && ./update.sh >> update.log 2>&1
> ```

### 3. Build a Specific Version
To build or roll back to a specific tag:
```bash
./build.sh --tag v0.2.64
```

### 4. Build Script Options
| Flag | Description |
| :--- | :--- |
| `--latest` | (Default) Automatically fetch remote tags, check out the latest version, and build |
| `--tag <TAG>` | Check out and build a specific Git tag (e.g. `--tag v0.2.65`) |
| `--current` | Build using the currently checked-out code without switching tags |
| `--check` | Check if an upstream update is available without building |
| `--pull-ls` | Pre-download the official Google `language_server` binary (~180MB) during build for offline readiness |
| `--push` | Push the built image and tags to a remote Docker registry |
| `--image <NAME>` | Set a custom image name (default: `antigravity-server`) |
| `--no-cache` | Build without Docker cache |

---

## 🤖 GitHub Actions CI/CD Pipeline

The repository includes a complete GitHub Actions workflow [`.github/workflows/docker-publish.yml`](.github/workflows/docker-publish.yml) that builds and publishes images to both **GitHub Container Registry (GHCR)** and **Docker Hub**:

- 🚀 **Multi-Architecture**: Builds and publishes both `linux/amd64` and `linux/arm64` (Apple Silicon, Raspberry Pi, AWS Graviton);
- ⏰ **Scheduled Checks (Cron)**: Runs daily to check for upstream updates and automatically publishes new versions;
- 🏷️ **Multi-Tagging**: Generates `:latest`, `:v0.2.65`, and `:0.2.65` tags;
- 🕹️ **Manual Trigger (Workflow Dispatch)**: Can be triggered manually from the GitHub UI with custom tag parameters;
- 📝 **Automated Docker Hub README Sync**: Automatically syncs `DOCKERHUB.md` to Docker Hub overview upon release.

### Configuring GitHub Secrets (for Docker Hub)
To push to Docker Hub, add the following secrets in your repository (**Settings → Secrets and variables → Actions**):

| Secret Name | Required | Description |
| :--- | :---: | :--- |
| `DOCKERHUB_USERNAME` | Yes | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | Yes | Your Docker Hub Personal Access Token (PAT) |
| `DOCKERHUB_REPO` | No | Custom repository name (defaults to `${DOCKERHUB_USERNAME}/antigravity-server`) |

> **Note**: GHCR (`ghcr.io`) uses GitHub's built-in `GITHUB_TOKEN` and requires zero additional configuration. If Docker Hub secrets are not set, the workflow will safely skip Docker Hub and publish to GHCR only.

---

## 🔑 Google Account Sign-In (Headless Docker)

After the container starts, sign in to your Google Account using one of the following methods:

### Method A: Web UI One-Time Code Flow (Recommended)
1. Open `http://<server-ip>:8765` in your browser;
2. Navigate to **Settings → Account** and click **Sign In**;
3. You will be redirected to `/__agy/signin`. Click the Google authorization link;
4. Authorize with your Google account. Google will present a one-time code on the final screen;
5. Copy and paste the code back into the web page to complete sign-in.

### Method B: Copy Existing Token from Desktop
If you have already signed in on your local machine (macOS/Windows/Linux), copy your existing OAuth token to the mounted directory:
```bash
cp ~/.gemini/jetski-standalone-oauth-token ./gemini/jetski-standalone-oauth-token
```

---

## 📁 Volume Persistence

`docker-compose.yml` mounts the following volumes to ensure zero data loss across updates:

| Host Path | Container Path | Purpose |
| :--- | :--- | :--- |
| `./data` | `/data` | Access password hash, web sessions, CSRF token, and config |
| `./workspace` | `/workspace` | User project directory where the Agent creates and edits code |
| `./gemini` | `/data/.gemini` | Google OAuth token (`jetski-standalone-oauth-token`), custom skills & rules |
| `./opt-ls` | `/opt/agy-server` | Google `language_server` binary (persisted to avoid re-downloading ~180MB) |

---

## ⚙️ Environment Variables

| Variable | Default | Description |
| :--- | :--- | :--- |
| `AGY_PORT` | `8765` | Server listening port |
| `AGY_PASSWORD` | *(Generated)* | Web UI access password (printed to logs on first boot if omitted) |
| `AGY_PUBLIC_URL` | *(Empty)* | Public domain URL (e.g. `https://agy.example.com`) |
| `AGY_TRUSTED_PROXIES`| *(Empty)* | Trusted reverse proxy CIDRs (e.g. `127.0.0.1/32` behind Caddy/Nginx) |
| `PUID` / `PGID` | `0` (root) | Host user/group ID mapping to prevent file ownership conflicts |
| `AGY_WORKSPACE_ROOT`| `/workspace` | Workspace directory path inside container |

---

## 🌐 Production Reverse Proxy Configuration

When serving over HTTPS, ensure **buffering is disabled** (required for real-time SSE token streaming) and **WebSocket upgrade is enabled**:

### Nginx Example
```nginx
server {
    listen 443 ssl http2;
    server_name agy.example.com;

    # SSL configuration
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # Allow large file streaming uploads
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

        # Forward client IP
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

## 🤖 Automated CI/CD Workflows

This repository provides fully automated GitHub Actions workflows:

1. **[Monitor Upstream Release](.github/workflows/monitor-upstream.yml)** (`monitor-upstream.yml`):
   - Periodically monitors the upstream repository ([`AFSlayer/antigravity-server`](https://github.com/AFSlayer/antigravity-server)) for new tags / releases every hour;
   - If a new version is detected, it automatically updates the Git submodule, refreshes README version badges, commits to `main`, and triggers the Docker build workflow;
   - Supports manual trigger via `workflow_dispatch` (with an optional `force_update` flag).

2. **[Build and Publish Docker Images](.github/workflows/docker-publish.yml)** (`docker-publish.yml`):
   - Multi-architecture build for `linux/amd64` and `linux/arm64`;
   - Automatically tags and publishes images to **GitHub Container Registry (GHCR)** and **Docker Hub** (`latest`, `vX.Y.Z`, `X.Y.Z`);
   - Automatically synchronizes repository descriptions and README to Docker Hub.
