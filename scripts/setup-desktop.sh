#!/usr/bin/env bash
# Purpose: Install and select one supported desktop profile through LightDM.
# Platform: Debian/Armbian board image; profile packages come from configured APT.
# Inputs: --profile, optional --user, and optional --remove; apt metadata is
#   never refreshed implicitly.
# Writes: desktop packages, project state, session files, and LightDM configuration
#   (install); profile packages and the profile session file (remove).
# Safety: only project-managed profile files are changed; remote access is separate.
#   Removal refuses to drop the active session and never removes LightDM itself.
# Repeat behavior: selecting the same profile is idempotent; switching updates state.
# Recovery: use setup-reset.sh or the desktop rollback target; packages are preserved.
# Verification: run board-status and the relevant X11 or Wayland verification target.
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"

PROFILE=
TARGET_USER=
REMOVE=no
usage() {
    cat <<'EOF'
 Usage: sudo ./setup.sh desktop --profile PROFILE [--user USER]
        sudo ./setup.sh desktop --profile PROFILE --remove

Profiles: openbox, xfce, i3, icewm, fluxbox, mate, plasma, lxqt, lxde, budgie,
          cinnamon, gnome, gnome-flashback, compiz, sway, labwc,
          enlightenment-x11, enlightenment-wayland

Installs only the selected desktop and LightDM. Sway and labwc also install
the `foot` terminal, `wofi` application launcher, and `mpv` video player.
The mate profile installs `mate-desktop-environment-core`, the plasma
profile installs `plasma-desktop` with `konsole`, the lxqt profile installs
`lxqt-core`, the lxde profile installs `lxde-core`, the budgie profile
installs `budgie-desktop`, and the cinnamon profile installs `cinnamon-core`.
The plasma profile additionally pins `kwin-x11` and the lxqt profile pins
`openbox`: these window managers are only Recommends (or absent from the
metapackage entirely), so this installer's `--no-install-recommends` would
otherwise leave WM-less sessions that cannot manage windows or log out.
All six are X11 sessions using
the tested Sunxi card0/PowerVR presentation path, but remain experimental
package/configuration support only until real-board presentation and reboot
evidence is recorded. Mate and plasma are heavier than xfce: prefer xfce or
lxqt on 1-2 GB boards and keep serial-console recovery available. The gnome
profile installs `gnome-session` with `gnome-shell`, `gnome-terminal`, and
`nautilus` as a GNOME-on-Xorg session under the same LightDM path. It
deliberately avoids the `gnome-core` metapackage (which hard-depends on
`gdm3`); mutter compositing ships inside `gnome-shell`, so no extra window
manager pin is needed. It is the heaviest profile: expect a
software-rendered Shell on this board and prefer 2 GB or more. The
gnome-flashback profile installs `gnome-session-flashback` with
`gnome-terminal` for the traditional GNOME 2-style panel desktop; its
metacity window manager and panel arrive as hard dependencies, so no pin is
needed. It is far lighter than Shell and the most usable GNOME on small
boards. The compiz profile installs the `compiz` metapackage (core, standard
plugins, GTK window decorator, and settings manager), `compiz-plugins-extra`,
and the `tint2` panel for a standalone OpenGL compositing session: cube,
wobbly windows, expo, and scale on the same X11 path. Compiz renders through
`llvmpipe` here (X11 GLX is software), so expect a retro slideshow rather
than 60 fps, and run `ccsm` first to enable at least Window Decoration,
Move, Resize, Place, and Application Switcher or the session is
non-interactive. It
 does not run apt update.
 Run `sudo apt update` explicitly first when the package cache is not current.
 No remote-access service is installed here.
 `--remove` uninstalls the profile's packages (plus orphaned dependencies)
 and drops its session file. It refuses to remove the active session —
 switch first — and never removes LightDM itself; use setup-reset.sh to drop
 the GUI entirely.
EOF
}
while (($#)); do
    case "$1" in
        --profile) PROFILE=${2:?missing profile}; shift 2 ;;
        --user) TARGET_USER=${2:?missing user}; shift 2 ;;
        --remove) REMOVE=yes; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done
require_root
TARGET_USER=$(resolve_real_user "$TARGET_USER")
id "$TARGET_USER" >/dev/null 2>&1 || die "User does not exist: $TARGET_USER"
[[ -n $PROFILE ]] || { usage >&2; exit 2; }

