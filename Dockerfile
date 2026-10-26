# Packaging for EasyPanel — REH (Reverse Engineer Higgsfield)
# Upstream: https://github.com/dansugc/reverse-engineer-higgsfield  (MIT)
# This image does NOT fork the source: it clones a pinned commit and builds it.
#
# Why a proxy inside the image: `reh web` binds 127.0.0.1 and rejects foreign
# Host/Origin headers (src/web.rs). Caddy terminates the request on :80,
# rewrites Host/Origin to loopback and proxies to 127.0.0.1:4400, so the
# container can sit behind EasyPanel/Traefik without patching upstream code.

ARG REH_COMMIT=76229146669da48f54d5f107536e8a9ef0ea4a18

# ---------- build ----------
FROM rust:bookworm AS build
ARG REH_COMMIT
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone https://github.com/dansugc/reverse-engineer-higgsfield.git . \
 && git checkout "${REH_COMMIT}" \
 && rm -rf .git
RUN cargo build --release --locked

# ---------- runtime ----------
FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ffmpeg \
      fonts-dejavu-core \
      ca-certificates \
      tini \
 && rm -rf /var/lib/apt/lists/*

# Static Caddy binary (musl build) copied from the official image.
COPY --from=caddy:2-alpine /usr/bin/caddy /usr/bin/caddy

COPY --from=build /src/target/release/reh /usr/local/bin/reh

COPY Caddyfile /etc/caddy/Caddyfile
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && mkdir -p /data

ENV REH_FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf \
    REH_DATA_DIR=/data \
    XDG_DATA_HOME=/data/.caddy \
    XDG_CONFIG_HOME=/data/.caddy

WORKDIR /data
VOLUME ["/data"]
EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD caddy version >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
