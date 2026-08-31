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

The x11vnc service binds to `127.0.0.1` by default. Direct LAN listening is
available only when explicitly requested with the lower-level command:

```bash
sudo ./scripts/install-x11vnc.sh --listen-lan
```

Services should bind to localhost and be reached through SSH tunneling. Direct
LAN exposure is an opt-in exception. See [SSH tunneling](SSH-TUNNELING.md).
