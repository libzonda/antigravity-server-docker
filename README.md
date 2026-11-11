# Antigravity Server Docker

Docker 容器化部署方案，支持 **随着 upstream 版本自动检查与平滑更新**，基于 Google Antigravity 自托管代理服务 [antigravity-server](https://github.com/AFSlayer/antigravity-server)。

[![Build and Publish Docker Images](https://github.com/libzonda/antigravity-server-docker/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/libzonda/antigravity-server-docker/actions/workflows/docker-publish.yml)
[![GHCR](https://img.shields.io/badge/ghcr.io-libzonda%2Fantigravity--server-blue?logo=github)](https://github.com/libzonda/antigravity-server-docker/pkgs/container/antigravity-server)
[![Latest Tag](https://img.shields.io/badge/version-v0.2.65-brightgreen.svg)](https://github.com/AFSlayer/antigravity-server/releases/tag/v0.2.65)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/AFSlayer/antigravity-server/blob/main/LICENSE)

---

## 🌟 核心特性

- 🔄 **随版本自动更新**：内置 `build.sh` 与 `update.sh`，自动比对上游 Git Tag，一键切换并构建对应版本的镜像；
- 📦 **开箱即用**：提供完善的 `docker-compose.yml`，内置健康检查、音视频/大文件支持、无头环境 Google OAuth 中继；
- ⚡ **双层自动运维**：
  - **外层**：脚本一键跟随 `antigravity-server` 补丁更新（`./update.sh`）；
  - **内层**：容器内集成 Google `language_server` 自动下载与每日空闲内存维护；
- 🛡️ **轻量且安全**：基于 Debian Slim 打造，静态编译 Go 二进制，支持 `PUID`/`PGID` 权限降权，镜像仅约 68MB；
- 📱 **完备移动端体验**：包含 61 项触屏 UX、虚拟键盘追踪、CJK 输入法保护、长列表滚动防雪崩补丁。

---

## 🚀 快速开始

### 1. 克隆并进入目录
```bash
git clone --recurse-submodules https://github.com/libzonda/antigravity-server-docker.git
cd antigravity-server-docker
```

### 2. 构建 Docker 镜像
使用构建脚本，自动探测并检出最新 Tag 并完成编译：
```bash
./build.sh
```

### 3. 配置环境变量（可选）
复制配置模板：
```bash
cp .env.example .env
```
编辑 `.env` 设置你的端口或固定密码：
```env
AGY_PORT=8765
AGY_PASSWORD=YourStrongPassword123!
```
> 注：若不设置 `AGY_PASSWORD`，首次启动会在容器日志中打印随机生成的安全密码。

### 4. 启动服务
```bash
docker compose up -d
```
启动后访问 `http://<服务器IP>:8765` 即可打开 Web 界面。

---

## 🔄 随版本更新机制（Version Upgrades）

项目设计了全自动的版本检测与更新流程，可根据需要随时跟进上游新版本：

### 1. 检查是否有新版本
```bash
./build.sh --check
```
*输出示例：*
- 若已是最新：`[OK] Local repository is already on the latest tag (v0.2.65).`
- 若有新版本：`[WARN] A newer tag is available: v0.2.66 (current: v0.2.65).`

### 2. 一键更新并重启容器（推荐）
执行 `update.sh` 脚本：
```bash
./update.sh
```
该脚本会自动：
1. 抓取 upstream 最新 Git Tag；
2. 检出最新版本源码并编译新镜像（如 `antigravity-server:v0.2.66` 和 `latest`）；
3. 自动调用 `docker compose up -d` 重建并平滑重启容器。

> **提示**：可将 `./update.sh` 加入系统的 `crontab` 定时任务，实现无人值守自动更新：
> ```cron
> # 每天凌晨 3 点自动检查更新
> 0 3 * * * cd /home/user/antigravity-server-docker && ./update.sh >> update.log 2>&1
> ```

### 3. 构建指定版本
如需构建或回退到特定历史版本：
```bash
./build.sh --tag v0.2.64
```

### 4. 构建参数参考
| 参数 | 说明 |
| :--- | :--- |
| `--latest` | （默认）自动拉取远程 Tags，检出最新版本并构建 |
| `--tag <TAG>` | 检出指定 Git Tag 并构建（如 `--tag v0.2.65`） |
| `--current` | 基于当前检出的本地代码构建，不切换 Tag |
| `--check` | 仅检查是否有上游更新，不执行构建 |
| `--pull-ls` | 构建期预先下载 Google `language_server`（~180MB），使镜像完全支持离线运行 |
| `--push` | 构建后自动推送到远程镜像仓库（配合 `IMAGE_NAME`） |
| `--image <NAME>` | 自定义镜像仓库名称（默认 `antigravity-server`） |
| `--no-cache` | 构建时不使用 Docker 缓存 |

---

## 🤖 GitHub Actions 自动构建与发布 (CI/CD)

项目已内置完整的 GitHub Actions 工作流 [`.github/workflows/docker-publish.yml`](.github/workflows/docker-publish.yml)，支持同时构建并推送到 **GitHub Container Registry (GHCR)** 和 **Docker Hub**：

- 🚀 **多架构构建**：同时构建并发布 `linux/amd64` 和 `linux/arm64`（Apple Silicon、Raspberry Pi 等）；
- ⏰ **定时追新 (Cron)**：每天定时检测 upstream 新版本，自动构建并发布；
- 🏷️ **多 Tag 自动生成**：自动生成 `:latest`、`:v0.2.65`、`:0.2.65` 等标签；
- 🕹️ **手动触发 (Workflow Dispatch)**：支持在 GitHub 网页一键点击触发，并可指定编译版本。

### 配置 GitHub Secrets（发布到 Docker Hub）
若需推送到 Docker Hub，只需在你的 GitHub 仓库设置中（**Settings → Secrets and variables → Actions**）添加以下两个 Secret：

| Secret 名称 | 必填 | 说明 |
| :--- | :---: | :--- |
| `DOCKERHUB_USERNAME` | 是 | 你的 Docker Hub 用户名 |
| `DOCKERHUB_TOKEN` | 是 | 你的 Docker Hub Personal Access Token (PAT) |
| `DOCKERHUB_REPO` | 否 | 自定义镜像名（默认 `${DOCKERHUB_USERNAME}/antigravity-server`） |

> **说明**：GHCR (`ghcr.io`) 使用 GitHub 内置的 `GITHUB_TOKEN`，无需任何配置即可开箱自动推送！如未配置 Docker Hub Secret，工作流会自动安全跳过 Docker Hub，仅推送到 GHCR。

---

## 🔑 Google 账号认证

容器启动后，如何登录你的 Google 账号：

### 方式 A：Web 界面验证码登录（推荐）
1. 在浏览器打开 `http://<服务器IP>:8765`；
2. 进入 **Settings → Account**，点击 **Sign In**；
3. 系统会自动重定向至 `/__agy/signin`，点击链接在手机/PC 上完成 Google 授权；
4. 授权完成后 Google 会展示一次性验证码，将验证码粘贴回页面即可完成认证。

### 方式 B：从本地已有环境直接复制 Token
如果你本地电脑（Mac/Windows/Linux）已经登录过 Antigravity，可直接复制 token 文件到挂载目录：
```bash
cp ~/.gemini/jetski-standalone-oauth-token ./gemini/jetski-standalone-oauth-token
```

---

## 📁 数据持久化说明

`docker-compose.yml` 默认映射了以下数据卷，确保升级或销毁容器时数据不丢失：

| 宿主机路径 | 容器内路径 | 存储内容 |
| :--- | :--- | :--- |
| `./data` | `/data` | 认证密码、Web 会话、CSRF Token、配置文件 |
| `./workspace` | `/workspace` | 你的项目代码目录，Agent 操作的工作区 |
| `./gemini` | `/data/.gemini` | Google OAuth 登录凭证（jetski token）、Rules 与 Skills |
| `./opt-ls` | `/opt/agy-server` | Google `language_server` 核心执行文件（避免容器重建重复下载 180MB） |

---

## ⚙️ 环境变量列表

| 变量名 | 默认值 | 说明 |
| :--- | :--- | :--- |
| `AGY_PORT` | `8765` | Web 界面监听端口 |
| `AGY_PASSWORD` | 随机生成 | Web 访问密码（首次启动未配置会在容器日志中打印） |
| `AGY_PUBLIC_URL` | 空 | 外部公开访问地址（例如 `https://agy.example.com`） |
| `AGY_TRUSTED_PROXIES`| 空 | 受信任反向代理 CIDR（如位于 Caddy/Nginx 后设为 `127.0.0.1/32`） |
| `PUID` / `PGID` | `0` (root) | 映射到宿主机的用户与组 ID，设为 `1000:1000` 可避免文件权限被 root 占用 |
| `AGY_WORKSPACE_ROOT` | `/workspace` | 容器内的工作区根目录 |

---

## 🌐 生产反向代理配置

若需配置 HTTPS 域名访问，需确保 **禁用缓冲（proxy_buffering off）** 并 **开启 WebSocket 升级**：

### Nginx 示例
```nginx
server {
    listen 443 ssl http2;
    server_name agy.example.com;

    # SSL 证书配置
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

        # 禁用缓冲（实时打字流必须）
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 86400s;

        # 传递客户端真实 IP
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