declare -A PACKAGES=(
    [openbox]='lightdm lightdm-gtk-greeter openbox xterm dbus-x11'
    [xfce]='lightdm lightdm-gtk-greeter xfce4 xfce4-goodies'
    [i3]='lightdm lightdm-gtk-greeter i3 xterm dbus-x11'
    [icewm]='lightdm lightdm-gtk-greeter icewm xterm dbus-x11'
    [fluxbox]='lightdm lightdm-gtk-greeter fluxbox xterm dbus-x11'
    [mate]='lightdm lightdm-gtk-greeter mate-desktop-environment-core xterm dbus-x11'
    [plasma]='lightdm lightdm-gtk-greeter plasma-desktop kwin-x11 konsole dbus-x11'
    [lxqt]='lightdm lightdm-gtk-greeter lxqt-core openbox xterm dbus-x11'
    [lxde]='lightdm lightdm-gtk-greeter lxde-core xterm dbus-x11'
    [budgie]='lightdm lightdm-gtk-greeter budgie-desktop xterm dbus-x11'
    [cinnamon]='lightdm lightdm-gtk-greeter cinnamon-core xterm dbus-x11'
    [gnome]='lightdm lightdm-gtk-greeter gnome-session gnome-shell gnome-terminal nautilus xterm dbus-x11'
    [gnome-flashback]='lightdm lightdm-gtk-greeter gnome-session-flashback gnome-terminal xterm dbus-x11'
    [compiz]='lightdm lightdm-gtk-greeter compiz compiz-plugins-extra tint2 xterm dbus-x11'
    [sway]='lightdm sway wayland-protocols xwayland foot wofi mpv'
    [labwc]='lightdm labwc wayland-protocols xwayland foot wofi mpv'
    [enlightenment-x11]='lightdm enlightenment xterm dbus-x11'
    [enlightenment-wayland]='lightdm enlightenment wayland-protocols xwayland'
)
[[ -n ${PACKAGES[$PROFILE]+yes} ]] || die "Unknown desktop profile: $PROFILE"

export DEBIAN_FRONTEND=noninteractive
read -r -a package_list <<<"${PACKAGES[$PROFILE]}"
if [[ $REMOVE == yes ]]; then
    ACTIVE=$(cat /etc/orangepi-zero3w-setup/state/desktop-profile 2>/dev/null || true)
    if [[ $ACTIVE == "$PROFILE" ]]; then
        die "Profile '$PROFILE' is the active session. Switch first (e.g. sudo orangepi-session set openbox), then remove."
    fi
    remove_list=()
    for pkg in "${package_list[@]}"; do
        case "$pkg" in
            lightdm|lightdm-gtk-greeter) continue ;;
        esac
        remove_list+=("$pkg")
    done
    apt-get remove -y "${remove_list[@]}"
    apt-get autoremove -y
    rm -f "/usr/share/xsessions/orangepi-$PROFILE.desktop" \
        "/usr/share/wayland-sessions/orangepi-$PROFILE.desktop"
    manifest_delete "desktop.$PROFILE"
    log "Removed desktop profile: $PROFILE (LightDM kept; use setup-reset.sh to drop the GUI entirely)."
    exit 0
fi
apt-get install -y --no-install-recommends "${package_list[@]}"
install -m 755 "$SCRIPT_DIR/orangepi-session" /usr/local/sbin/orangepi-session
install -d -m 755 /etc/X11/Xresources
install -m 644 "$SCRIPT_DIR/../config/90-orangepi-xterm" \
    /etc/X11/Xresources/90-orangepi-xterm

CONF=/etc/lightdm/lightdm.conf.d/50-orangepi-zero3w-setup.conf
ORIGINAL_TARGET=$(systemctl get-default 2>/dev/null || printf '%s\n' multi-user.target)
install -d -m 755 /etc/lightdm/lightdm.conf.d
if [[ -e $CONF ]] && ! grep -q 'managed by orangepi-zero3w-setup' "$CONF"; then
    BACKUP_ROOT="/var/backups/$PROJECT_NAME/$(date -u +%Y%m%dT%H%M%SZ)"
    backup_file "$CONF" "$BACKUP_ROOT"
