#!/bin/sh
# Generates the Orbiter theme from tokens.toml, installs it for the
# current user and applies it live: KDE colours, the Plasma style, fonts,
# Konsole, fish, fastfetch and the Plasma splash.
#   ./orbiter theme [black|dark|pearl]   install and switch (default: black)
#   ./orbiter theme --revert             back to Breeze Dark and default fonts
set -e
# Everything runs from the repository root.
cd "$(dirname "$0")/.."
. scripts/lib/splash.sh

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
FASTFETCH="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"

if [ "$1" = "--revert" ]; then
    plasma-apply-colorscheme BreezeDark
    plasma-apply-desktoptheme default
    for key in font fixed smallestReadableFont toolBarFont menuFont; do
        kwriteconfig6 --file kdeglobals --group General --key "$key" --delete
    done
    kwriteconfig6 --file kwinrc --group WM --key activeFont --delete
    kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile --delete
    echo y | fish -c 'fish_config theme save "fish default"' >/dev/null
    fish -c 'set -eU pure_color_success'
    if [ -f "$FASTFETCH/config.jsonc.orbiter-backup" ]; then
        mv "$FASTFETCH/config.jsonc.orbiter-backup" "$FASTFETCH/config.jsonc"
    elif grep -qs "^// Orbiter's fastfetch" "$FASTFETCH/config.jsonc"; then
        rm "$FASTFETCH/config.jsonc"
    fi
    rm -f "$FASTFETCH/orbiter-logo.txt"
    restore_splash
    echo "Reverted to Breeze Dark, Konsole's, fish's and fastfetch's defaults, and your previous splash. Apps pick up the default fonts when restarted."
    exit 0
fi

python3 src/theme/generate.py
. build/theme/fonts.sh

variant="${1:-black}"
case " $VARIANTS " in
    *" $variant "*) ;;
    *) echo "Unknown variant '$variant'; pick one of: $VARIANTS" >&2; exit 1 ;;
esac
# black -> OrbiterBlack
scheme="Orbiter$(printf %s "$variant" | cut -c1 | tr a-z A-Z)$(printf %s "$variant" | cut -c2-)"

mkdir -p "$DATA/fonts/orbiter" "$DATA/color-schemes" "$DATA/plasma/desktoptheme" "$DATA/konsole" "$DATA/orbiter"
cp src/theme/fonts/* "$DATA/fonts/orbiter/"
fc-cache -f "$DATA/fonts/orbiter"
cp build/theme/color-schemes/*.colors "$DATA/color-schemes/"
rm -rf "$DATA/plasma/desktoptheme/orbiter"
cp -r build/theme/desktoptheme/orbiter "$DATA/plasma/desktoptheme/"
# Plasma keeps rendered SVG metadata across restarts; drop it so a changed
# style is actually reread.
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}"
rm -rf "$CACHE/plasma_theme_orbiter.kcache" "$CACHE/ksvg-elements"
# Konsole's colour schemes and a profile per variant, and the switcher that
# the bar's Design row uses (it also sets Konsole's default profile).
cp build/theme/konsole/* "$DATA/konsole/"
cp src/theme/switch-variant.sh "$DATA/orbiter/"
fish src/theme/orbiter.fish
# fastfetch, which CachyOS's fish greeting runs. Someone else's config is
# kept once as config.jsonc.orbiter-backup; --revert puts it back.
mkdir -p "$FASTFETCH"
if [ -f "$FASTFETCH/config.jsonc" ] && ! grep -qs "^// Orbiter's fastfetch" "$FASTFETCH/config.jsonc" \
   && [ ! -f "$FASTFETCH/config.jsonc.orbiter-backup" ]; then
    mv "$FASTFETCH/config.jsonc" "$FASTFETCH/config.jsonc.orbiter-backup"
fi
cp src/theme/fastfetch/config.jsonc "$FASTFETCH/config.jsonc"
cp src/theme/fastfetch/logo.txt "$FASTFETCH/orbiter-logo.txt"

# plasma-apply-colorscheme skips a scheme that is already active, even if its
# file just changed, so step through another one to force a reload.
current="$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)"
if [ "$current" = "$scheme" ]; then
    plasma-apply-colorscheme BreezeDark >/dev/null
fi
"$DATA/orbiter/switch-variant.sh" "$variant"
plasma-apply-desktoptheme orbiter
# Needs ./orbiter install; naming a splash that isn't there would break startup.
if plasma-apply-lookandfeel --list 2>/dev/null | grep -qx org.orbiter.splash; then
    use_orbiter_splash
else
    echo "Note: the Plasma splash isn't installed, so it wasn't selected; run ./orbiter install, then this again." >&2
fi

# Qt 6 font strings: family, point size, pixel size, style hint, weight, then flags.
font() { echo "$1,$2,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"; }
kwriteconfig6 --file kdeglobals --group General --key font "$(font "$UI_FONT" "$FONT_SIZE")"
kwriteconfig6 --file kdeglobals --group General --key menuFont "$(font "$UI_FONT" "$FONT_SIZE")"
kwriteconfig6 --file kdeglobals --group General --key toolBarFont "$(font "$UI_FONT" "$FONT_SIZE")"
kwriteconfig6 --file kdeglobals --group General --key smallestReadableFont "$(font "$UI_FONT" "$SMALL_SIZE")"
kwriteconfig6 --file kdeglobals --group General --key fixed "$(font "$MONO_FONT" "$FONT_SIZE")"
kwriteconfig6 --file kwinrc --group WM --key activeFont "$(font "$UI_FONT" "$FONT_SIZE")"

echo "Applied Orbiter $variant. Running apps pick up the new fonts when restarted; open Konsole windows switch too."
