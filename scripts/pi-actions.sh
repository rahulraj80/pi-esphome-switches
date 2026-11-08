#!/usr/bin/env bash
#
# pi-actions.sh — dispatcher for Pi hardware actions exposed via ESPHome.
#
# Installed to: /opt/pi-esphome-switches/scripts/pi-actions.sh
# Called by:    esphome/pi-switches.yaml  (via shell_command, with sudo)
#
# Each action runs as root (sudo). Make sure the pi-actions runner can
# execute these without a password — see systemd/pi-esphome-switches.sudoers
#

set -euo pipefail

ACTION="${1:-}"
LOG_FILE="/var/log/pi-esphome-switches.log"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE" 2>/dev/null || echo "[$(date '+%F %T')] $*"
}

case "$ACTION" in
  reboot)
    log "ACTION=reboot requested"
    /usr/bin/sudo /usr/sbin/reboot
    ;;

  shutdown)
    log "ACTION=shutdown requested"
    /usr/bin/sudo /usr/sbin/poweroff
    ;;

  update)
    log "ACTION=update requested (apt update + upgrade)"
    /usr/bin/sudo /usr/bin/apt-get update -y
    /usr/bin/sudo /usr/bin/apt-get upgrade -y
    log "ACTION=update completed"
    ;;

  vnc-start)
    log "ACTION=vnc-start requested"
    if /usr/bin/systemctl is-active --quiet vncserver-x11-serviced 2>/dev/null; then
      log "VNC already running"
    else
      /usr/bin/sudo /usr/bin/systemctl start vncserver-x11-serviced
      log "VNC started"
    fi
    ;;

  vnc-stop)
    log "ACTION=vnc-stop requested"
    /usr/bin/sudo /usr/bin/systemctl stop vncserver-x11-serviced 2>/dev/null || true
    log "VNC stopped"
    ;;

  vnc-status)
    if /usr/bin/systemctl is-active --quiet vncserver-x11-serviced 2>/dev/null; then
      echo "ON"
    else
      echo "OFF"
    fi
    ;;

  wifi-on)
    /usr/bin/sudo /usr/bin/nmcli radio wifi on 2>/dev/null || true
    ;;
  wifi-off)
    /usr/bin/sudo /usr/bin/nmcli radio wifi off 2>/dev/null || true
    ;;

  bt-on)
    /usr/bin/sudo /usr/bin/rfkill unblock bluetooth 2>/dev/null || true
    ;;
  bt-off)
    /usr/bin/sudo /usr/bin/rfkill block bluetooth 2>/dev/null || true
    ;;

  *)
    echo "Usage: $0 {reboot|shutdown|update|vnc-start|vnc-stop|vnc-status|wifi-on|wifi-off|bt-on|bt-off}"
    exit 1
    ;;
esac
