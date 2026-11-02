import QtQuick

// A line graph of a history series over a time window: a sparkline with axes
// off, or a full graph with gridlines, value labels on the right and times
// underneath. Long windows are reduced to one point per pixel (the peak).
Canvas {
    id: graph

    property var values: []
    property var times: []
    property int revision: 0        // bump to redraw after values change in place
    property real span: 0           // ms of history to show; 0 for everything
    property real maxValue: 0       // top of the scale; 0 scales to the data
    property real limit: -1         // draws a marked line at this value
    property bool axes: false
    property var format: v => Math.round(v)
    property color lineColor: "white"
    property color gridColor: Qt.rgba(1, 1, 1, 0.08)
    property color labelColor: "grey"
    property color limitColor: "orange"
    property string font: "IBM Plex Mono"

    readonly property int rightGutter: axes ? 52 : 0
    readonly property int bottomGutter: axes ? 16 : 0

    onRevisionChanged: requestPaint()
    onSpanChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()

    // The window's samples as [time, value], one per pixel column at most.
    function points(plotWidth) {
        const n = times.length
        if (n === 0)
            return { list: [] }
        const end = times[n - 1]
        const start = span > 0 ? end - span : times[0]
        let first = 0
        while (first < n && times[first] < start)
            ++first
        const result = []
        const step = Math.max(1, Math.floor((n - first) / plotWidth))
        for (let i = first; i < n; i += step) {
            let peak = values[i]
            for (let j = i + 1; j < Math.min(i + step, n); ++j)
                peak = Math.max(peak, values[j])
            result.push([times[i], peak])
        }
        return { start: span > 0 ? start : times[first], end: end, list: result }
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const w = width - rightGutter
        const h = height - bottomGutter
        const data = points(w)
        if (data.list.length < 2)
            return

        let top = maxValue
        if (top <= 0) {
            top = 0
            for (const p of data.list)
                top = Math.max(top, p[1])
            top = top > 0 ? top * 1.15 : 1
        }
        const duration = Math.max(1, data.end - data.start)
        const x = t => (t - data.start) / duration * w
        const y = v => h - 1 - Math.min(v, top) / top * (h - 2)

        if (axes) {
            ctx.font = `10px "${font}"`
            ctx.fillStyle = labelColor
            ctx.strokeStyle = gridColor
            ctx.lineWidth = 1
            // Small graphs only label the top and zero.
            for (const f of (h < 80 ? [0, 1] : [0, 0.5, 1])) {
                const gy = Math.round(y(top * f)) + 0.5
                ctx.beginPath()
                ctx.moveTo(0, gy)
                ctx.lineTo(w, gy)
                ctx.stroke()
                ctx.textAlign = "left"
                ctx.textBaseline = "middle"
                ctx.fillText(format(top * f), w + 6, Math.min(Math.max(gy, 6), h - 6))
            }
            // Four time labels, evenly spread.
            ctx.textBaseline = "bottom"
            for (let i = 1; i <= 4; ++i) {
                const t = data.start + duration * i / 5
                ctx.textAlign = "center"
                ctx.fillText(Qt.formatTime(new Date(t), "HH:mm"), x(t), height)
            }
        }

        if (limit >= 0 && limit <= top) {
            ctx.strokeStyle = limitColor
            ctx.globalAlpha = 0.7
            ctx.beginPath()
            ctx.moveTo(0, Math.round(y(limit)) + 0.5)
            ctx.lineTo(w, Math.round(y(limit)) + 0.5)
            ctx.stroke()
            ctx.globalAlpha = 1
        }

        ctx.beginPath()
        ctx.moveTo(x(data.list[0][0]), y(data.list[0][1]))
        for (const p of data.list)
            ctx.lineTo(x(p[0]), y(p[1]))

        // Fill under the line, fading out downwards.
        ctx.save()
        ctx.lineTo(x(data.list[data.list.length - 1][0]), h)
        ctx.lineTo(x(data.list[0][0]), h)
        ctx.closePath()
        const gradient = ctx.createLinearGradient(0, 0, 0, h)
        gradient.addColorStop(0, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.22))
        gradient.addColorStop(1, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0))
        ctx.fillStyle = gradient
        ctx.fill()
        ctx.restore()

        ctx.beginPath()
        ctx.moveTo(x(data.list[0][0]), y(data.list[0][1]))
        for (const p of data.list)
            ctx.lineTo(x(p[0]), y(p[1]))
        ctx.strokeStyle = lineColor
        ctx.lineWidth = 1.2
        ctx.lineJoin = "round"
        ctx.stroke()
    }
}
