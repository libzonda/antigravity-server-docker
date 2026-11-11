# syntax=docker/dockerfile:1

# ==============================================================================
# Stage 1: Build the agy-server Go binary (natively on builder platform)
# ==============================================================================
FROM --platform=$BUILDPLATFORM golang:1.24-bookworm AS builder

ARG TARGETOS
ARG TARGETARCH
ARG VERSION="dev"

WORKDIR /build

# Pre-fetch Go modules for efficient layer caching
COPY antigravity-server/go.mod antigravity-server/go.sum ./
RUN go mod download

# Copy source code and build statically linked executable for target OS and Arch
COPY antigravity-server/ ./
RUN CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH:-amd64} go build \
    -trimpath \
    -ldflags "-s -w -X main.version=${VERSION}" \
    -o /out/agy-server \
    ./cmd/agy-server

# ==============================================================================
# Stage 2: Minimal runtime image based on Debian slim
# ==============================================================================
FROM debian:bookworm-slim

# Build-time arguments
ARG DOWNLOAD_LS=false

# Default environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    HOME=/data \
    AGY_HOME=/data \
    AGY_PORT=8765 \
    AGY_BIND=0.0.0.0 \
    AGY_WORKSPACE_ROOT=/workspace \
    AGY_LANGUAGE_SERVER=/opt/agy-server/language_server

# Install core runtime dependencies:
# - ca-certificates: for Google API and HTTPS outbound connections
# - curl: for healthcheck and downloading language_server
# - tar & gzip: for extracting official archive
# - procps: provides ps utility required for fallback process discovery
# - git: for workspace repo operations
# - gosu: for elegant privilege drop when PUID/PGID is set
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    tar \
    gzip \
    procps \
    git \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Copy built server binary from builder stage
COPY --from=builder /out/agy-server /usr/local/bin/agy-server
RUN chmod 755 /usr/local/bin/agy-server

# Create mount points and directories
RUN mkdir -p /data /workspace /opt/agy-server /data/.gemini

# Optional: pre-download the official Google language_server during docker build
RUN if [ "$DOWNLOAD_LS" = "true" ]; then \
      echo "Pre-downloading official Antigravity language_server during image build..." && \
      /usr/local/bin/agy-server update --yes --force || \
      echo "Notice: Pre-download skipped or failed; entrypoint will auto-download on first container start."; \
    fi

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

# Expose default Web UI and RPC port
EXPOSE 8765

# Volume declarations for persistence
VOLUME ["/data", "/workspace", "/opt/agy-server"]

WORKDIR /workspace

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -fsSL http://127.0.0.1:${AGY_PORT}/favicon.ico || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["agy-server", "serve"]
