#!/bin/sh
# Starts `reh web` on loopback and Caddy on :80. Stops the container if either dies.
set -eu

CADDYFILE=/etc/caddy/Caddyfile
if [ -n "${BASIC_AUTH_HASH:-}" ] && [ -n "${BASIC_AUTH_USER:-}" ]; then
  CADDYFILE=/etc/caddy/Caddyfile.auth
  echo "[caddy] basic auth propio habilitado (usuario ${BASIC_AUTH_USER})"
else
  echo "[caddy] sin auth propia: se espera que EasyPanel aplique Basic Auth al dominio"
fi

if [ -z "${FAL_KEY:-}" ]; then
  echo "[reh] aviso: FAL_KEY no está definida — solo probe/demo/plan (sin IA, sin build)."
fi

mkdir -p "${REH_DATA_DIR:-/data}"

echo "[reh] $(reh --version 2>&1)"
reh doctor 2>&1 || true

# cwd = /data: aquí viven reh-runs/ y un .env opcional (volumen persistente)
cd "${REH_DATA_DIR:-/data}"
reh web --no-open --port 4400 &
REH_PID=$!
echo "[reh] web pid=$REH_PID en 127.0.0.1:4400"

caddy run --config "$CADDYFILE" --adapter caddyfile &
CADDY_PID=$!
echo "[caddy] pid=$CADDY_PID en :80 ($CADDYFILE)"

stop_all() { kill "$REH_PID" "$CADDY_PID" 2>/dev/null || true; }
trap stop_all INT TERM

while kill -0 "$REH_PID" 2>/dev/null && kill -0 "$CADDY_PID" 2>/dev/null; do
  sleep 2
done

echo "[reh] un proceso terminó; cerrando el contenedor"
stop_all
wait 2>/dev/null || true
exit 1
