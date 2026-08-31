# Desktop sessions

No GUI is installed by default. Desktop installation is separate from remote
access and does not install a VNC server.

Available profiles are:

```text
openbox, xfce, i3, icewm, sway,
enlightenment-x11, enlightenment-wayland
```

Install one explicitly:

```bash
sudo ./setup.sh desktop --profile openbox
```

LightDM is the supported display manager. X11 and Wayland packages may coexist,
but only one LightDM session should be selected as the default at a time.
Enlightenment profiles are experimental until tested on the target board.
