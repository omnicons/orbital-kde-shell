#!/bin/sh
# Installs Orbiter's boot theme: the boot menu for Limine or GRUB, and the
# Plymouth boot animation (any bootloader). Run by `sudo ./orbiter boot`, after
# `./orbiter install`; `sudo ./orbiter uninstall-boot` undoes all of it.
#
# The bootloader is detected; set BOOTLOADER=limine|grub|none to choose.
#   Limine: limine.conf is backed up once (limine.conf.orbiter-backup) and
#     only its global section changes (see src/boot/limine_conf.py). On
#     CachyOS the initramfs is rebuilt with limine-mkinitcpio, which also
#     refreshes the hashes limine.conf keeps and re-enrolls the config.
#   GRUB (untested so far): the theme goes to themes/orbiter in /boot/grub
#     (Arch) or /boot/grub2 (Fedora), its fonts are made with grub-mkfont,
#     /etc/default/grub is backed up once and pointed at it (see
#     src/boot/grub_default.py), and grub.cfg is regenerated.
#   Anything else (systemd-boot has no theming): Plymouth only.
#
# Secure Boot: before changing anything it checks that whatever must be
# re-signed afterwards will be (see scripts/lib/secure-boot.sh), and stops if
# not; afterwards it has sbctl verify the signatures.
#   --check   report the bootloader and Secure Boot findings, change nothing
#             (works without sudo)
set -e
# Everything runs from the repository root.
cd "$(dirname "$0")/.."
. scripts/lib/secure-boot.sh
. scripts/lib/system.sh

check_only=0
[ "$1" = --check ] && check_only=1

if [ $check_only = 0 ] && [ "$(id -u)" -ne 0 ]; then
    echo "Run this with sudo (or with --check to only look)." >&2
    exit 1
fi
if [ $check_only = 0 ] && [ ! -f build/boot/plymouth/orbiter.script ]; then
    echo "build/boot is missing; run ./orbiter install first (without sudo)." >&2
    exit 1
fi

STATE=/var/lib/orbiter
grub_tools

if [ -z "$BOOTLOADER" ]; then
    # Without root the ESP may be unreadable; Limine's tools give it away then.
    if find_limine || { [ $check_only = 1 ] && command -v limine-update >/dev/null; }; then
        BOOTLOADER=limine
    elif [ -f /etc/default/grub ] && { [ -f "$GRUB_DIR/grub.cfg" ] || command -v "$GRUB_MKCONFIG" >/dev/null; }; then
        BOOTLOADER=grub
    else
        BOOTLOADER=none
    fi
elif [ "$BOOTLOADER" = limine ] && ! find_limine && [ $check_only = 0 ]; then
    echo "BOOTLOADER=limine, but no limine.conf was found." >&2
    exit 1
fi
echo "Bootloader: $BOOTLOADER"

# --- Checks, before anything changes ---------------------------------------------
secure_boot_preflight "$BOOTLOADER" || exit 1
if [ "$SKIP_MENU" = 1 ]; then
    BOOTLOADER=none
fi

missing=""
plymouth_ready || missing="${missing}
  - Plymouth with its script plugin: plymouth (Arch), or plymouth-scripts
    and plymouth-plugin-script (Fedora)"
if [ "$BOOTLOADER" = grub ] && ! command -v "$GRUB_MKFONT" >/dev/null; then
    missing="${missing}
  - $GRUB_MKFONT, for the menu's fonts: grub2-tools-extra (Fedora)"
fi
if [ -n "$missing" ]; then
    echo "Missing:$missing" >&2
    [ $check_only = 1 ] || exit 1
fi
if [ "$BOOTLOADER" = limine ] && [ -n "$LIMINE_CONF" ] && limine_hashes_go_stale; then
    echo "Stopping: $LIMINE_CONF pins the initramfs by hash, and nothing here would" >&2
    echo "update those hashes after rebuilding it for the boot animation. Remove the" >&2
    echo "#hash suffixes from the entries, or update them yourself, then run this again." >&2
    exit 1
fi

if [ $check_only = 1 ]; then
    echo "Check only: nothing changed. The boot menu would be themed for '$BOOTLOADER', plus the boot animation."
    exit 0
