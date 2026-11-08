# pi-esphome-switches

Expose Raspberry Pi hardware actions (reboot, shutdown, update, start/stop VNC, …)
as **ESPHome buttons/switches** in Home Assistant, with the actual actions
executed by a local authenticated HTTP server.

## Target machines

- **Control Pi** (this repo's deploy target): runs ESPHome host device + pi-control-server
- **Home Assistant**: `192.168.3.99` (configured later)

## Architecture

```
┌─────────────────┐      native API (6053)      ┌─────────────────────┐
│  Home Assistant │ ◄─────────────────────────── │  ESPHome host       │
│     (.99)       │                              │  on Control Pi      │
└─────────────────┘                              │  (.94 / .99)        │
                                                 │                     │
                                                 │   HTTP Basic Auth   │
                                                 └─────────┬───────────┘
                                                           │ port 9090
                                                 ┌─────────▼───────────┐
                                                 │ pi-control-server   │
                                                 │ (executes actions)  │
                                                 └─────────────────────┘
```

ESPHome is the **connector only** — it exposes buttons/switches to HA. It does
not execute Pi actions itself (esphome on the `host` platform has no
`shell_command`). The actual `reboot`/`shutdown`/`vnc` commands run through
the separate `pi-control-server` HTTP endpoint, which HA calls with auth.

| Component | Role |
|-----------|------|
| ESPHome host device | Exposes Reboot/Shutdown/Update buttons + VNC switch to HA |
| pi-control-server | stdlib Python HTTP server on port **9090** with **HTTP Basic Auth**; executes actions via sudo |

## What you can control

| Action | HTTP endpoint (POST, Basic Auth) |
|--------|----------------------------------|
| Reboot Pi | `http://<pi-ip>:9090/action/reboot` |
| Shutdown Pi | `http://<pi-ip>:9090/action/shutdown` |
| Update system | `http://<pi-ip>:9090/action/update` |
| Start VNC | `http://<pi-ip>:9090/action/vnc/start` |
| Stop VNC | `http://<pi-ip>:9090/action/vnc/stop` |
| VNC status | `GET http://<pi-ip>:9090/action/vnc/status` |
| Health | `GET http://<pi-ip>:9090/health` (no auth) |

## Quick start on the target Pi

```bash
git clone https://github.com/rahulraj80/pi-esphome-switches.git ~/scripts/pi-esphome-switches
cd ~/scripts/pi-esphome-switches
sudo bash deploy/install.sh
```

The server binds to `127.0.0.1:9090`. Home Assistant (on `192.168.3.99`) reaches it over the LAN via the Pi's IP.

## Authentication mechanism

**HTTP Basic Auth** (RFC 7617), configured via systemd environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `PI_CONTROL_USER` | `piadmin` | Basic auth username |
| `PI_CONTROL_PASS` | `changeme` | Basic auth password |
| `PI_CONTROL_AUTH` | `1` | Set to `0` to disable (not recommended) |
| `PI_CONTROL_PORT` | `9090` | Non-standard HTTP port |

To change credentials:

```bash
sudo nano /etc/systemd/system/pi-control-server.service
# Edit PI_CONTROL_USER and PI_CONTROL_PASS
sudo systemctl daemon-reload
sudo systemctl restart pi-control-server
```

**Example direct access with curl:**

```bash
# Health check (no auth)
curl http://<pi-ip>:9090/health

# Action (with Basic Auth)
curl -u piadmin:changeme -X POST http://<pi-ip>:9090/action/reboot

# VNC status
curl -u piadmin:changeme http://<pi-ip>:9090/action/vnc/status
```

> **Security note:** Basic Auth sends credentials base64-encoded (not encrypted).
> Since this is on your LAN (`192.168.3.x`), that's acceptable for local use.
> If you ever expose port 9090 beyond your LAN, put it behind HTTPS (e.g. via
> an nginx/stunnel reverse proxy) or restrict it with firewall rules.

## Home Assistant setup (192.168.3.99) — do this after install

1. **Discover the ESPHome device:**
   Settings → Devices & Services → Add Integration → ESPHome → enter this Pi's IP

2. **Add REST commands** (one per action):
   Settings → Devices & Services → Add Integration → REST Command
   - Name: `reboot_pi`
   - URL: `http://<pi-ip>:9090/action/reboot`
   - Method: `post`
   - Authentication: `Basic` → user `piadmin`, pass `changeme`
   - Repeat for `shutdown_pi`, `update_pi`, `vnc_start`, `vnc_stop`

3. **Create automations** (button press → REST command):
   Settings → Automations → Add Automation
   - Trigger: ESPHome button `button.reboot_pi` pressed
   - Action: Call service `rest_command.reboot_pi`
   - Repeat for each button/switch

4. **Create helpers / dashboard entities** so the buttons appear as switches on your HA dashboard.

## Logs & troubleshooting

```bash
systemctl status pi-control-server
journalctl -u pi-control-server -f
curl -u piadmin:changeme -X POST http://127.0.0.1:9090/action/vnc/status
```

## License

MIT
