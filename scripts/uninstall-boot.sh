#!/bin/sh
# Undoes install-boot.sh for whichever bootloader it themed: takes the theme
# out of limine.conf or /etc/default/grub (restoring any settings it
# replaced), puts the previous Plymouth theme back and rebuilds. Run with sudo.
set -e
# Everything runs from the repository root.
cd "$(dirname "$0")/.."
. scripts/lib/secure-boot.sh
. scripts/lib/system.sh

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this with sudo." >&2
    exit 1
fi

STATE=/var/lib/orbiter
BOOTLOADER="$(cat "$STATE/bootloader" 2>/dev/null || echo limine)"
grub_tools

# Undoing edits limine.conf and rebuilds the initramfs too, so the same
# Secure Boot checks apply.
secure_boot_preflight "$BOOTLOADER" || exit 1
if [ "$BOOTLOADER" = limine ] && find_limine && limine_hashes_go_stale; then
    echo "Stopping: $LIMINE_CONF pins the initramfs by hash, and nothing here would" >&2
    echo "update those hashes after the rebuild. Remove the #hash suffixes first." >&2
    exit 1
fi

case "$BOOTLOADER" in
limine)
    if find_limine; then
        python3 src/boot/limine_conf.py remove "$LIMINE_CONF"
        rm -rf "$LIMINE_ESP/orbiter"
    fi
    ;;
grub)
    python3 src/boot/grub_default.py remove /etc/default/grub
    rm -rf "$GRUB_DIR/themes/orbiter"
    regenerate_grub_cfg
    ;;
esac

previous="$(cat "$STATE/previous-plymouth-theme" 2>/dev/null || default_plymouth_theme)"
plymouth-set-default-theme "$previous"
rm -rf /usr/share/plymouth/themes/orbiter

rebuild_initramfs "$BOOTLOADER"

rm -rf "$STATE"
secure_boot_verify || true
echo "Boot theme removed ($BOOTLOADER); Plymouth is back to $previous. Backups (*.orbiter-backup) are kept."
