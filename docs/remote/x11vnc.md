# x11vnc remote desktop

`x11vnc` mirrors the real Xorg display at `:0`. This matters because `Xvfb` and typical virtual VNC desktops do not exercise the Sunxi-to-PowerVR DRI3 presentation path.

Install it after `scripts/verify.sh` passes:

```bash
sudo ./scripts/install-x11vnc.sh --user "$USER"
```

Connect to:

```text
BOARD_IP:5900
```

Security recommendations:

- expose port 5900 only to a trusted LAN or VPN;
- do not forward raw VNC directly to the public internet;
- use WireGuard, NetBird, Tailscale or an SSH tunnel for remote access;
- choose a unique VNC password.

Useful checks:

```bash
systemctl status x11vnc --no-pager -l
ss -ltnp | grep ':5900'
python3 - <<'PY'
import socket
s = socket.create_connection(("127.0.0.1", 5900), timeout=5)
print(repr(s.recv(12)))
s.close()
PY
```

The expected protocol banner begins with `RFB`.

