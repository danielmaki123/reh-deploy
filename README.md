# reh-deploy

Empaquetado de [REH — Reverse Engineer Higgsfield](https://github.com/dansugc/reverse-engineer-higgsfield)
(MIT) para desplegarlo como app en EasyPanel.

**No es un fork.** La imagen clona el commit fijado (`7622914…`) y lo compila.
Lo único propio es el *packaging*: FFmpeg, una fuente para subtítulos y **Caddy delante**.

## Por qué Caddy delante

`reh web` está diseñado para uso local:

- `src/web.rs:293` → `TcpListener::bind(("127.0.0.1", port))`: no acepta conexiones externas.
- `src/web.rs:43` → rechaza cualquier `Host` que no sea `localhost` / `127.0.0.1` (403).
- No tiene autenticación.

Caddy termina en `:80`, **reescribe `Host` y `Origin` a loopback** y hace proxy a
`127.0.0.1:4400`. Así el binario original funciona sin parchear y detrás de Traefik
(EasyPanel) queda con **basic auth obligatoria**.

## Variables de entorno

| Variable | Obligatoria | Qué es |
|---|---|---|
| `BASIC_AUTH_USER` | sí | usuario del basic auth |
| `BASIC_AUTH_HASH` | sí | hash **bcrypt** de la contraseña (nunca la contraseña en claro) |
| `FAL_KEY` | no | clave de fal.ai; sin ella solo funciona probe/demo/plan (gratis) |
| `REH_FONT` | no | ya viene fijada a DejaVu Sans Bold |

Generar el hash:

```bash
caddy hash-password --plaintext 'tu-contraseña'
# o
python3 -c "import bcrypt; print(bcrypt.hashpw(b'tu-contraseña', bcrypt.gensalt()).decode())"
```

> En Docker Compose / EasyPanel, `$` dentro del hash bcrypt debe escaparse como `$$`
> si se escribe en YAML. En el panel de EasyPanel se pega tal cual.

## Puerto y volumen

- **Puerto del contenedor:** `80` (el que EasyPanel mapea al dominio).
- **Volumen:** `/data` → ahí viven `reh-runs/` (análisis, keyframes, builds) y un `.env`
  opcional. Sin volumen, todo se pierde al redeploy.

## Límites y costes

- Subida máxima: **300 MB** por vídeo (`DefaultBodyLimit` de REH).
- `plan`/`--no-ai`/`demo`: gratis. `analyze` con IA: céntimos. `build`: ~$2–3 por ejecución.
- La app **no** gasta nada sin `--max-usd` y sin confirmación; el botón "Rebuild on fal"
  respeta el campo `max $`.

## Seguridad — leer antes de exponerlo

1. La `FAL_KEY` vive en el servidor: quien entre, gasta tu saldo. **No quites el basic auth.**
2. Los vídeos que subas se guardan en `/data` del VPS; con IA además se envían a fal.
3. Si el contenedor se expone sin TLS, el basic auth viaja en claro. Usa el dominio HTTPS
   de EasyPanel, nunca `http://IP:80`.
4. Rotar contraseña = cambiar `BASIC_AUTH_HASH` y redeploy.

## Actualizar REH

```bash
docker build --build-arg REH_COMMIT=<nuevo-sha> -t reh .
```

En EasyPanel: cambia el `ARG` por defecto en el `Dockerfile` (o pasa el build arg) y redeploy.
El repo upstream tiene 3 commits; revisa el diff antes de saltar de versión.
