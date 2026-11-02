# Secure Boot safety checks for the boot theme scripts (sourced, not run).
#
# Theming never touches an EFI binary, but two things can still leave a
# Secure Boot machine unbootable if nothing re-signs afterwards:
#   - a Limine config whose checksum is enrolled into the signed Limine
#     binary: editing limine.conf means re-enrolling and re-signing;
#   - unified kernel images (UKIs): rebuilding the initramfs (Plymouth lives
#     there) rebuilds the signed image.
# CachyOS's tooling and sbctl's hooks re-sign both automatically when sbctl
# manages the keys, so that's what these checks require (or, for UKIs, ukify
# or dracut set up to sign them itself). GRUB set to enforce GPG signatures
# would reject an unsigned theme and grub.cfg, so the GRUB menu is skipped
# there.
#
# The common Fedora setup (shim, Fedora-signed GRUB and kernel, an ordinary
# initramfs) needs no re-signing: the firmware and shim check the kernel,
# never the initramfs, grub.cfg or theme files.
#
# ORBITER_SECURE_BOOT_OVERRIDE=1 skips the refusals, for setups that sign
# some other way (you then re-sign before rebooting).

LIMINE_CONFIGS="/etc/limine-entry-tool.conf /etc/limine-entry-tool.d/*.conf /etc/default/limine"

# The last uncommented KEY=value across Limine's config files, which are read
# in that order (later ones win). Grepped, not sourced: they use bash arrays.
limine_setting() {
    # shellcheck disable=SC2086
    grep -hs "^$1=" $LIMINE_CONFIGS | tail -n 1 | cut -d= -f2- | tr -d "\"'"
}

secure_boot_on() {
    # 4 bytes of attributes, then the value.
    value="$(od -An -t u1 -j 4 -N 1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c 2>/dev/null | tr -d ' ')"
    [ "$value" = 1 ]
}

# sbctl installed and holding enrolled keys: it signs on every rebuild.
sbctl_ready() {
    command -v sbctl >/dev/null 2>&1 || return 1
    sbctl setup --print-state --json 2>/dev/null | grep -q '"installed": *true' && return 0
    sbctl status --json 2>/dev/null | grep -q '"installed": *true'
}

# Locally built UKIs, which a rebuild replaces: CachyOS's Limine tooling,
# mkinitcpio presets, kernel-install's uki layout (Fedora's way), or dracut's
# uefi mode. Fedora's prebuilt, Fedora-signed kernel-uki-virt isn't rebuilt,
# so it doesn't count.
uses_uki() {
    [ "$(limine_setting ENABLE_UKI)" = yes ] && return 0
    grep -qs '^[^#]*_uki=' /etc/mkinitcpio.d/*.preset && return 0
    grep -qs '^[[:space:]]*layout=uki' /etc/kernel/install.conf && return 0
    grep -Eqs '^[[:space:]]*uefi="?yes' /etc/dracut.conf /etc/dracut.conf.d/*.conf && return 0
    return 1
}

# ukify (kernel-install) or dracut configured with a Secure Boot key signs
# each UKI it builds.
uki_signs_itself() {
    grep -qs '^[[:space:]]*SecureBootPrivateKey' /etc/kernel/uki.conf && return 0
    grep -qs '^[[:space:]]*uefi_secureboot_key' /etc/dracut.conf /etc/dracut.conf.d/*.conf
}

limine_config_enrolled() {
    [ "$(limine_setting ENABLE_ENROLL_LIMINE_CONFIG)" = yes ]
}

grub_enforces_signatures() {
    grep -rqs 'check_signatures.*enforce' /etc/default/grub /etc/grub.d /boot/grub/grub.cfg /boot/grub2/grub.cfg
}

# Prints what was found and decides. Sets SKIP_MENU=1 when only the menu must
# be skipped; returns non-zero when the whole install has to stop.
# $1: the bootloader (limine, grub or none).
secure_boot_preflight() {
    SKIP_MENU=0
    problems=""
    if secure_boot_on; then sb=on; else sb=off; fi
    if sbctl_ready; then signer=sbctl; else signer=none; fi
    if uses_uki; then uki=yes; else uki=no; fi
    enrolled=no
    [ "$1" = limine ] && limine_config_enrolled && enrolled=yes

    echo "Secure Boot: $sb; sbctl managing keys: $( [ $signer = sbctl ] && echo yes || echo no ); UKIs: $uki"
    [ "$1" = limine ] && echo "Limine config enrolled in its binary: $enrolled"

    if [ "$1" = grub ] && grub_enforces_signatures; then
        echo "GRUB enforces GPG signatures, so an unsigned theme would be rejected: skipping the GRUB menu (the boot animation still installs)."
        SKIP_MENU=1
    fi

    [ $enrolled = yes ] && ! command -v limine-enroll-config >/dev/null 2>&1 && problems="${problems}
  - limine.conf's checksum is enrolled into the Limine binary, but
    limine-enroll-config isn't here to update it after editing the config."

    if [ $sb = on ] && [ $signer = none ]; then
        [ $uki = yes ] && ! uki_signs_itself && problems="${problems}
  - The initramfs is inside signed kernel images (UKIs), and nothing here
    re-signs them after the rebuild Plymouth needs."
        [ $enrolled = yes ] && problems="${problems}
  - limine.conf's checksum is enrolled into the signed Limine binary, and
    re-enrolling needs a re-sign that only sbctl does automatically."
    fi

    if [ -n "$problems" ]; then
        echo "Stopping: with Secure Boot on, this could leave the machine unbootable:$problems"
        if [ "$ORBITER_SECURE_BOOT_OVERRIDE" = 1 ]; then
            echo "ORBITER_SECURE_BOOT_OVERRIDE=1 is set, so continuing. Re-sign before rebooting."
            return 0
        fi
        echo "Set up sbctl (sbctl create-keys, sbctl enroll-keys) or, if you sign another way,"
        echo "run with ORBITER_SECURE_BOOT_OVERRIDE=1 and re-sign before rebooting."
        return 1
    fi
    return 0
}

# Whether this boot came through the firmware's fallback path,
# \EFI\BOOT\BOOT*.EFI. Yes if that can't be told, so a real problem isn't
# written off as an unused file.
booted_from_fallback() {
    command -v efibootmgr >/dev/null 2>&1 || return 0
    boot_current="$(efibootmgr 2>/dev/null | sed -n 's/^BootCurrent: *//p')"
    [ -n "$boot_current" ] || return 0
    boot_entry="$(efibootmgr -v 2>/dev/null | grep -i "^Boot$boot_current" | tr '\\' / | tr '[:upper:]' '[:lower:]')"
    case "$boot_entry" in
        */efi/boot/boot*.efi*) return 0 ;;
        *.efi*) return 1 ;;
        *) return 0 ;;
    esac
}

