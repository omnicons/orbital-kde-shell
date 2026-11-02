#!/bin/sh
# Switches the Orbiter variant live: KDE's colour scheme, and Konsole's
# profile in every open session. apply-theme.sh installs this into
# ~/.local/share/orbiter; the bar's Design switcher runs it.
#   switch-variant.sh black|dark|pearl
set -e

variant="$1"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
# black -> OrbiterBlack
scheme="Orbiter$(printf %s "$variant" | cut -c1 | tr a-z A-Z)$(printf %s "$variant" | cut -c2-)"

if [ ! -f "$DATA/konsole/Orbiter-$variant.profile" ]; then
    echo "Unknown variant '$variant'." >&2
    exit 1
fi

plasma-apply-colorscheme "$scheme" >/dev/null

# Each variant is its own Konsole profile ("Orbiter Black" ...): Konsole keeps
# profiles in memory, so switching between them is live where rewriting one
# profile's file isn't.
kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile "Orbiter-$variant.profile"
for service in $(busctl --user list --no-legend 2>/dev/null | awk '{print $1}' | grep '^org\.kde\.konsole-[0-9]*$'); do
    for session in $(busctl --user tree --list "$service" 2>/dev/null | grep '^/Sessions/[0-9]*$'); do
        busctl --user call "$service" "$session" org.kde.konsole.Session setProfile s "Orbiter ${scheme#Orbiter}" >/dev/null 2>&1 || true
    done
done
