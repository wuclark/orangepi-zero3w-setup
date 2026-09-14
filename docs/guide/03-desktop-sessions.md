# Desktop sessions

No GUI is installed by default. Desktop installation is separate from remote
access and does not install a VNC server.

Available profiles are:

```text
openbox, xfce, i3, icewm, fluxbox, mate, plasma, lxqt, lxde, budgie, cinnamon,
gnome, gnome-flashback, compiz, sway, labwc, enlightenment-x11,
enlightenment-wayland
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
sudo make desktop-gnome
sudo make desktop-gnome-flashback
sudo make desktop-compiz
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

To remove a profile entirely (packages plus its session file):

```bash
sudo make desktop-remove DESKTOP_PROFILE=compiz
```

Removal refuses to drop the active session — switch first — and never
removes LightDM itself, since other profiles may still use it. Use
`sudo ./setup.sh reset` to drop the GUI configuration entirely (packages
are preserved by design).

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
The plasma profile explicitly adds `kwin-x11`: it is only a Recommends of
`plasma-desktop`, so `--no-install-recommends` would otherwise leave a
window-manager-less session that can neither manage windows nor log out
(Debian bug #1110436 documents the same trap on minimal installs).
`lxqt` (`lxqt-core`) is a lightweight Qt-based X11 desktop and `lxde`
(`lxde-core`) a very light GTK X11 desktop on the same path; both likewise
remain experimental until the same board evidence is recorded. The lxqt
profile explicitly adds `openbox`, LXQt's default window manager, which
`lxqt-core` does not depend on. `budgie`
(`budgie-desktop`) is a heavier GNOME-stack X11 desktop on the same path and
likewise remains experimental; prefer `xfce`/`lxqt`/`lxde` on small boards.
`cinnamon` (`cinnamon-core`) is a GNOME-fork X11 desktop with compositing
demands on the same path and likewise remains experimental; like the others
it runs under LightDM with no `gdm3`.
`gnome` (`gnome-session` with `gnome-shell`, `gnome-terminal`, and
`nautilus`) is a GNOME-on-Xorg session on the same path. It deliberately
avoids the `gnome-core` metapackage, which hard-depends on `gdm3`; mutter
compositing ships inside `gnome-shell`, so no extra window manager pin is
needed. It is the heaviest profile — expect a software-rendered Shell and
prefer 2 GB or more — and likewise remains experimental until the same board
evidence is recorded. `gnome-flashback` (`gnome-session-flashback` with
`gnome-terminal`) is the traditional GNOME 2-style panel desktop on the same
path; its metacity window manager and panel arrive as hard dependencies, so
no pin is needed. It is far lighter than Shell and the most usable GNOME on
small boards, with the same experimental gate. `compiz` (the `compiz`
metapackage with `compiz-plugins-extra` and the `tint2` panel) is a
standalone OpenGL compositing session — cube, rotate, expo, scale, wobbly
windows — on the same X11 path. It renders through `llvmpipe` (X11 GLX is
software here), so expect a retro slideshow, extra heat, and higher power
draw rather than 60 fps. First launch `ccsm` and enable at least Window
Decoration, Move Window, Resize Window, Place Windows, and Application
Switcher, or the session is non-interactive; then add Cube, Rotate, Expo,
Wobbly Windows, and Animations to taste. Optional `emerald`/`emerald-themes`
packages provide skinnable window decorations (`emerald --replace`). Same
experimental gate as the other profiles.
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
