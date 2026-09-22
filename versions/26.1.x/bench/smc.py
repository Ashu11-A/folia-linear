"""smc.py — send one console line to smp-test via its node API.

Transport: runs INSIDE worker-1 (same `sexidium` network, has python3), POSTs
raw command bytes to http://smp-test:8840/command with X-Sexidium-Token.
The reply is {"ok":true}; the real result lands in the smp-test console log.

Deployed with Portainer put_archive to worker-1:/tmp (container filesystem,
ephemeral, never a volume) and deleted after the study. It commands ONLY the
staging API; nothing live is ever addressed.

Usage: python3 /tmp/smc.py '<base64 of command>' [--health]
"""
import base64
import sys
import urllib.request

sys.path.insert(0, "/srv/build/repo/scripts/remote")


def _token():
    from config import Settings

    return Settings().secrets(create=False).get("api_token", "")


def _post(cmd):
    req = urllib.request.Request(
        "http://smp-test:8840/command",
        data=cmd.encode(),
        headers={"X-Sexidium-Token": _token()},
        method="POST",
    )
    return urllib.request.urlopen(req, timeout=60).read().decode()[:500]


def _health():
    req = urllib.request.Request("http://smp-test:8840/health", method="GET")
    return urllib.request.urlopen(req, timeout=15).read().decode()[:500]


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--health":
        print(_health())
    else:
        print(_post(base64.b64decode(sys.argv[1]).decode()))
