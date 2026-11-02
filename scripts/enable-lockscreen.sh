#!/bin/sh
# Makes the real lock screen use Orbiter (`./orbiter lockscreen`). Run once
# after `./orbiter install`, then log out and back in.
#
# kscreenlocker only loads lock screens from a shell package: the one named in
# PLASMA_DEFAULT_SHELL, which it inherits from KWin. Set it for KWin alone;
# plasmashell reads the same variable and must keep its own shell.
set -e
dropin="$HOME/.config/systemd/user/plasma-kwin_wayland.service.d"
mkdir -p "$dropin"
cat > "$dropin/orbiter-lockscreen.conf" <<EOF
[Service]
Environment=PLASMA_DEFAULT_SHELL=org.orbiter.lockscreen
EOF
systemctl --user daemon-reload
