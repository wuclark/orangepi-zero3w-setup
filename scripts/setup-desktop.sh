#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"

PROFILE=
TARGET_USER=
usage() {
    cat <<'EOF'
Usage: sudo ./setup.sh desktop --profile PROFILE [--user USER]

Profiles: openbox, xfce, i3, icewm, fluxbox, sway, labwc, enlightenment-x11,
          enlightenment-wayland

Installs only the selected desktop and LightDM. Sway and labwc also install
the `foot` terminal, `wofi` application launcher, and `mpv` video player. It
does not run apt update.
Run `sudo apt update` explicitly first when the package cache is not current.
No remote-access service is installed here.
EOF
}
while (($#)); do
    case "$1" in
        --profile) PROFILE=${2:?missing profile}; shift 2 ;;
        --user) TARGET_USER=${2:?missing user}; shift 2 ;;
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
    [sway]='lightdm sway wayland-protocols xwayland foot wofi mpv'
    [labwc]='lightdm labwc wayland-protocols xwayland foot wofi mpv'
    [enlightenment-x11]='lightdm enlightenment xterm dbus-x11'
    [enlightenment-wayland]='lightdm enlightenment wayland-protocols xwayland'
)
[[ -n ${PACKAGES[$PROFILE]+yes} ]] || die "Unknown desktop profile: $PROFILE"

export DEBIAN_FRONTEND=noninteractive
read -r -a package_list <<<"${PACKAGES[$PROFILE]}"
apt-get install -y --no-install-recommends "${package_list[@]}"
install -m 755 "$SCRIPT_DIR/orangepi-session" /usr/local/sbin/orangepi-session

CONF=/etc/lightdm/lightdm.conf.d/50-orangepi-zero3w-setup.conf
ORIGINAL_TARGET=$(systemctl get-default 2>/dev/null || printf '%s\n' multi-user.target)
install -d -m 755 /etc/lightdm/lightdm.conf.d
if [[ -e $CONF ]] && ! grep -q 'managed by orangepi-zero3w-setup' "$CONF"; then
    BACKUP_ROOT="/var/backups/$PROJECT_NAME/$(date -u +%Y%m%dT%H%M%SZ)"
    backup_file "$CONF" "$BACKUP_ROOT"
fi
case "$PROFILE" in
    openbox) SESSION=openbox ;;
    xfce) SESSION=xfce ;;
    i3) SESSION=i3 ;;
    icewm) SESSION=icewm ;;
    sway|labwc|enlightenment-x11|enlightenment-wayland) SESSION=$PROFILE ;;
esac
install -d -m 755 /usr/local/libexec/orangepi-zero3w-setup
install -m 755 "$SCRIPT_DIR/orangepi-session-launch" /usr/local/libexec/orangepi-zero3w-setup/session-launch
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
TryExec=${profile%%-*}
Type=Application
DesktopNames=$profile
EOF
}
case "$PROFILE" in
    openbox|xfce|i3|icewm|fluxbox|enlightenment-x11) install_session_file "$PROFILE" x11 ;;
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
log "Installed desktop profile: $PROFILE"
log "LightDM default session: $SESSION"
log "Remote access remains separate; use setup.sh remote explicitly."
