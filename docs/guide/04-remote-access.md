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
service. The wayvnc and TigerVNC targets install their packages only; they do
not create or expose a service automatically because they require a selected
Wayland compositor or virtual desktop session configuration.

The x11vnc service binds to `127.0.0.1` by default. Direct LAN listening is
available only when explicitly requested with the lower-level command:

```bash
sudo ./scripts/install-x11vnc.sh --listen-lan
```

Services should bind to localhost and be reached through SSH tunneling. Direct
LAN exposure is an opt-in exception. When x11vnc is installed, its tunnel
command is shown in the login message. See [SSH tunneling](../remote/ssh-tunneling.md).
