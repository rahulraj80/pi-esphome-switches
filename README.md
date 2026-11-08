# pi-esphome-switches

Expose Raspberry Pi hardware actions (reboot, shutdown, update, start/stop VNC, …)
as controllable endpoints and surface them in **Home Assistant** at `192.168.3.99`.

## Architecture

Two components run on the target Pi:

| Component | Role |
|-----------|------|
| **pi-control-server** (`server/pi-control-server.py`) | Lightweight stdlib HTTP server exposing REST endpoints for each action. Runs as root. Guaranteed to work. |
| **ESPHome host device** (`esphome/pi-switches.yaml`, best-effort) | Native esphome `host` platform device for HA discovery + uptime telemetry. Included but esphome's shell-command API varies by version, so the Python server is the reliable control path. |

## What you can control

| Action | Endpoint (POST) |
|--------|-----------------|
| Reboot Pi | `http://<pi-ip>:8080/action/reboot` |
| Shutdown Pi | `http://<pi-ip>:8080/action/shutdown` |
| Update system (`apt update && upgrade -y`) | `http://<pi-ip>:8080/action/update` |
| Start VNC | `http://<pi-ip>:8080/action/vnc/start` |
| Stop VNC | `http://<pi-ip>:8080/action/vnc/stop` |
| VNC status | `GET http://<pi-ip>:8080/action/vnc/status` |

## Quick start on the target Pi

```bash
git clone https://github.com/rahulraj80/pi-esphome-switches.git ~/scripts/pi-esphome-switches
cd ~/scripts/pi-esphome-switches
sudo bash deploy/install.sh
```

The server binds to `127.0.0.1:8080`. Home Assistant (on `192.168.3.99`) calls these endpoints via its **REST Command** integration.

## Home Assistant setup (192.168.3.99)

Add one **REST Command** per action:

**Settings → Devices & Services → Add Integration → REST Command**

Example for reboot:
- Name: `reboot_pi`
- URL: `http://<this-pi-ip>:8080/action/reboot`
- Method: `post`

Repeat for `shutdown_pi`, `update_pi`, `vnc_start`, `vnc_stop`.

Then create **helpers** (Settings → Devices & Services → Helpers) or **scripts** that call these rest commands, and expose them as switches/buttons on your HA dashboards.

### Optional: Long-Lived Access Token

Only needed if you call HA's REST API from outside HA:
1. Profile (bottom-left) → **Long-Lived Access Tokens** → **Create Token**
2. Name it (e.g. `pi-control`), copy it, store it safely.
3. Use `Authorization: Bearer <token>` header.

## Security notes

- Actions run as root. The sudoers rule whitelists only the commands in `systemd/pi-esphome-switches.sudoers` — review before installing.
- The control server listens on `127.0.0.1:8080` (localhost only). HA reaches it over the LAN via the Pi's IP. If you expose the port, restrict it to your LAN subnet.
- Change the esphome OTA password if you enable the esphome device.

## Logs & troubleshooting

```bash
systemctl status pi-control-server
journalctl -u pi-control-server -f
curl -X POST http://127.0.0.1:8080/action/vnc/status
curl -X POST http://127.0.0.1:8080/action/reboot
```

## License

MIT
