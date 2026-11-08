#!/usr/bin/env bash
#
# install.sh — one-liner installer for the Pi ESPHome Switches device.
# Run this on the target Raspberry Pi (the one you want to control).
#
#   curl -fsSL https://raw.githubusercontent.com/rahulraj80/pi-esphome-switches/main/deploy/install.sh | sudo bash
#
# What it does:
#   1. Installs ESPHome (pipx) if missing
#   2. Copies files to /opt/pi-esphome-switches
#   3. Sets up passwordless sudo for the actions
#   4. Installs & enables the systemd service
#   5. Prints Home Assistant setup steps
#

set -euo pipefail

REPO_FILES="/opt/pi-esphome-switches"
PI_USER="${SUDO_USER:-pi}"

echo "[1/6] Ensuring prerequisites (python3, pip, git)..."
apt-get update -y
apt-get install -y python3 python3-pip python3-venv git

echo "[2/6] Installing ESPHome (pipx)..."
if ! command -v esphome >/dev/null 2>&1; then
  pip3 install --user esphome
  export PATH="$HOME/.local/bin:$PATH"
fi
ESPHOME_BIN="$(command -v esphome || echo "$HOME/.local/bin/esphome")"

echo "[3/6] Installing files to $REPO_FILES..."
install -d -o "$PI_USER" -g "$PI_USER" "$REPO_FILES/esphome" "$REPO_FILES/scripts" "$REPO_FILES/systemd"
cp esphome/pi-switches.yaml "$REPO_FILES/esphome/"
cp scripts/pi-actions.sh "$REPO_FILES/scripts/"
chmod +x "$REPO_FILES/scripts/pi-actions.sh"
chown -R "$PI_USER:$PI_USER" "$REPO_FILES"

echo "[4/6] Setting up passwordless sudo..."
install -m 0440 systemd/pi-esphome-switches.sudoers /etc/sudoers.d/pi-esphome-switches
visudo -c

echo "[5/6] Installing systemd service..."
cp systemd/pi-esphome-switches.service /etc/systemd/system/pi-esphome-switches.service
systemctl daemon-reload
systemctl enable --now pi-esphome-switches.service

echo "[6/6] Done."
echo
echo "============================================================"
echo "  ESPHome device 'pi-switches' is now running on this Pi."
echo "  Check status:   systemctl status pi-esphome-switches"
echo "  View logs:      journalctl -u pi-esphome-switches -f"
echo
echo "  Next — add it to Home Assistant (192.168.3.99):"
echo "    1. Settings → Devices & Services → Add Integration → ESPHome"
echo "    2. Enter this Pi's IP address (or let mDNS discover it)"
echo "    3. Submit — the buttons & switches will appear"
echo
echo "  Optional — create an HA Long-Lived Access Token (for API access):"
echo "    Profile (bottom-left) → Long-Lived Access Tokens → Create Token"
echo "    Copy the token; store it safely (HA will not show it again)"
echo "============================================================"