fi
# TRYEXEC must name the real session binary: LightDM hides .desktop entries
# whose TryExec is missing, so a profile short name (e.g. xfce, plasma) that
# is not itself an executable breaks session selection and logout fallback.
case "$PROFILE" in
    openbox) SESSION=openbox; TRYEXEC=openbox ;;
    xfce) SESSION=xfce; TRYEXEC=startxfce4 ;;
    i3) SESSION=i3; TRYEXEC=i3 ;;
    icewm) SESSION=icewm; TRYEXEC=icewm ;;
    fluxbox) SESSION=fluxbox; TRYEXEC=startfluxbox ;;
    mate) SESSION=mate; TRYEXEC=mate-session ;;
    plasma) SESSION=plasma; TRYEXEC=startplasma-x11 ;;
    lxqt) SESSION=lxqt; TRYEXEC=startlxqt ;;
    lxde) SESSION=lxde; TRYEXEC=startlxde ;;
    budgie) SESSION=budgie; TRYEXEC=budgie-desktop ;;
    cinnamon) SESSION=cinnamon; TRYEXEC=cinnamon-session ;;
    gnome) SESSION=gnome; TRYEXEC=gnome-session ;;
    gnome-flashback) SESSION=gnome-flashback; TRYEXEC=gnome-session ;;
    compiz) SESSION=compiz; TRYEXEC=compiz ;;
    sway) SESSION=sway; TRYEXEC=sway ;;
    labwc) SESSION=labwc; TRYEXEC=labwc ;;
    enlightenment-x11|enlightenment-wayland) SESSION=$PROFILE; TRYEXEC=enlightenment_start ;;
esac
install -d -m 755 /usr/local/libexec/orangepi-zero3w-setup
install -m 755 "$SCRIPT_DIR/orangepi-session-launch" /usr/local/libexec/orangepi-zero3w-setup/session-launch
install -m 755 "$SCRIPT_DIR/lib.sh" /usr/local/libexec/orangepi-zero3w-setup/lib.sh
case "$PROFILE" in
    sway|labwc)
        install -m 755 "$SCRIPT_DIR/orangepi-tycat" /usr/local/bin/orangepi-tycat
        install -m 755 "$SCRIPT_DIR/orangepi-play-video" /usr/local/bin/orangepi-play-video
        ;;
esac
install_session_file() {
    local profile=$1 type=$2
    local directory
    case "$type" in
        x11) directory=/usr/share/xsessions ;;
        wayland) directory=/usr/share/wayland-sessions ;;
        *) die "Unknown session type: $type" ;;
    esac
    install -d -m 755 "$directory"
    cat >"$directory/orangepi-$profile.desktop" <<EOF
[Desktop Entry]
Name=Orange Pi $profile
Comment=Orange Pi managed $type session
Exec=/usr/local/libexec/orangepi-zero3w-setup/session-launch $profile
TryExec=$TRYEXEC
Type=Application
DesktopNames=$profile
EOF
}
case "$PROFILE" in
    openbox|xfce|i3|icewm|fluxbox|mate|plasma|lxqt|lxde|budgie|cinnamon|gnome|gnome-flashback|compiz|enlightenment-x11) install_session_file "$PROFILE" x11 ;;
    sway|labwc|enlightenment-wayland) install_session_file "$PROFILE" wayland ;;
esac
cat >"$CONF" <<EOF
# managed by orangepi-zero3w-setup
[Seat:*]
autologin-user=$TARGET_USER
autologin-user-timeout=0
user-session=orangepi-$SESSION
EOF
systemctl set-default graphical.target
systemctl enable lightdm
install -d -m 755 /etc/orangepi-zero3w-setup/state
if [[ ! -f /etc/orangepi-zero3w-setup/state/default-target ]]; then
    printf '%s\n' "$ORIGINAL_TARGET" >/etc/orangepi-zero3w-setup/state/default-target
fi
printf '%s\n' "$PROFILE" >/etc/orangepi-zero3w-setup/state/desktop-profile
manifest_record "desktop.$PROFILE" "sudo make desktop-$PROFILE"
manifest_record desktop.active "sudo make switch-$PROFILE"
log "Installed desktop profile: $PROFILE"
log "LightDM default session: $SESSION"
log "Remote access remains separate; use setup.sh remote explicitly."
