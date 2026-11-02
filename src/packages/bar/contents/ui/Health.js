.pragma library
.import "Format.js" as Format

// The dashboard's health check: five categories, each ok or carrying notes,
// a score out of 100, and notable episodes from the recorded history.
//
// A note is { level, text } with level "critical", "warning" or "info".
// Each costs points: critical 20, warning 10, info 2.

const PENALTY = { critical: 20, warning: 10, info: 2 }

// Stretches of at least `minMs` where series stays above `threshold`:
// [{ start, end, peak }]
function episodes(times, series, threshold, minMs) {
    const found = []
    let start = -1
    let peak = 0
    for (let i = 0; i <= series.length; ++i) {
        const above = i < series.length && series[i] > threshold
        if (above) {
            if (start < 0) {
                start = i
                peak = series[i]
            }
            peak = Math.max(peak, series[i])
        } else if (start >= 0) {
            const end = i - 1
            if (times[end] - times[start] >= minMs)
                found.push({ start: times[start], end: times[end], peak: peak })
            start = -1
        }
    }
    return found
}

function timeRange(e) {
    const from = Qt.formatTime(new Date(e.start), "HH:mm")
    const to = Qt.formatTime(new Date(e.end), "HH:mm")
    return from === to ? from : `${from}–${to}`
}

// Episodes worth listing, newest first: [{ when, text, level }]
function events(history, info) {
    const t = history.times
    const s = history.series
    const list = []
    for (const e of episodes(t, s.cpuTemp, 80, 60000))
        list.push({ at: e.start, when: timeRange(e), level: "warning",
                    text: `CPU over 80 °C for ${Format.duration((e.end - e.start) / 1000)}, up to ${Math.round(e.peak)} °C` })
    for (const e of episodes(t, s.gpuTemp, 85, 60000))
        list.push({ at: e.start, when: timeRange(e), level: "warning",
                    text: `GPU over 85 °C for ${Format.duration((e.end - e.start) / 1000)}, up to ${Math.round(e.peak)} °C` })
    for (const e of episodes(t, s.ram, 90, 60000))
        list.push({ at: e.start, when: timeRange(e), level: "warning",
                    text: `Memory over 90 % for ${Format.duration((e.end - e.start) / 1000)}` })
    for (const d of info.drives) {
        const used = d.used / d.size * 100
        if (used >= 80)
            list.push({ at: Date.now(), when: "now", level: used >= 90 ? "critical" : "warning",
                        text: `${d.target} is ${Math.round(used)} % full` })
    }
    return list.sort((a, b) => b.at - a.at)
}

function check(history, info) {
    const s = history.series
    const t = history.times
    const categories = []
    const add = (name, notes, okText) => categories.push({ name: name, notes: notes, summary: notes.length ? notes[0].text : okText })

    // Thermal
    const thermal = []
    const hot = episodes(t, s.cpuTemp, 80, 60000)
    if (history.cpuTemp >= 90)
        thermal.push({ level: "critical", text: `CPU at ${Math.round(history.cpuTemp)} °C now` })
    if (hot.length)
        thermal.push({ level: "warning", text: `CPU ran over 80 °C ${hot.length === 1 ? "once" : hot.length + " times"} since start` })
    if (episodes(t, s.gpuTemp, 85, 60000).length)
        thermal.push({ level: "warning", text: "GPU ran over 85 °C since start" })
    add("Thermal", thermal, history.cpuTemp > 0 ? `CPU ${Math.round(history.cpuTemp)} °C` : "No readings")

    // Storage
    const storage = []
    for (const d of info.drives) {
        const used = d.used / d.size * 100
        if (used >= 90)
            storage.push({ level: "critical", text: `${d.target} ${Math.round(used)} % full` })
        else if (used >= 80)
            storage.push({ level: "warning", text: `${d.target} ${Math.round(used)} % full` })
    }
    const fullest = info.drives.reduce((m, d) => Math.max(m, d.used / d.size * 100), 0)
    add("Storage", storage, info.drives.length ? `Fullest drive ${Math.round(fullest)} %` : "No drives read yet")

    // Memory
    const memory = []
    if (history.ram >= 90)
        memory.push({ level: "warning", text: `Memory ${Math.round(history.ram)} % used` })
    else if (episodes(t, s.ram, 90, 60000).length)
        memory.push({ level: "info", text: "Memory ran over 90 % since start" })
    if (history.swap >= 50)
        memory.push({ level: "warning", text: `Swap ${Math.round(history.swap)} % used` })
    add("Memory", memory, `${Math.round(history.ram)} % used`)

    // Services
    const services = info.failedUnits.map(u => ({ level: "critical", text: `${u} failed` }))
    add("Services", services, "All running")

    // Updates and restarts
    const updates = []
    if (info.rebootNeeded)
        updates.push({ level: "warning", text: "Kernel updated; restart to use it" })
    const pending = info.updates.repo + info.updates.extra
    if (info.updates.repo >= 0 && pending > 0)
        updates.push({ level: pending >= 100 ? "warning" : "info", text: `${pending} updates waiting` })
    if (info.batteryHealth >= 0 && info.batteryHealth < 80)
        updates.push({ level: "info", text: `Battery at ${Math.round(info.batteryHealth)} % of its design capacity` })
    add("Maintenance", updates, info.updates.repo < 0 ? "Updates not checked" : "Up to date")

    const notes = categories.reduce((all, c) => all.concat(c.notes), [])
    const score = Math.max(0, 100 - notes.reduce((sum, n) => sum + PENALTY[n.level], 0))
    return { score: score, categories: categories, notes: notes }
}