fi

mkdir -p "$STATE"
echo "$BOOTLOADER" > "$STATE/bootloader"

# --- Boot menu ------------------------------------------------------------------
case "$BOOTLOADER" in
limine)
    CONF="$LIMINE_CONF"
    [ -f "$CONF.orbiter-backup" ] || cp -p "$CONF" "$CONF.orbiter-backup"
    mkdir -p "$LIMINE_ESP/orbiter"
    cp build/boot/limine/wallpaper.png "$LIMINE_ESP/orbiter/limine-wallpaper.png"
    python3 src/boot/limine_conf.py apply "$CONF" build/boot/limine/theme.conf
    echo "limine.conf themed (backup: $CONF.orbiter-backup)."
    ;;
grub)
    THEME="$GRUB_DIR/themes/orbiter"
    rm -rf "$THEME"
    mkdir -p "$GRUB_DIR/themes"
    cp -r build/boot/grub/orbiter "$THEME"
    # GRUB's own font format, from the bundled display font and IBM Plex Mono
    # (or whatever monospace font is installed if Plex isn't).
    display_ttf="src/theme/fonts/ShareTechMono-Regular.ttf"
    mono_ttf="$(fc-match -f '%{file}' 'IBM Plex Mono:style=Regular')"
    while read -r file role size; do
        case "$role" in
            mono) "$GRUB_MKFONT" -n "Orbiter Mono" -s "$size" -o "$THEME/$file" "$mono_ttf" ;;
            display) "$GRUB_MKFONT" -n "Orbiter Display" -s "$size" -o "$THEME/$file" "$display_ttf" ;;
        esac
    done < build/boot/grub/fonts.list
    [ -f /etc/default/grub.orbiter-backup ] || cp -p /etc/default/grub /etc/default/grub.orbiter-backup
    python3 src/boot/grub_default.py apply /etc/default/grub "$THEME/theme.txt"
    "$GRUB_MKCONFIG" -o "$GRUB_DIR/grub.cfg"
    echo "GRUB themed (backup: /etc/default/grub.orbiter-backup)."
    # Fedora hides the menu unless the last boot failed.
    if command -v grub2-editenv >/dev/null && grub2-editenv list 2>/dev/null | grep -q '^menu_auto_hide=1'; then
        echo "Note: GRUB hides its menu on this machine; hold Shift (or press Esc) at boot to see it," >&2
        echo "or show it every time with: sudo grub2-editenv - unset menu_auto_hide" >&2
    fi
    ;;
*)
    echo "No themable boot menu found; installing the boot animation only."
    ;;
esac

# --- Plymouth -------------------------------------------------------------------
current="$(plymouth-set-default-theme)"
if [ "$current" != orbiter ]; then
    echo "$current" > "$STATE/previous-plymouth-theme"
fi
rm -rf /usr/share/plymouth/themes/orbiter
cp -r build/boot/plymouth /usr/share/plymouth/themes/orbiter
plymouth-set-default-theme orbiter

rebuild_initramfs "$BOOTLOADER"

if [ "$BOOTLOADER" = limine ] && ! grep -q '^# >>> orbiter theme' "$LIMINE_CONF"; then
    echo "Warning: the theme lines are missing from limine.conf after the rebuild." >&2
    echo "Run this script again, or restore $LIMINE_CONF.orbiter-backup." >&2
    exit 1
fi

# Plymouth only shows if it's in the initramfs and asked for on the kernel
# command line; say so rather than editing either. dracut (Fedora) adds it
# whenever it's installed, and Fedora asks with rhgb rather than splash.
if ! grep -qs 'plymouth' /etc/mkinitcpio.conf /etc/mkinitcpio.conf.d/*.conf 2>/dev/null \
   && ! command -v dracut >/dev/null; then
    echo "Note: plymouth isn't in mkinitcpio's HOOKS, so the boot animation won't show." >&2
fi
if ! grep -qwE 'splash|rhgb' /proc/cmdline; then
    echo "Note: neither 'splash' nor 'rhgb' is on the kernel command line, so the boot animation won't show." >&2
fi
secure_boot_verify || exit 1
echo "Done. The new boot menu and animation show at the next boot."
