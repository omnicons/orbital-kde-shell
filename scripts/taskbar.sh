#!/bin/sh
# What happens to the panels other than the Orbiter bar (`./orbiter taskbar`):
#   keep     set them to Opaque, so they draw Orbiter's panel background
#            instead of turning transparent with the top bar (the default;
#            `./orbiter install` does this)
#   remove   delete them, as in the original rice; add one back with the
#            desktop's right-click menu, Add Panel
# Either way the bar's own panel stays Translucent: its pills are the
# background.
set -e

case "${1:-keep}" in
    keep)   others='panel.opacity = "opaque"' ;;
    remove) others='panel.remove()' ;;
    *) echo "Usage: ./orbiter taskbar [keep|remove]" >&2; exit 1 ;;
esac

busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s "
    for (const panel of panels()) {
        if (panel.widgets('org.orbiter.bar').length > 0)
            panel.opacity = 'translucent'
        else
            $others
    }
" >/dev/null
