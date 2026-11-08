#!/usr/bin/env bash
#
# install.sh — one-line installer for the Pi control facility.
# Run this on the target Raspberry Pi (the one you want to control).
#
#   curl -fsSL https://raw.githubusercontent.com/rahulraj80/pi-esphome-switches/main/deploy/install.sh | sudo bash
#
# What it does:
#   1. Installs python3 (already present on most Pi OS images)
#   2. Copies files to /opt/pi-esphome-switches
#   3. Sets up passwordless sudo for the whitelisted actions
#   4. Installs & enables the pi-control-server systemd service (HTTP endpoints)
#   5. (Best-effort) Installs ESPHome host device for HA discovery
#   6. Prints Home Assistant setup steps
#

set -uo pipefail

REPO_FILES="/opt/pi-esphome-switches"
PI_USER="${SUDO_USER:-pi}"

echo "[1/6] Ensuring prerequisites (python3)..."
apt-get update -y
apt-get install -y python3

echo "[2/6] Installing files to $REPO_FILES..."
install -d -o "$PI_USER" -g "$PI_USER" \
  "$REPO_FILES/server" "$REPO_FILES/scripts" "$REPO_FILES/systemd" \
  "$REPO_FILES/esphome"
cp server/pi-control-server.py "$REPO_FILES/server/"
cp scripts/pi-actions.sh "$REPO_FILES/scripts/"
chmod +x "$REPO_FILES/server/pi-control-server.py" "$REPO_FILES/scripts/pi-actions.sh"
if [ -f esphome/pi-switches.yaml ]; then
  cp esphome/pi-switches.yaml "$REPO_FILES/esphome/"
fi
chown -R "$PI_USER:$PI_USER" "$REPO_FILES"

echo "[3/6] Setting up passwordless sudo..."
install -m 0440 systemd/pi-esphome-switches.sudoers /etc/sudoers.d/pi-esphome-switches
visudo -c

echo "[4/6] Installing pi-control-server systemd service..."
cp systemd/pi-control-server.service /etc/systemd/system/pi-control-server.service
systemctl daemon-reload
systemctl enable --now pi-control-server.service

echo "[5/6] (Best-effort) Installing ESPHome host device..."
if pip3 install --user esphome 2>/dev/null; then
  export PATH="$HOME/.local/bin:$PATH"
  if [ -f "$REPO_FILES/esphome/pi-switches.yaml" ]; then
    sudo install -d -o "$PI_USER" -g "$PI_USER" /opt/pi-esphome-switches/esphome
    sudo cp "$REPO_FILES/esphome/pi-switches.yaml" /opt/pi-esphome-switches/esphome/
    sudo chown -R "$PI_USER:$PI_USER" /opt/pi-esphome-switches/esphome
    sudo ln -sf ~/.local/bin/esphome /usr/bin/esphome 2>/dev/null || true
    cp systemd/pi-esphome-switches.service /etc/systemd/system/pi-esphome-switches.service 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable --now pi-esphome-switches.service 2>/dev/null || true
    echo "    ESPHome host device installed (may need config tweaks for your esphome version)"
  fi
else
  echo "    ESPHome install failed — skipping (control server still works fine)"
fi

echo "[6/6] Done."
echo
echo "============================================================"
echo "  Pi Control Server is running on this Pi."
echo "  Endpoints (require HTTP Basic Auth, user: piadmin / pass: changeme):"
echo "    POST http://<this-pi-ip>:9090/action/reboot"
echo "    POST http://<this-pi-ip>:9090/action/shutdown"
echo "    POST http://<this-pi-ip>:9090/action/update"
echo "    POST http://<this-pi-ip>:9090/action/vnc/start"
echo "    POST http://<this-pi-ip>:9090/action/vnc/stop"
echo "    GET  http://<this-pi-ip>:9090/action/vnc/status"
echo "    GET  http://<this-pi-ip>:9090/health (no auth)"
echo
echo "  Example curl:"
echo "    curl -u piadmin:changeme -X POST http://<this-pi-ip>:9090/action/reboot"
echo
echo "  Check status:   systemctl status pi-control-server"
echo "  View logs:      journalctl -u pi-control-server -f"
echo
echo "  CHANGE THE DEFAULT CREDENTIALS:"
echo "    Edit /etc/systemd/system/pi-control-server.service"
echo "    PI_CONTROL_USER=... PI_CONTROL_PASS=..."
echo "    sudo systemctl daemon-reload && sudo systemctl restart pi-control-server"
echo
echo "  Next — add ESPHome to Home Assistant (192.168.3.99):"
echo "    Settings → Devices & Services → Add Integration → ESPHome"
echo "    Enter this Pi's IP (or let mDNS discover it)"
echo "    Then create HA automations: when an ESPHome button is pressed,"
echo "    call REST command POST http://<this-pi-ip>:9090/action/<action>"
echo "    with the same Basic Auth credentials."
echo
echo "  Optional — create an HA Long-Lived Access Token:"
echo "    Profile (bottom-left) → Long-Lived Access Tokens → Create Token"
echo "============================================================"
