# Desktop sessions

No GUI is installed by default. Desktop installation is separate from remote
access and does not install a VNC server.

Available profiles are:

```text
openbox, xfce, i3, icewm, fluxbox, sway, labwc,
enlightenment-x11, enlightenment-wayland
```

Install one explicitly:

```bash
sudo ./setup.sh desktop --profile openbox
sudo ./setup.sh desktop --profile labwc
```

Each invocation installs the requested profile and leaves previously installed
profiles available. LightDM uses explicit project session entries, so the
profiles can be switched without reinstalling them:

```bash
orangepi-session list
sudo orangepi-session set labwc
sudo orangepi-session set openbox --reboot
sudo orangepi-session rollback --reboot
```

The switch changes the default session and takes effect after reboot. Because
the supported configuration autologins the selected user, the LightDM greeter
does not normally provide an interactive session picker.

The X11 profiles use the tested Sunxi `card0`/PowerVR presentation path. `sway`
and `labwc` are direct Wayland profiles using the compositor's DRM backend;
they are package/configuration support only until real-board evidence confirms
PowerVR rendering, HDMI presentation, and recovery after reboot. Do not treat
a successful login as GPU support evidence. Enlightenment profiles remain
experimental and are not interchangeable aliases: they use separate X11 and
Wayland session entries, but still require board testing.

Do not run the linked session-manager installer on this Debian image. It targets
Ubuntu 22.04 and runs its own `apt update`; use this repository's commands so
the existing apt cache and delayed GPU module ordering are preserved.
