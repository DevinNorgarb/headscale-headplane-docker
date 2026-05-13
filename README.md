# Headscale + Headplane (Docker Compose, Rocky Linux 9)

Turnkey Compose stack: **Headscale** (Tailscale-compatible control server) on port **8080** and **Headplane** (web UI) on port **3000**.

## Layout

```text
.
├── compose.yml
├── README.md
├── config/
│   ├── config.yaml      # Headscale
│   ├── headplane.yaml   # Headplane (required by the UI image)
│   └── acl.hujson       # minimal ACL policy file (mounted read-only)
├── data/
│   ├── headscale/       # SQLite DB, Noise/DERP keys (created on first run)
│   └── headplane/       # Headplane app data
└── scripts/
    └── deploy.sh        # installs Docker if needed, creates dirs, starts stack
```

## Quick start

1. Copy this directory onto your Rocky Linux 9 host.

2. Run the deploy script as **root** (it uses `dnf` and manages Docker):

   ```bash
   chmod +x scripts/deploy.sh
   sudo ./scripts/deploy.sh
   ```

3. Open Headplane:

   - Direct to container port: `http://YOUR_SERVER_IP:3000/admin`
   - Behind TLS on **`scale.f1y.ing`** (recommended): use your reverse proxy path (often `https://scale.f1y.ing/admin`). This repo’s configs assume **`server_url`** / **`base_url`** / **`public_url`** are `https://scale.f1y.ing`. Tailscale nodes still talk to Headscale via that HTTPS URL while Headplane calls Headscale internally at `http://headscale:8080`.

   Plain **`http://scale.f1y.ing:8080`** can reach Headscale directly for debugging; clients should still use **`https://scale.f1y.ing`** as `server_url` when TLS terminates at your proxy.

   See Headscale reverse-proxy notes: [Integration / Reverse proxy](https://headscale.net/stable/ref/integration/reverse-proxy/).

4. Create a Headscale API key and paste it at the Headplane login prompt:

   ```bash
   docker compose exec headscale headscale apikeys create --expiration 90d
   ```

   Adjust expiry as needed (`720h`, `365d`, etc.).

## Editing configuration

- **Headscale**: edit `config/config.yaml`, then restart:

  ```bash
  docker compose restart headscale headplane
  ```

- **Headplane** (cookie secret, base URL, etc.): edit `config/headplane.yaml`, then:

  ```bash
  docker compose restart headplane
  ```

- **ACLs / policy**: edit `config/acl.hujson`, then `docker compose restart headscale`.

## Hostname in this repo

| Setting | Value |
| --- | --- |
| Headscale `server_url` | `https://scale.f1y.ing` |
| Headplane `server.base_url` | `https://scale.f1y.ing` |
| Headplane `headscale.public_url` | `https://scale.f1y.ing` |

If Headplane is only exposed as **`http://scale.f1y.ing:3000`** (no HTTPS on that port), set `base_url` to that URL, use `cookie_secure: false`, and put Headscale `server_url` back to whatever URL nodes actually use.

## Optional checks

Validate Headscale config inside the container:

```bash
docker compose exec headscale headscale configtest
```

## Troubleshooting

### Headplane exits: `pre_authkey` / `pod_name` missing

Current Headplane builds validate **every** integration subtree. Keep `integration.agent.pre_authkey` as an empty string when the agent is disabled, and set `integration.kubernetes.pod_name` (ignored while `kubernetes.enabled` is false). This repo’s `config/headplane.yaml` includes both.

### Headscale log: “Listening without TLS but ServerURL does not start with http://”

Expected when **`server_url`** is `https://…` for clients but Headscale itself listens on plain HTTP (**`listen_addr`** inside Docker) and **TLS terminates at your reverse proxy**. Match [Headscale reverse-proxy TLS notes](https://headscale.net/stable/ref/integration/reverse-proxy/) (`tls_cert_path` / `tls_key_path` empty, proxy forwards WebSockets).

## Notes

- Images use `latest` tags; pin versions in `compose.yml` when you want reproducible upgrades.
- With HTTPS on **`scale.f1y.ing`**, `cookie_secure` is `true`. Terminate TLS in your reverse proxy and forward to container ports **8080** (Headscale) and **3000** (Headplane).
