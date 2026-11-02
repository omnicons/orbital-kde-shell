import QtQuick

// Facts about the machine that come from shell commands rather than sensors:
// boot timing, failed services, pending updates, drives, power profiles and
// network connections. The dashboard calls refresh() when it opens; updates
// are only checked on request, since that goes online.
Item {
    id: info

    // { total, stages: [{ name, seconds }], slowest: { unit, seconds } }
    property var boot: null
    property var failedUnits: []
    property bool rebootNeeded: false
    // repo and extra are -1 until checked. extra counts the second source:
    // the AUR on Arch, Flatpak elsewhere; extraLabel names it.
    property var updates: ({ repo: -1, extra: -1, extraLabel: "", checking: false, checked: null })
    // [{ source, fstype, size, used, target }], one per device.
    property var drives: []
    property var power: ({ current: "", available: [] })
    property var netbird: ({ present: false })
    property var tailscale: ({ running: false })
    property var lan: ({ ip: "", device: "" })
    property real batteryHealth: -1     // percent of design capacity

    Shell { id: shell }

    // Every match of a global regex (Qt's JS engine has no matchAll).
    function matches(text, regex) {
        const found = []
        let m
        while ((m = regex.exec(text)) !== null)
            found.push(m)
        return found
    }

    // "1min 2.5s", "839ms", "6.895s" -> seconds
    function seconds(text) {
        let total = 0
        for (const [, value, unit] of matches(text, /([\d.]+)\s*(ms|min|h|s)\b/g))
            total += parseFloat(value) * ({ ms: 0.001, s: 1, min: 60, h: 3600 })[unit]
        return total
    }

    function refresh() {
        shell.run("systemd-analyze", out => {
            // Startup finished in 5.7s (firmware) + 2.1s (loader) + ... = 18.1s
            const line = out.split("\n")[0]
            const stages = matches(line, /([\d.]+\w*(?:\s[\d.]+\w+)?)\s\((\w+)\)/g)
                .map(m => ({ name: m[2], seconds: seconds(m[1]) }))
            const total = line.includes("=") ? seconds(line.slice(line.lastIndexOf("=") + 1)) : 0
            info.boot = Object.assign({}, info.boot, { total: total, stages: stages })
        })
        shell.run("systemd-analyze blame --no-pager | head -n 1", out => {
            const parts = out.trim().split(/\s+/)
            if (parts.length >= 2)
                info.boot = Object.assign({}, info.boot,
                    { slowest: { unit: parts[parts.length - 1], seconds: seconds(parts.slice(0, -1).join(" ")) } })
        })
        shell.run("systemctl --failed --no-legend --plain; systemctl --user --failed --no-legend --plain", out => {
            info.failedUnits = out.split("\n").map(l => l.trim().split(/\s+/)[0]).filter(u => u)
        })
        // Arch removes the running kernel's modules when it updates the
        // kernel; Fedora keeps them, but dnf knows.
        shell.run("if [ ! -d /usr/lib/modules/$(uname -r) ]; then echo reboot; "
                  + "elif command -v dnf >/dev/null && dnf -q needs-restarting -r 2>/dev/null | grep -q 'Reboot is required'; then echo reboot; "
                  + "else echo ok; fi", out => {
            info.rebootNeeded = out.trim() === "reboot"
        })
        shell.run("df -B1 --output=source,fstype,size,used,target -x tmpfs -x devtmpfs -x efivarfs -x overlay -x squashfs", out => {
            // Btrfs subvolumes list the same device several times; keep the
            // shortest mount point.
            const byDevice = {}
            for (const line of out.split("\n").slice(1)) {
                const [source, fstype, size, used, ...target] = line.trim().split(/\s+/)
                if (!source || !source.startsWith("/dev/"))
                    continue
                const drive = { source, fstype, size: Number(size), used: Number(used), target: target.join(" ") }
                if (!byDevice[source] || drive.target.length < byDevice[source].target.length)
                    byDevice[source] = drive
            }
            info.drives = Object.values(byDevice).sort((a, b) => a.target.localeCompare(b.target))
        })
        // Straight from D-Bus, which power-profiles-daemon and Fedora's
        // tuned-ppd both serve (powerprofilesctl comes with only the first).
        shell.run(`busctl get-property --system --json=short ${powerObject} ActiveProfile Profiles`, out => {
            try {
                const [active, profiles] = out.trim().split("\n").map(JSON.parse)
                info.power = { current: active.data, available: profiles.data.map(p => p.Profile.data) }
            } catch (e) {
                info.power = { current: "", available: [] }
            }
        })
        shell.run("netbird status 2>/dev/null", (out, code) => {
            const field = name => ((out.match(new RegExp(`^${name}:\\s*(.+)$`, "m")) || [])[1] || "").trim()
            info.netbird = code !== 0 || !out ? { present: false } : {
                present: true,
                connected: field("Management") === "Connected",
                ip: field("NetBird IP").split("/")[0],
                peers: field("Peers count"),
            }
        })
        shell.run("tailscale status --json 2>/dev/null", out => {
            try {
                const status = JSON.parse(out)
                info.tailscale = { running: status.BackendState === "Running",
                                   ip: (status.Self && status.Self.TailscaleIPs || [])[0] || "" }
            } catch (e) {
                info.tailscale = { running: false }
            }
        })
        shell.run("ip -4 -o route get 1.1.1.1", out => {
            info.lan = { ip: (out.match(/\bsrc\s+(\S+)/) || [])[1] || "",
                         device: (out.match(/\bdev\s+(\S+)/) || [])[1] || "" }
        })
        shell.run("cd /sys/class/power_supply/BAT* 2>/dev/null && cat energy_full energy_full_design 2>/dev/null || cat charge_full charge_full_design 2>/dev/null", out => {
            const [full, design] = out.trim().split("\n").map(Number)
            info.batteryHealth = full > 0 && design > 0 ? Math.min(100, full / design * 100) : -1
        })
    }

    function fetchUpdates() {
        info.updates = Object.assign({}, info.updates, { checking: true })
        // Prints the repository count, the second source's count, and its name.
        shell.run("if command -v checkupdates >/dev/null; then "
                  + "checkupdates 2>/dev/null | wc -l; { paru -Qua 2>/dev/null || yay -Qua 2>/dev/null; } | wc -l; echo AUR; "
                  + "else dnf -q check-upgrade 2>/dev/null | awk 'NF == 3' | wc -l; "
                  + "flatpak remote-ls --updates 2>/dev/null | wc -l; echo Flatpak; fi", out => {
            const [repo, extra, label] = out.trim().split("\n")
            info.updates = { repo: Number(repo) || 0, extra: Number(extra) || 0, extraLabel: label || "",
                             checking: false, checked: new Date() }
        })
    }

    readonly property string powerObject: "net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles"

    function setPowerProfile(profile) {
        info.power = Object.assign({}, info.power, { current: profile })
        shell.run(`busctl set-property --system ${powerObject} ActiveProfile s ${profile}`, () => refresh())
    }
}
