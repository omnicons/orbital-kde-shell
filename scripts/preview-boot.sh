#!/bin/sh
# Plays the Orbiter Plymouth theme in a window, the real theme through
# Plymouth's own renderer, without touching the boot setup: it copies the
# theme into Plymouth's theme folder but doesn't select it or rebuild the
# initramfs. Feeds it this machine's running services as fake status updates.
# Run by, after `./orbiter install`:
#   sudo --preserve-env=DISPLAY,XAUTHORITY ./orbiter preview-boot [boot|shutdown]
set -e
# Everything runs from the repository root.
cd "$(dirname "$0")/.."

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this with sudo --preserve-env=DISPLAY,XAUTHORITY." >&2
    exit 1
fi
if [ ! -f build/boot/plymouth/orbiter.script ]; then
    echo "build/boot is missing; run ./orbiter install first (without sudo)." >&2
    exit 1
fi
mode="${1:-boot}"

# Plymouth draws into an X11 window here (XWayland on Plasma). Without a
# display it would fall back to drawing on the screen itself, so refuse.
if [ -z "$DISPLAY" ]; then
    echo "No DISPLAY; run with sudo --preserve-env=DISPLAY,XAUTHORITY." >&2
    exit 1
fi
if [ ! -f /usr/lib/plymouth/renderers/x11.so ] && [ ! -f /usr/lib64/plymouth/renderers/x11.so ]; then
    echo "Plymouth's X11 renderer (renderers/x11.so) isn't installed, and without it the" >&2
    echo "preview would draw on the screen itself. Fedora doesn't ship it; for a close" >&2
    echo "approximation in a window, run: qml-qt6 dev/boot-animation.qml" >&2
    echo "(qml-qt6 comes with qt6-qtdeclarative-devel; it's qml6 on Arch)." >&2
    exit 1
fi
if [ -z "$XAUTHORITY" ] && [ -n "$SUDO_UID" ]; then
    XAUTHORITY="$(ls /run/user/"$SUDO_UID"/xauth_* 2>/dev/null | head -n 1)"
    export XAUTHORITY
fi

rm -rf /usr/share/plymouth/themes/orbiter
cp -r build/boot/plymouth /usr/share/plymouth/themes/orbiter

cleanup() {
    plymouth quit 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# A private plymouthd: the theme named on a fake kernel command line, udev
# ignored so it never reaches for the GPU, no real terminal.
plymouthd --mode="$mode" --tty=/dev/null --no-boot-log \
    --debug --debug-file=/tmp/orbiter-plymouth-preview.log \
    --kernel-command-line="splash plymouth.theme=orbiter plymouth.ignore-udev"
plymouth show-splash
echo "Playing; the log is in /tmp/orbiter-plymouth-preview.log."

sleep 1.5
plymouth update-root-fs --new-root-dir=/
sleep 1.5
for unit in $(systemctl list-units --type=service --state=active --no-legend --plain | awk '{print $1}' | head -n 30); do
    plymouth update --status="$unit"
    sleep 0.2
done
sleep 4
