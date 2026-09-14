# Desktop sessions

No GUI is installed by default. Desktop installation is separate from remote
access and does not install a VNC server.

Available profiles are:

```text
openbox, xfce, i3, icewm, fluxbox, mate, plasma, lxqt, lxde, budgie, cinnamon,
sway, labwc, enlightenment-x11, enlightenment-wayland
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
sudo make desktop-mate
sudo make desktop-plasma
sudo make desktop-lxqt
sudo make desktop-lxde
sudo make desktop-budgie
sudo make desktop-cinnamon
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

The X11 profiles use the tested Sunxi `card0`/PowerVR presentation path. `mate`
(`mate-desktop-environment-core`) and `plasma` (`plasma-desktop` with
`konsole`) are heavier full desktops on that same X11 path and remain
experimental package/configuration support only until real-board evidence
confirms PowerVR rendering, HDMI presentation, and recovery after reboot;
prefer `xfce` on 1-2 GB boards and keep serial-console recovery available.
`lxqt` (`lxqt-core`) is a lightweight Qt-based X11 desktop and `lxde`
(`lxde-core`) a very light GTK X11 desktop on the same path; both likewise
remain experimental until the same board evidence is recorded. `budgie`
(`budgie-desktop`) is a heavier GNOME-stack X11 desktop on the same path and
likewise remains experimental; prefer `xfce`/`lxqt`/`lxde` on small boards.
`cinnamon` (`cinnamon-core`) is a GNOME-fork X11 desktop with compositing
demands on the same path and likewise remains experimental; like the others
it runs under LightDM with no `gdm3`.
`sway`
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
