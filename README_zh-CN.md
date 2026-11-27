# Antigravity Server Docker

[English](README.md) · [简体中文](README_zh-CN.md)

基于 [antigravity-server](https://github.com/AFSlayer/antigravity-server)（Google Antigravity 自托管反向代理）的 Docker 容器化部署方案，提供**开箱即用的多架构预构建镜像、上游版本自动追踪与平滑升级**。

[![Build and Publish Docker Images](https://github.com/libzonda/antigravity-server-docker/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/libzonda/antigravity-server-docker/actions/workflows/docker-publish.yml)
[![Monitor Upstream Release](https://github.com/libzonda/antigravity-server-docker/actions/workflows/monitor-upstream.yml/badge.svg)](https://github.com/libzonda/antigravity-server-docker/actions/workflows/monitor-upstream.yml)
[![GHCR](https://img.shields.io/badge/ghcr.io-libzonda%2Fantigravity--server-blue?logo=github)](https://github.com/libzonda/antigravity-server-docker/pkgs/container/antigravity-server)
[![Docker Hub](https://img.shields.io/badge/docker%20hub-libzonda%2Fantigravity--server-2496ED?logo=docker&logoColor=white)](https://hub.docker.com/r/libzonda/antigravity-server)
[![Latest Tag](https://img.shields.io/badge/version-v0.2.79-brightgreen.svg)](https://github.com/AFSlayer/antigravity-server/releases/tag/v0.2.79)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/AFSlayer/antigravity-server/blob/main/LICENSE)

---

## 🌟 核心特性

- 📦 **免编译多架构镜像**：在 GHCR 与 Docker Hub 发布 `linux/amd64` 和 `linux/arm64` 预构建镜像，随上游版本自动同步更新，无需本地搭建 Go 编译环境；
- 📱 **100+ 移动端与桌面端 UX 补丁**：完整适配 Antigravity 2.34–2.35+，恢复项目新建 `(+)` 按钮、移动端 Agent 选择器、发送按钮旁上下文窗口指示器、常驻撤销/复制操作、iOS 键盘/IME 输入法保护及 WebSocket RPC 压缩中继；
- 🔗 **本地预览与无头 OAuth 中继**：内置不透明源隔离的 Sidecar UI 沙箱（`/__agy/sidecar/`）、Agent 本地开发服务预览代理（`/__agy/api/loopback-fetch`）、远程插件/MCP OAuth 回调中继（`/__agy/api/oauth-callback`）及内建 Google 登录页（`/__agy/signin`）；
- ⚡ **双层自动运维**：
  - **外层**：GitHub Actions 每小时自动追踪上游版本构建新镜像（本地源码部署亦可通过 `./update.sh` 一键追新）；
  - **内层**：容器首次启动自动下载 Google `language_server`，每日自动检查上游 `language_server` 更新，并在空闲窗口重启回收长对话内存；
- 🛡️ **轻量且安全**：基于 `debian:bookworm-slim` 构建（基础镜像约 68MB），静态编译 Go 二进制，支持 `PUID`/`PGID` 权限降权、PBKDF2-SHA256 密码校验与登录防爆破限流。

> [!NOTE]
> 自 Antigravity 2.34.0 起，上游桌面端不再允许外部程序读取其 `language_server` 访问令牌（官方伴侣附着模式已失效）。通过无头服务器 / Docker 容器运行 `agy-server serve` 是当前受支持的主流部署方式。

---

## 🚀 快速开始

### 方式一：直接拉取预构建镜像（推荐，无需本地 Build）

创建部署目录并保存以下内容为 `docker-compose.yml`（无需克隆仓库源码，也不包含 `build`）：

```yaml
services:
  antigravity-server:
    # GitHub Container Registry（也可切换为 Docker Hub：libzonda/antigravity-server:latest）
    # 如需锁定版本可指定 Tag，例如 ghcr.io/libzonda/antigravity-server:v0.2.78
    image: ghcr.io/libzonda/antigravity-server:latest
    container_name: antigravity-server
    restart: unless-stopped
    ports:
      - "8765:8765"
    environment:
      - AGY_PORT=8765
      - AGY_BIND=0.0.0.0
      - AGY_WORKSPACE_ROOT=/workspace
      # 可选：静态登录密码（留空则在首次启动时自动生成并输出到日志）
      - AGY_PASSWORD=
      # 可选：反代后的公网 HTTPS 地址（例如 https://agy.example.com）
      - AGY_PUBLIC_URL=
      # 可选：受信任反向代理 CIDR（例如 127.0.0.1/32）
      - AGY_TRUSTED_PROXIES=
      # 可选：映射宿主机 UID/GID，避免挂载目录生成 root 属主文件（如设为 1000）
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

启动服务：
```bash
docker compose up -d
```

若未设置 `AGY_PASSWORD`，首次启动后可在容器日志中查看随机生成的密码：
```bash
docker logs antigravity-server
```

后续升级到最新版本：
```bash
docker compose pull && docker compose up -d
```

启动后在浏览器访问 `http://<服务器IP>:8765` 即可使用。

#### 备选：`docker run` 单行启动
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

### 方式二：从源码本地构建（可选）

如需自定义编译参数或从本地源码直接构建：

1. **克隆仓库（含子模块）**：
   ```bash
   git clone --recurse-submodules https://github.com/libzonda/antigravity-server-docker.git
   cd antigravity-server-docker
   ```
2. **构建本地镜像**（自动拉取上游最新 Tag 编译）：
   ```bash
   ./build.sh
   ```
3. **配置环境变量（可选）**：
   ```bash
   cp .env.example .env
   ```
   编辑 `.env` 设置 `AGY_PORT`、`AGY_PASSWORD`、`PUID`/`PGID` 等配置。
4. **使用仓库自带的本地构建配置启动**：
   ```bash
   docker compose up -d
   ```

---

## 🔑 Google 账号认证（无头容器）

容器启动后，可通过以下任一方式完成 Google 账号登录：

### 方式 A：Web 界面验证码登录（推荐）
1. 在浏览器打开 `http://<服务器IP>:8765`；
2. 进入 **Settings → Account**，点击 **Sign In**；
3. 页面会跳转至 `/__agy/signin`，点击 Google 授权链接在手机或电脑上完成登录；
4. 授权完成后复制 Google 页面展示的一次性验证码；
5. 将验证码粘贴回 Web 页面即可完成认证。

### 方式 B：复用本地电脑已有 Token
如果本地电脑已登录过 Antigravity，可直接把本地 Token 复制到挂载目录：
```bash
cp ~/.gemini/jetski-standalone-oauth-token ./gemini/jetski-standalone-oauth-token
```

---

## 📁 数据持久化说明

Compose 配置通过以下四个挂载目录确保升级或重建容器时状态不丢失：

| 宿主机路径 | 容器内路径 | 存储内容 |
| :--- | :--- | :--- |
| `./data` | `/data` | 登录密码哈希、Web 会话、CSRF Token 与服务配置 |
| `./workspace` | `/workspace` | 项目代码目录，Agent 读写和编辑的工作区 |
| `./gemini` | `/data/.gemini` | Google OAuth 凭证（`jetski-standalone-oauth-token`）、自定义 Skills 与 Rules |
| `./opt-ls` | `/opt/agy-server` | Google `language_server` 二进制（约 200–240MB，持久化以避免重建容器时重复下载） |

---

## ⚙️ 环境变量列表

| 变量名 | 默认值 | 说明 |
| :--- | :--- | :--- |
| `AGY_PORT` | `8765` | 容器内服务监听端口（建议保持 `8765` 以匹配健康检查，如需改端口请调整 `ports` 左侧宿主机端口） |
| `AGY_BIND` | `0.0.0.0` | 容器内绑定监听地址 |
| `AGY_PASSWORD` | *自动生成* | Web 登录密码（首次启动留空时会随机生成并打印到容器日志） |
| `AGY_PUBLIC_URL` | *空* | 配置 HTTPS 反代后的外部访问地址（例如 `https://agy.example.com`） |
| `AGY_TRUSTED_PROXIES` | *空* | 受信任反向代理 CIDR（例如位于 Nginx/Caddy 后可设为 `127.0.0.1/32`） |
| `AGY_WORKSPACE_ROOT` | `/workspace` | 容器内的工作区根目录 |
| `AGY_SESSION_DAYS` | `30` | Web 登录会话有效天数 |
| `AGY_WS_RELAY` | `on` | 设为 `off` / `0` / `false` / `no` 可关闭 `/connect-websocket` 压缩中继，改为直通转发 |
| `AGY_DISABLE_PATCHES` | *空* | 需要禁用的补丁 ID 列表，逗号分隔（例如 `websocket-transport-default`） |
| `PUID` / `PGID` | `0` (root) | 映射宿主机的用户与组 ID，设为 `1000` 可避免挂载目录出现 root 属主文件 |

---

## 🌐 生产反向代理配置

配置 HTTPS 域名反代时，必须**关闭代理缓冲**（保障实时流式输出）、**放行 WebSocket 升级**（用于 `/connect-websocket`）并**完整透传 `Host` / `X-Forwarded-Host`**（用于 WebSocket `Origin` 校验），同时建议在容器环境变量中设置 `AGY_PUBLIC_URL` 与 `AGY_TRUSTED_PROXIES`。

### Nginx 示例
```nginx
server {
    listen 443 ssl http2;
    server_name agy.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # 允许大文件流式上传
    client_max_body_size 0;

    location / {
        proxy_pass http://127.0.0.1:8765;
        proxy_http_version 1.1;

        # WebSocket 支持
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # 禁用缓冲（实时流式响应必须）
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 86400s;

        # 传递客户端真实 IP 与 Host
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Caddy 示例
```caddyfile
agy.example.com {
    encode zstd gzip

    reverse_proxy 127.0.0.1:8765 {
        flush_interval -1
    }
}
```

---

## 🔄 本地构建与升级脚本

若采用**方式二（本地源码构建）**，可通过内置的 `build.sh` 与 `update.sh` 跟进上游版本：

### 1. 检查上游更新
```bash
./build.sh --check
```

### 2. 一键更新并重启容器
```bash
./update.sh
```
脚本会自动抓取上游最新 Git Tag、检出源码重新编译镜像，并调用 `docker compose up -d` 平滑重建容器。

> **提示**：可将 `./update.sh` 加入 `crontab` 实现定时自动检查与本地重建：
> ```cron
> 0 3 * * * cd /path/to/antigravity-server-docker && ./update.sh >> update.log 2>&1
> ```

### 3. 构建指定版本
```bash
./build.sh --tag v0.2.78
```

### 4. 构建参数参考
| 参数 | 说明 |
| :--- | :--- |
| `--latest` | （默认）自动拉取远程 Tags，检出最新版本并构建 |
| `--tag <TAG>` | 检出指定 Git Tag 并构建（如 `--tag v0.2.78`） |
| `--current` | 基于当前本地检出的代码构建，不切换 Tag |
| `--check` | 仅检查上游是否有更新，不执行构建 |
| `--pull-ls` | 构建期预先下载 Google `language_server`（约 200–240MB），用于离线环境镜像准备 |
| `--push` | 构建完成后推送镜像及标签到远程仓库 |
| `--image <NAME>` | 自定义镜像名称（默认 `antigravity-server`） |
| `--no-cache` | 构建时不使用 Docker 缓存 |

---

## 🤖 自动化 CI/CD 工作流 (GitHub Actions)

本仓库通过两个配合运行的 GitHub Actions 工作流持续维护最新多架构镜像：

1. **[Monitor Upstream Release](.github/workflows/monitor-upstream.yml)**（`monitor-upstream.yml`）：
   - 每小时自动巡检（`cron: '20 * * * *'`）上游仓库 [`AFSlayer/antigravity-server`](https://github.com/AFSlayer/antigravity-server) 是否发布新 Tag 或 Release；
   - 一旦检测到新版本，自动更新 `antigravity-server` 子模块指针、刷新 README 版本徽章、提交推送到 `main` 分支，并自动触发 `docker-publish.yml`；
   - 支持在 Actions 页面通过 `workflow_dispatch` 手动触发（提供 `force_update` 强制触发选项）。

2. **[Build and Publish Docker Images](.github/workflows/docker-publish.yml)**（`docker-publish.yml`）：
   - 在代码推送至 `main`/`master`、推送 `v*` 标签、手动触发或由 `monitor-upstream.yml` 调度时执行；
   - 自动构建 `linux/amd64` 与 `linux/arm64` 双架构镜像，发布 `:latest`、`:vX.Y.Z`、`:X.Y.Z` 标签至 **GHCR**（`ghcr.io/libzonda/antigravity-server`）与 **Docker Hub**；
   - 自动将 [`DOCKERHUB.md`](DOCKERHUB.md) 同步更新至 Docker Hub 仓库简介。

### 配置 GitHub Secrets（Fork 后推送至自己的 Docker Hub）
如需将 Fork 仓库镜像同步推送至自己的 Docker Hub，可在 **Settings → Secrets and variables → Actions** 添加：

| Secret 名称 | 必填 | 说明 |
| :--- | :---: | :--- |
| `DOCKERHUB_USERNAME` | 是 | Docker Hub 用户名 |
| `DOCKERHUB_TOKEN` | 是 | Docker Hub Personal Access Token (PAT) |
| `DOCKERHUB_REPO` | 否 | 自定义仓库名（默认 `${DOCKERHUB_USERNAME}/antigravity-server`） |

> **说明**：GHCR (`ghcr.io`) 直接使用内置 `GITHUB_TOKEN` 鉴权，无需额外配置。若未设置 Docker Hub Secrets，工作流会自动跳过 Docker Hub 仅推送至 GHCR。

---

## ℹ️ 注意事项与功能边界

- **内置浏览器（Built-in Browser Use）说明**：本轻量容器以无头模式运行官方 `language_server`，不包含 Electron 桌面宿主或 Chromium 运行时，因此**不支持** Antigravity 原生内置 WebView 浏览器自动化能力（`webview_browser` / `browser_subagent`）。不过，Agent 在容器内启动的 localhost 开发服务仍可通过 `/__agy/api/loopback-fetch` 自动代理到 Web 侧边栏进行实时预览。
- **首次启动下载**：若未预先挂载包含二进制的 `./opt-ls` 目录，容器首次启动时入口脚本会自动从 Google 官方地址下载约 200–240MB 的 `language_server`；保持挂载 `./opt-ls:/opt/agy-server` 后，后续更新容器镜像无需重复下载。
