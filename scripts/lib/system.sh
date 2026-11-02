# Where this distribution keeps the boot pieces, for the boot theme scripts
# (sourced, not run). Covers Arch/CachyOS and Fedora: GRUB is grub-* with
# /boot/grub on Arch and grub2-* with /boot/grub2 on Fedora, Limine's config
# sits on the ESP wherever that's mounted (/boot on CachyOS, /boot/efi on
# Fedora), and the initramfs comes from mkinitcpio or dracut.
# Needs limine_setting from secure-boot.sh.

# Sets GRUB_DIR, GRUB_MKCONFIG and GRUB_MKFONT.
grub_tools() {
    if command -v grub2-mkconfig >/dev/null; then
        GRUB_DIR=/boot/grub2 GRUB_MKCONFIG=grub2-mkconfig GRUB_MKFONT=grub2-mkfont
    else
        GRUB_DIR=/boot/grub GRUB_MKCONFIG=grub-mkconfig GRUB_MKFONT=grub-mkfont
    fi
}

# Regenerates grub.cfg. By default Fedora's grub2-mkconfig also rewrites the
# options line of every boot entry from /etc/default/grub, which drops any
# kernel argument that's only in the entries (rhgb among them, and with it
# Plymouth). --no-grubenv-update stops that; other GRUBs don't have the option.
regenerate_grub_cfg() {
    if "$GRUB_MKCONFIG" --help 2>/dev/null | grep -q -e --no-grubenv-update; then
        "$GRUB_MKCONFIG" --no-grubenv-update -o "$GRUB_DIR/grub.cfg"
    else
        "$GRUB_MKCONFIG" -o "$GRUB_DIR/grub.cfg"
    fi
}

# Gives the login screen the monitor layout and primary display of the user
# running sudo. SDDM's KWin keeps its own layout, which starts in connector
# order. The primary display goes in the theme's config too: SDDM's own idea of
# it is whichever output Qt lists first, whatever KWin's layout says.
sync_login_monitors() {
    user_config="$(getent passwd "$SUDO_USER" | cut -d: -f6)/.config/kwinoutputconfig.json"
    sddm_home="$(getent passwd sddm | cut -d: -f6)"
    if [ -z "$SUDO_USER" ] || [ -z "$sddm_home" ] || [ ! -f "$user_config" ]; then
        echo "Note: no Plasma monitor layout found to copy, so the login screen keeps its own."
        return 0
    fi
    login_config="$sddm_home/.config/kwinoutputconfig.json"
    if [ -f "$login_config" ] && [ ! -f "$login_config.orbiter-backup" ]; then
        cp -p "$login_config" "$login_config.orbiter-backup"
    fi
    install -d -o sddm -g sddm "$sddm_home/.config"
    install -m 644 -o sddm -g sddm "$user_config" "$login_config"
    primary_output="$(python3 src/boot/kwin_primary_output.py "$user_config" || true)"
    if [ -n "$primary_output" ]; then
        echo "primaryOutput=$primary_output" >> /usr/share/sddm/themes/orbiter/theme.conf
    fi
    echo "Login screen monitors now follow $SUDO_USER's Plasma layout (primary: ${primary_output:-unknown}); run this again if you change them."
}

# Finds limine.conf in the places Limine looks, on CachyOS's configured ESP
# or the usual mount points. Sets LIMINE_CONF, and LIMINE_ESP to the mount
# point of its partition (what limine.conf calls boot():/).
find_limine() {
    for root in $(limine_setting ESP_PATH) /boot /boot/efi /efi; do
        for conf in "$root/limine.conf" "$root/limine/limine.conf" "$root/boot/limine.conf" \
                    "$root/boot/limine/limine.conf" "$root/EFI/BOOT/limine.conf" "$root/EFI/limine/limine.conf"; do
            if [ -f "$conf" ]; then
                LIMINE_CONF="$conf"
                LIMINE_ESP="$(findmnt -n -o TARGET -T "$conf" 2>/dev/null || echo "$root")"
                return 0
            fi
        done
    done
    return 1
}

# limine.conf entries can pin the initramfs by hash (path#hash). CachyOS's
# limine-mkinitcpio refreshes those after a rebuild; without it a rebuild
# would leave them stale and the entry would refuse to boot.
limine_hashes_go_stale() {
    command -v limine-mkinitcpio >/dev/null && return 1
    grep -Eqs '^[[:space:]]*(module_path|kernel_path|image_path):.*#[0-9a-fA-F]{128}' "$LIMINE_CONF"
}

# Plymouth with its script plugin, its label plugin and its theme switcher
# (all separate packages on Fedora). Our theme draws no text, but without the
# label plugin the script plugin has no console viewer and segfaults on its
# first frame, and label-freetype is the one that reaches the initramfs.
plymouth_ready() {
    command -v plymouth-set-default-theme >/dev/null || return 1
    for dir in /usr/lib/plymouth /usr/lib64/plymouth; do
        [ -f "$dir/script.so" ] && [ -f "$dir/label-freetype.so" ] && return 0
    done
    return 1
}

# The distribution's own theme, for when the previous one wasn't recorded.
default_plymouth_theme() {
    for theme in cachyos-bootanimation bgrt spinner; do
        if [ -d "/usr/share/plymouth/themes/$theme" ]; then echo "$theme"; return; fi
    done
    echo text
}

# Rebuilds the initramfs, where Plymouth's theme lives. $1: the bootloader.
rebuild_initramfs() {
    if [ "$1" = limine ] && command -v limine-mkinitcpio >/dev/null; then
        # Also refreshes the kernel and initramfs hashes in limine.conf.
        limine-mkinitcpio
        limine_reenroll_if_needed
    elif command -v mkinitcpio >/dev/null; then
        mkinitcpio -P
    elif command -v dracut >/dev/null; then
        dracut --regenerate-all --force
    else
        echo "Warning: no mkinitcpio or dracut; rebuild the initramfs yourself." >&2
    fi
}
