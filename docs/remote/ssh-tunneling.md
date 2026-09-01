# SSH tunneling with a Windows VNC viewer

SSH tunneling forwards a local Windows port to a VNC port on the board. VNC
traffic is encrypted inside SSH, and the VNC service can listen only on the
board's localhost interface.

For x11vnc or wayvnc on board port `5900`, open Windows PowerShell and run:

```powershell
ssh -N -L 5900:127.0.0.1:5900 orangepi@BOARD_IP
```

Leave that window open. In TightVNC Viewer, connect to:

```text
localhost::5900
```

For a TigerVNC/TightVNC virtual desktop on board port `5901`:

```powershell
ssh -N -L 5901:127.0.0.1:5901 orangepi@BOARD_IP
```

Connect the viewer to `localhost::5901`. If the local port is already used,
forward a different Windows port:

```powershell
ssh -N -L 15900:127.0.0.1:5900 orangepi@BOARD_IP
```

Then connect to `localhost::15900`.

When the project configures x11vnc, the board's login message also prints a
ready-to-copy tunnel command using the current login user and detected board
address. The message is informational; it does not open a tunnel or expose
VNC on the LAN. If the address shown there is not reachable from your client,
replace it with the board's reachable IP or hostname:

```powershell
ssh -N -L 5900:127.0.0.1:5900 orangepi@BOARD_IP
```

Leave the SSH window open while the VNC viewer is connected to
`127.0.0.1:5900` (or `localhost::5900` in TightVNC Viewer).

`x11vnc` mirrors the existing X11 display. `wayvnc` serves a Wayland session.
TightVNC/TigerVNC creates a separate virtual X11 desktop and does not mirror
the HDMI session or directly serve Wayland.
