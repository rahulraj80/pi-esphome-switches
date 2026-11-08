# pi-esphome-switches

Expose Raspberry Pi hardware actions (reboot, shutdown, update, start/stop VNC, …)
as **ESPHome switches/buttons** and surface them in **Home Assistant** via the
ESPHome native API.

Target HA server: `192.168.3.99`

## What this gives you

| Entity | Type | Action |
|--------|------|--------|
| Reboot Pi | Button (momentary) | `reboot` |
| Shutdown Pi | Button (momentary) | `poweroff` |
| Update System | Button (momentary) | `apt update && apt upgrade -y` |
| VNC Server | Switch (toggle) | `systemctl start/stop vncserver-x11-serviced` |
| CPU Temperature | Sensor | reads thermal zone |
| Pi Uptime | Sensor | system uptime |

Optional (commented in the YAML): WiFi toggle, Bluetooth toggle.

## Architecture

- **ESPHome (linux platform)** runs natively on the Pi (no microcontroller needed).
- Buttons/switches run shell commands via `shell_command` → `scripts/pi-actions.sh` → `sudo`.
- A `systemd` service keeps ESPHome running and restarts it on failure.
- Home Assistant discovers the device through the **ESPHome integration** (native API).

## Quick start

### 1. On the target Pi (the one to control)

```bash
git clone https://github.com/rahulraj80/pi-esphome-switches.git
cd pi-esphome-switches
sudo bash deploy/install.sh
```

The installer:
- installs ESPHome,
- copies files to `/opt/pi-esphome-switches`,
- sets up passwordless `sudo` for the whitelisted commands,
- installs and starts the `pi-esphome-switches` systemd service.

### 2. In Home Assistant (192.168.3.99)

1. **Settings → Devices & Services → Add Integration → ESPHome**
2. Enter this Pi's IP address (or wait for mDNS discovery).
3. Submit. The buttons, switches, and sensors appear as entities.

> No long-lived access token is required for the ESPHome integration itself — it pairs over the native API. A token is only needed if you call HA's REST API from outside.

### 3. (Optional) Create an HA Long-Lived Access Token

If you later want to call Home Assistant's REST API:

1. In HA, click your **Profile** (bottom-left).
2. Scroll to **Long-Lived Access Tokens** → **Create Token**.
3. Give it a name (e.g. `pi-esphome-switches`), copy the token, and store it safely.
4. Use it in the `Authorization: Bearer <token>` header.

## Manual deployment (without the installer)

```bash
# 1. Install esphome
pip3 install --user esphome
export PATH="$HOME/.local/bin:$PATH"

# 2. Copy files
sudo install -d -o $USER -g $USER /opt/pi-esphome-switches/{esphome,scripts,systemd}
cp esphome/pi-switches.yaml /opt/pi-esphome-switches/esphome/
cp scripts/pi-actions.sh /opt/pi-esphome-switches/scripts/
chmod +x /opt/pi-esphome-switches/scripts/pi-actions.sh

# 3. Passwordless sudo
sudo install -m 0440 systemd/pi-esphome-switches.sudoers /etc/sudoers.d/pi-esphome-switches
sudo visudo -c

# 4. systemd
sudo cp systemd/pi-esphome-switches.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now pi-esphome-switches
```

## Configuration

Edit `esphome/pi-switches.yaml` before deploying:

- `ota.password` — set a strong OTA password.
- Uncomment the **WiFi / Bluetooth** sections in the YAML if you want those toggles.
- Change `vncserver-x11-serviced` to your VNC service name if different (e.g. `tightvncserver`).

## Logs & troubleshooting

```bash
# Service status
systemctl status pi-esphome-switches

# Live logs
journalctl -u pi-esphome-switches -f

# ESPHome logs
esphome logs /opt/pi-esphome-switches/esphome/pi-switches.yaml

# Test an action directly
sudo /opt/pi-esphome-switches/scripts/pi-actions.sh reboot
sudo /opt/pi-esphome-switches/scripts/pi-actions.sh vnc-status
```

## Security notes

- Reboot/shutdown/update run as root. The sudoers rule whitelists only the commands in `systemd/pi-esphome-switches.sudoers` — review it before installing.
- The device listens on the ESPHome native API port (6053). Keep it on a trusted LAN.
- Change the OTA password and consider binding `native_api` to a specific interface if needed.

## License

MIT
