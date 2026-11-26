# Antigravity Server Docker

[![GitHub](https://img.shields.io/badge/GitHub-libzonda%2Fantigravity--server--docker-blue?logo=github)](https://github.com/libzonda/antigravity-server-docker)
[![Docker Multi-Arch](https://img.shields.io/badge/arch-amd64%20%7C%20arm64-brightgreen)](https://github.com/libzonda/antigravity-server-docker)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](https://github.com/AFSlayer/antigravity-server/blob/main/LICENSE)

Ready-to-use Docker container for [Google Antigravity](https://antigravity.google) based on [antigravity-server](https://github.com/AFSlayer/antigravity-server). It turns Antigravity's standalone binary into a secure, self-hosted cloud and mobile assistant with **100+ runtime UX patches** (compatible with Antigravity 2.34–2.35+), remote direct access, and zero relay dependencies.

Supports **`linux/amd64`** and **`linux/arm64`** (Apple Silicon, Raspberry Pi 5, AWS Graviton, Oracle Cloud ARM).

---

## 🚀 Quick Start

### Option 1: Docker Compose (Recommended — No Build)

Save the following as `docker-compose.yml`:

```yaml
services:
  antigravity-server:
    # Docker Hub image (or use GHCR: ghcr.io/libzonda/antigravity-server:latest)
    # Pin a specific release tag if preferred, e.g. libzonda/antigravity-server:v0.2.78
    image: libzonda/antigravity-server:latest
    container_name: antigravity-server
    restart: unless-stopped
    ports:
      - "8765:8765"
    environment:
      - AGY_PORT=8765
      - AGY_BIND=0.0.0.0
      - AGY_WORKSPACE_ROOT=/workspace
      # Optional: set access password (auto-generated and printed in logs if omitted)
      - AGY_PASSWORD=YourSecurePassword123!
      # Optional: public HTTPS domain when behind a reverse proxy (e.g. https://agy.example.com)
      - AGY_PUBLIC_URL=
      # Optional: trusted reverse proxy CIDR (e.g. 127.0.0.1/32)
      - AGY_TRUSTED_PROXIES=
      # Optional: user permissions for mounted files (0 for root, or 1000)
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

Start the container:
```bash
docker compose up -d
```

Open `http://<your-server-ip>:8765` in your browser.

---

### Option 2: Docker Run

```bash
docker run -d \
  --name antigravity-server \
  --restart unless-stopped \
  -p 8765:8765 \
  -v $(pwd)/data:/data \
  -v $(pwd)/workspace:/workspace \
  -v $(pwd)/gemini:/data/.gemini \
  -v $(pwd)/opt-ls:/opt/agy-server \
  -e AGY_PASSWORD=YourSecurePassword123! \
  libzonda/antigravity-server:latest
```

View the generated password (if `AGY_PASSWORD` was omitted):
```bash
docker logs antigravity-server
```

---

## 🌟 Key Features & Why This Image?

| Feature | Official Bridge (`antigravity.google.com`) | This Docker Image (`antigravity-server`) |
| :--- | :--- | :--- |
| **Mobile & Touch UX** | Desktop web bundle (missing `+` and `⋮` menus) | **100+ runtime patches**: restored `(+)` button, agent picker, context window indicator, delete/pin/archive menu, permanent Undo & Copy buttons |
| **iOS Keyboard & Scrolling** | Visual viewport jitter, safe-area gap, IME text duplication | Visual viewport tracking, safe-area collapsed to 0px, CJK IME composition protection, scroll anchoring |
| **Sidecar, Preview & OAuth** | Localhost tools unreachable remotely | Opaque-origin **Sidecar UI sandbox** (`/__agy/sidecar/`), **localhost preview** (`/__agy/api/loopback-fetch`), and **remote OAuth callback relay** (`/__agy/api/oauth-callback`) |
| **Connection Path** | Relayed through Google servers | **Direct connection** (your domain, VPN, or private LAN) |
| **RPC WebSocket Transport** | Uncompressed large JSON transfers, prone to timeout | **Relay termination with context compression** (70–85% bandwidth reduction) |
| **Reconnect on Restart** | CSRF Token invalidation causing 502 crash | **Persistent CSRF Token & gRPC Status 14 mapping** for seamless auto-reconnect |
| **File Uploads** | Strict 1MB RPC text payload limit | **Chunked streaming uploader** for logs, datasets, and large files |
| **Memory Management** | Memory creeps up to 4GB+ on prolonged sessions | **Daily idle maintenance restart** recycling memory |
| **Access Control** | Google login required | Self-hosted **PBKDF2-SHA256 password, session tokens, and IP brute-force limiter** |

---

## 🔑 Google Account Sign-In in Headless Docker

Google's standalone build opens `xdg-open` for OAuth and redirects to `localhost`. This container intercepts the flow so you can sign in from any remote browser without SSH tunnels:

1. Open `http://<your-server-ip>:8765` in your browser.
2. Go to **Settings → Account** and click **Sign In**.
3. It redirects to the built-in sign-in page (`/__agy/signin`). Click the Google consent link.
4. Authorize with your Google account. Google will present a one-time verification code.
5. Paste the code back into the web interface to complete login.

*(Alternative)*: If you already signed in on a desktop machine, simply copy the token into the mounted `./gemini` directory:
```bash
cp ~/.gemini/jetski-standalone-oauth-token ./gemini/jetski-standalone-oauth-token
```

---

## 📁 Volume Persistence

| Host Path | Container Path | Purpose |
| :--- | :--- | :--- |
| `./data` | `/data` | Web login password verifier, sessions, CSRF token, and config |
| `./workspace` | `/workspace` | User project directory where the Agent creates and edits code |
| `./gemini` | `/data/.gemini` | Google OAuth token (`jetski-standalone-oauth-token`), custom skills & rules |
| `./opt-ls` | `/opt/agy-server` | Google `language_server` binary (~200–240MB; persisted to prevent re-downloading) |

---

## ⚙️ Environment Variables

| Variable | Default | Description |
| :--- | :--- | :--- |
| `AGY_PORT` | `8765` | Server listening port inside the container (keep `8765` for healthcheck; remap host side via `ports`) |
| `AGY_BIND` | `0.0.0.0` | Bind IP address |
| `AGY_PASSWORD` | *(Generated)* | Access password (auto-generated on first boot if omitted) |
| `AGY_PUBLIC_URL` | *(Empty)* | Public domain URL (e.g. `https://agy.example.com`) |
| `AGY_WORKSPACE_ROOT` | `/workspace` | Root directory for workspace projects |
| `AGY_TRUSTED_PROXIES` | *(Empty)* | Trusted proxy CIDRs (e.g. `127.0.0.1/32` behind Nginx/Caddy) |
| `AGY_SESSION_DAYS` | `30` | Login session lifetime in days |
| `AGY_WS_RELAY` | `on` | Set to `off` / `0` / `false` / `no` to pass `/connect-websocket` through uncompressed |
| `AGY_DISABLE_PATCHES` | *(Empty)* | Comma-separated patch IDs to disable (e.g. `websocket-transport-default`) |
| `PUID` / `PGID` | `0` (root) | Optional user/group ID to avoid root-owned files on host |

---

## 🌐 Reverse Proxy Configuration

When hosting behind Nginx or Caddy with HTTPS, ensure **buffering is disabled** (for real-time token streaming), **WebSocket upgrade is enabled**, and `Host` / `X-Forwarded-Host` headers are preserved:

### Nginx
```nginx
server {
    listen 443 ssl http2;
    server_name agy.example.com;

    client_max_body_size 0;

    location / {
        proxy_pass http://127.0.0.1:8765;
        proxy_http_version 1.1;

        # WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Disable buffering for real-time streaming
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 86400s;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Caddy
```caddyfile
agy.example.com {
    encode zstd gzip
    reverse_proxy 127.0.0.1:8765 {
        flush_interval -1
    }
}
```

---

## ℹ️ Notes & Limitations

- **Built-in Browser Use**: This lightweight container runs `language_server` headlessly without Electron or Chromium, so Antigravity's built-in WebView browser automation is not included. Localhost dev-server previews in the side panel still work automatically via `/__agy/api/loopback-fetch`.

---

## 🔗 Links & Credits

- GitHub Repository: [libzonda/antigravity-server-docker](https://github.com/libzonda/antigravity-server-docker)
- Upstream Project: [AFSlayer/antigravity-server](https://github.com/AFSlayer/antigravity-server)
- License: [Apache-2.0](https://github.com/AFSlayer/antigravity-server/blob/main/LICENSE)
