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

The same operations are available through Make. These targets install the
selected profile but do not reboot:

```bash
sudo make desktop-openbox
sudo make desktop-xfce
sudo make desktop-labwc
```

The Sway and labwc profiles include `foot` as a terminal and `wofi` as an
application launcher. In Sway, `Super+Enter` opens the terminal when using the
default configuration; run `wofi --show drun` from the terminal to browse
installed applications. The profiles also install `mpv`; use
`orangepi-play-video FILE` for Wayland playback. Use `orangepi-tycat FILE` for
Terminology previews; this wrapper forces software decoding because
Terminology does not currently render the vendor OMX decoder's zero-copy
output.

To switch among installed profiles:

```bash
sudo make desktop-list
sudo make desktop-current
sudo make desktop-switch DESKTOP_PROFILE=xfce
sudo make desktop-switch DESKTOP_PROFILE=labwc DESKTOP_REBOOT=1
```

There are also `desktop-<profile>` and `switch-<profile>` targets for every
profile listed below. Installation and switching remain separate so a session
change cannot unexpectedly reboot the board.

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

To prevent the graphical autologin session from starting, mask LightDM:

```bash
sudo make lightdm-mask
```

This also stops the current LightDM session. Restore normal graphical boot with:

```bash
sudo make lightdm-unmask
```
