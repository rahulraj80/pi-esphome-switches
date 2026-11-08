#!/usr/bin/env python3
#
# pi-control-server.py — lightweight HTTP server exposing Raspberry Pi
# hardware actions as authenticated REST endpoints.
#
# Uses only the Python standard library (http.server). Nothing extra to
# install on the Pi.
#
# Endpoints (all require HTTP Basic Auth unless PI_CONTROL_AUTH=0):
#   POST /action/reboot      -> reboot the Pi
#   POST /action/shutdown    -> power off the Pi
#   POST /action/update      -> apt update + upgrade
#   POST /action/vnc/start   -> start vncserver-x11-serviced
#   POST /action/vnc/stop    -> stop vncserver-x11-serviced
#   GET  /action/vnc/status  -> returns {"status": "ON"|"OFF"}
#   GET  /health             -> health check (no auth)
#
# Configuration via environment variables:
#   PI_CONTROL_HOST      bind address (default: 127.0.0.1)
#   PI_CONTROL_PORT      bind port    (default: 9090  <- non-standard)
#   PI_CONTROL_USER      basic auth user (default: piadmin)
#   PI_CONTROL_PASS      basic auth pass (default: changeme   <- CHANGE THIS)
#   PI_CONTROL_AUTH      set to "0" to disable auth (not recommended)
#   PI_ACTION_SCRIPT     path to dispatcher (default: /opt/pi-esphome-switches/scripts/pi-actions.sh)
#

import base64
import http.server
import json
import os
import subprocess
from threading import Thread

HOST = os.environ.get("PI_CONTROL_HOST", "127.0.0.1")
PORT = int(os.environ.get("PI_CONTROL_PORT", "9090"))
USER = os.environ.get("PI_CONTROL_USER", "piadmin")
PASS = os.environ.get("PI_CONTROL_PASS", "changeme")
ENABLE_AUTH = os.environ.get("PI_CONTROL_AUTH", "1") != "0"
ACTION_SCRIPT = os.environ.get(
    "PI_ACTION_SCRIPT",
    "/opt/pi-esphome-switches/scripts/pi-actions.sh",
)

# Pre-compute the base64 token for Basic Auth comparison
_AUTH_TOKEN = base64.b64encode(f"{USER}:{PASS}".encode()).decode()


def run(action):
    """Run an action via sudo. Returns (returncode, output)."""
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


def _check_auth(handler):
    """Return True if authenticated, False if a 401 was already sent."""
    if not ENABLE_AUTH:
        return True

    auth_header = handler.headers.get("Authorization", "")
    if not auth_header.startswith("Basic "):
        handler.send_response(401)
        handler.send_header("WWW-Authenticate", 'Basic realm="Pi Control"')
        handler.send_header("Content-Length", "0")
        handler.end_headers()
        return False

    provided = auth_header[6:].strip()
    if not _constant_time_compare(provided, _AUTH_TOKEN):
        handler.send_response(401)
        handler.send_header("WWW-Authenticate", 'Basic realm="Pi Control"')
        handler.send_header("Content-Length", "0")
        handler.end_headers()
        return False

    return True


def _constant_time_compare(a, b):
    """Simple constant-time compare to avoid timing attacks."""
    if len(a) != len(b):
        return False
    result = 0
    for x, y in zip(a, b):
        result |= x != y if isinstance(x, int) else ord(x) != ord(y)
    return result == 0


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
            return

        if self.path == "/action/vnc/status":
            if not _check_auth(self):
                return
            rc, out = run("vnc-status")
            self._send(200, {"status": out})
            return

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

        if not _check_auth(self):
            return

        rc, out = run(action)
        if rc == 0:
            self._send(200, {"action": action, "status": "ok", "output": out})
        else:
            self._send(500, {"action": action, "status": "error", "output": out})


def main():
    server = http.server.ThreadingHTTPServer((HOST, PORT), Handler)
    print(
        f"pi-control-server listening on {HOST}:{PORT} "
        f"(auth={'on' if ENABLE_AUTH else 'off'})",
        flush=True,
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    server.server_close()


if __name__ == "__main__":
    main()
