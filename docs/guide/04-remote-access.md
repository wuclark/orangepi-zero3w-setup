# Remote access

Remote access is optional and separate from desktop installation. The available
backends are:

- `x11vnc`: mirrors an active X11 display, normally `:0`;
- `wayvnc`: serves an active Wayland compositor output;
- `tigervnc`: creates a separate virtual X11 desktop.

Install a backend explicitly:

```bash
sudo ./setup.sh remote --backend x11vnc
```

The equivalent Make targets are:

```bash
sudo make remote-x11vnc
sudo make remote-wayvnc
sudo make remote-tigervnc
```

Or choose the backend generically:

```bash
sudo make remote REMOTE_BACKEND=x11vnc
```

`REMOTE_USER=name` can be supplied for x11vnc when the target user is not the
login user. Use `sudo make remote-status` to inspect the configured x11vnc
service. The wayvnc target also creates a localhost-only configuration and a
session hook for the selected user. Switch that user to labwc or sway, then
reboot or log in again for wayvnc to start:

```bash
sudo make remote-wayvnc
sudo make desktop-switch DESKTOP_PROFILE=labwc DESKTOP_REBOOT=1
```

With the Weston target, wayvnc is currently view-only because Weston does not
provide WayVNC’s virtual-pointer protocol; use the X11 target and x11vnc for
remote input. TigerVNC remains package-only because it requires a separate virtual desktop
session configuration. All remote targets default to SSH-tunneled localhost
access and do not expose a service on the LAN.

The x11vnc service binds to `127.0.0.1` by default. Direct LAN listening is
available only when explicitly requested with the lower-level command:

```bash
sudo ./scripts/install-x11vnc.sh --listen-lan
```

Services should bind to localhost and be reached through SSH tunneling. Direct
LAN exposure is an opt-in exception. When x11vnc is installed, its tunnel
command is shown in the login message. See [SSH tunneling](../remote/ssh-tunneling.md).