# After a rebuild with Secure Boot on: ask sbctl whether every EFI image on the
# ESP is still signed, and say so loudly if not. An unsigned fallback that this
# machine doesn't boot from only gets a note: nothing here changed it, and
# signing it isn't always wise (Limine with no enrolled config treats Secure
# Boot as inactive).
secure_boot_verify() {
    secure_boot_on || return 0
    if ! sbctl_ready; then
        if [ "$ORBITER_SECURE_BOOT_OVERRIDE" = 1 ]; then
            echo "Secure Boot is on and the checks were overridden: re-sign before rebooting." >&2
        else
            echo "Secure Boot is on; nothing changed here is checked by the firmware, so nothing needs re-signing."
        fi
        return 0
    fi
    unsigned="$(sbctl verify 2>/dev/null | grep -i 'not signed' || true)"
    if ! booted_from_fallback; then
        fallback='/EFI/BOOT/BOOT[^/]*\.EFI'
        unused="$(echo "$unsigned" | grep -iE "$fallback" || true)"
        unsigned="$(echo "$unsigned" | grep -ivE "$fallback" || true)"
        if [ -n "$unused" ]; then
            echo "Note: the firmware's fallback loader isn't signed, but this machine doesn't boot from it:"
            echo "$unused"
        fi
    fi
    if [ -n "$unsigned" ]; then
        echo "Warning: Secure Boot is on and these files are not signed:" >&2
        echo "$unsigned" >&2
        echo "Do not reboot yet: sign each with 'sudo sbctl sign -s <file>', then run 'sudo sbctl verify'." >&2
        return 1
    fi
    echo "sbctl verify: everything this machine boots from is signed."
}

# Call before editing an enrolled limine.conf. Limine panics at boot if the
# config doesn't match the enrolled checksum, so from here on any failure or
# interruption re-enrolls whatever the config has become before exiting.
limine_guard_enrollment() {
    limine_config_enrolled || return 0
    trap 'limine_repair_enrollment $?' EXIT
    trap 'exit 130' INT
    trap 'exit 143' HUP TERM
}

# $1: the status the script is exiting with.
limine_repair_enrollment() {
    trap - EXIT
    [ "$1" = 0 ] && return 0
    echo "Stopped partway; re-enrolling limine.conf so the machine can still boot." >&2
    if command -v limine-enroll-config >/dev/null 2>&1 && limine-enroll-config; then
        echo "limine.conf is re-enrolled and signed. If the initramfs rebuild didn't finish," >&2
        echo "run 'sudo limine-update' before rebooting, or its hashes may be out of date." >&2
    else
        echo "DO NOT REBOOT: limine.conf no longer matches the enrolled checksum, and Limine" >&2
        echo "will panic at boot. Run 'sudo limine-enroll-config' and make sure it succeeds." >&2
    fi
    exit "$1"
}

# Limine with an enrolled config: re-enroll and re-sign after editing it.
# limine-mkinitcpio usually does this through CachyOS's post hook; running it
# again is harmless (preflight has made sure sbctl signs).
limine_reenroll_if_needed() {
    if limine_config_enrolled && command -v limine-enroll-config >/dev/null; then
        limine-enroll-config
    fi
}
