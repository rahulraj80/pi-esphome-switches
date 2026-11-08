#!/usr/bin/env python3
#
# pi-control-server.py — lightweight HTTP server that exposes Raspberry Pi
# hardware actions (reboot, shutdown, update, start/stop VNC) as REST
# endpoints.
#
# Uses only the Python standard library (http.server) so nothing extra
# needs to be installed.
#
# Endpoints (all POST):
#   POST /action/reboot      -> reboot the Pi
#   POST /action/shutdown    -> power off the Pi
#   POST /action/update      -> apt update + upgrade
#   POST /action/vnc/start   -> start vncserver-x11-serviced
#   POST /action/vnc/stop    -> stop vncserver-x11-serviced
#   GET  /action/vnc/status  -> returns "ON" or "OFF"
#   GET  /health             -> health check
#
# Runs as root (via systemd User=root or sudo) so actions work without
# per-command sudoers entries. Bound to 127.0.0.1:8080 by default —
# expose via Home Assistant REST commands on the local LAN.
#

import http.server
import json
import os
import subprocess
import sys
from threading import Thread

HOST = os.environ.get("PI_CONTROL_HOST", "127.0.0.1")
PORT = int(os.environ.get("PI_CONTROL_PORT", "8080"))
ACTION_SCRIPT = "/opt/pi-esphome-switches/scripts/pi-actions.sh"


def run(action):
    """Run an action script. Returns (returncode, output)."""
    try:
        result = subprocess.run(
            ["sudo", ACTION_SCRIPT, action],
            capture_output=True,
            text=True,
            timeout=300,
        )
        return result.returncode, (result.stdout or result.stderr).strip()
    except subprocess.TimeoutExpired:
        return 124, "timeout"
    except Exception as exc:  # pylint: disable=broad-except
        return 1, str(exc)


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format, *args):  # noqa: ARG002
        # Silence default request logging
        pass

    def _send(self, code, body):
        payload = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):  # noqa: N802
        if self.path == "/health":
            self._send(200, {"status": "ok"})
        elif self.path == "/action/vnc/status":
            rc, out = run("vnc-status")
            self._send(200, {"status": out})
        else:
            self._send(404, {"error": "not found"})

    def do_POST(self):  # noqa: N802
        routes = {
            "/action/reboot": "reboot",
            "/action/shutdown": "shutdown",
            "/action/update": "update",
            "/action/vnc/start": "vnc-start",
            "/action/vnc/stop": "vnc-stop",
        }
        action = routes.get(self.path)
        if action is None:
            self._send(404, {"error": "not found"})
            return

        rc, out = run(action)
        if rc == 0:
            self._send(200, {"action": action, "status": "ok", "output": out})
        else:
            self._send(500, {"action": action, "status": "error", "output": out})


def main():
    server = http.server.ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"pi-control-server listening on {HOST}:{PORT}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    server.server_close()


if __name__ == "__main__":
    main()
