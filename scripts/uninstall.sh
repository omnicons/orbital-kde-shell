#!/bin/sh
# Removes what `./orbiter install` set up (`./orbiter uninstall`). Pick
# another wallpaper first, or Plasma falls back to its default one.
. "$(dirname "$0")/lib/splash.sh"
rm -f "$HOME/.config/systemd/user/plasma-kwin_wayland.service.d/orbiter-lockscreen.conf"
rmdir "$HOME/.config/systemd/user/plasma-kwin_wayland.service.d" 2>/dev/null
systemctl --user daemon-reload
kpackagetool6 --type Plasma/Shell --remove org.orbiter.lockscreen
kpackagetool6 --type Plasma/Wallpaper --remove org.orbiter.wallpaper
restore_splash
kpackagetool6 --type Plasma/LookAndFeel --remove org.orbiter.splash
# The bar's panel goes with it.
busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s '
    panels().filter(p => p.widgets("org.orbiter.bar").length > 0).forEach(p => p.remove())
' >/dev/null
kpackagetool6 --type Plasma/Applet --remove org.orbiter.bar
