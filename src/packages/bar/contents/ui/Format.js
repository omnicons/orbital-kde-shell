.pragma library

// Number formatting shared by the bar and the dashboard. Decimal units, one
// decimal place below ten: "4.7 MB/s", "16.8 GB", "63 GB".

function number(value) {
    return value < 10 ? value.toFixed(1) : Math.round(value).toString()
}

function bytes(value) {
    const units = ["B", "KB", "MB", "GB", "TB"]
    let i = 0
    while (value >= 1000 && i < units.length - 1) {
        value /= 1000
        ++i
    }
    return i === 0 ? `${Math.round(value)} B` : `${number(value)} ${units[i]}`
}

function rate(value) {
    return bytes(value) + "/s"
}

function percent(value) {
    return `${Math.round(value)} %`
}

function duration(seconds) {
    const minutes = Math.floor(seconds / 60)
    const hours = Math.floor(minutes / 60)
    const days = Math.floor(hours / 24)
    if (days > 0)
        return `${days} d ${hours % 24} h`
    if (hours > 0)
        return `${hours} h ${minutes % 60} min`
    return `${minutes} min`
}
