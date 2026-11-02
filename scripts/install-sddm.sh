#!/bin/sh
# Installs the Orbiter SDDM theme and selects it, with KWin as the login
# screen's Wayland compositor (KDE's recommended setup). Run by
# `sudo ./orbiter login`, after `./orbiter install`. It doesn't switch display
# managers; it prints the commands for that.
set -e
# Everything runs from the repository root.
cd "$(dirname "$0")/.."

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this with sudo." >&2
    exit 1
fi
if [ ! -f build/sddm/Main.qml ]; then
    echo "build/sddm is missing; run ./orbiter install first (without sudo)." >&2
    exit 1
fi

rm -rf /usr/share/sddm/themes/orbiter
cp -r build/sddm /usr/share/sddm/themes/orbiter

mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/orbiter.conf <<EOF
[Theme]
Current=orbiter

[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1
EOF

echo "Theme installed. To switch from Plasma Login Manager to SDDM (takes effect at the next boot):"
echo "  sudo systemctl disable plasmalogin.service"
echo "  sudo systemctl enable sddm.service"
echo "To go back: disable sddm.service and enable plasmalogin.service the same way."
