import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support
import "Format.js" as Format
import "Health.js" as Health

// The load pill's popup, named after the machine: an overview of CPU, GPU,
// memory and network with history graphs, the busiest processes, drives, a
// health check, and system facts and controls.
ColumnLayout {
    id: root

    required property var history
    property bool shown: false          // the popup is open
    property int tab: 0
    property string selected: "cpu"
    property real span: 15 * 60 * 1000
    property string machine

    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color mutedColor: Kirigami.Theme.disabledTextColor
    readonly property color dimColor: Qt.alpha(Kirigami.Theme.textColor, 0.35)
    readonly property color lineColor: Qt.alpha(Kirigami.Theme.textColor, 0.10)
    readonly property color accentColor: Kirigami.Theme.focusColor

    width: 640
    spacing: 12

    Tokens { id: tokens }

    // Held in a property so the layout doesn't place it.
    readonly property SystemInfo info: SystemInfo {}

    readonly property var health: {
        history.revision
        info.drives; info.failedUnits; info.updates; info.rebootNeeded; info.batteryHealth
        return Health.check(history, info)
    }
    readonly property var events: {
        history.revision
        info.drives; info.failedUnits; info.updates; info.rebootNeeded; info.batteryHealth
        return Health.events(history, info)
    }

    // Fresh facts on every open, and every minute while open. Updates are
    // checked on the first open only; the System tab can check again.
    onShownChanged: {
        if (!shown)
            return
        info.refresh()
        if (info.updates.repo < 0 && !info.updates.checking)
            info.fetchUpdates()
    }
    Timer {
        interval: 60000
        running: root.shown
        repeat: true
        onTriggered: root.info.refresh()
    }

    // Vendor and model, read once.
    P5Support.DataSource {
        engine: "executable"
        connectedSources: ["cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name"]
        onNewData: (source, data) => {
            // Long legal names ("Micro-Star International Co., Ltd.") give way
            // to the model alone.
            const [vendor, model] = data.stdout.trim().split("\n")
            root.machine = vendor && vendor.length <= 16 ? `${vendor} ${model}` : (model || vendor || "")
            disconnectSource(source)
        }
    }

    // What each card shows, and the graphs under the big one when it's selected.
    readonly property var metrics: ({
        cpu: { title: i18n("CPU · Usage"), device: "", series: "cpu", max: 100, format: Format.percent,
               extra: [{ title: i18n("Frequency"), series: "cpuFreq", max: 0, format: v => (v / 1000).toFixed(1) + " GHz" },
                       { title: i18n("Temperature"), series: "cpuTemp", max: 100, limit: 80, format: v => Math.round(v) + " °C" }] },
        gpu: { title: i18n("GPU · Usage"), device: history.gpuName, series: "gpu", max: 100, format: Format.percent,
               extra: [{ title: i18n("VRAM"), series: "vram", max: history.vramTotal, format: Format.bytes },
                       { title: i18n("Temperature"), series: "gpuTemp", max: 100, limit: 80, format: v => Math.round(v) + " °C" }] },
        ram: { title: i18n("Memory · Used"), device: Format.bytes(history.ramTotal), series: "ram", max: 100, format: Format.percent,
               extra: [{ title: i18n("Swap"), series: "swap", max: 100, format: Format.percent }] },
        net: { title: i18n("Network · Download"), device: "", series: "netDown", max: 0, format: Format.rate,
               extra: [{ title: i18n("Upload"), series: "netUp", max: 0, format: Format.rate }] },
    })
    readonly property var metric: metrics[selected]
    readonly property var latest: {
        history.revision
        const out = {}
        for (const key in history.series) {
            const s = history.series[key]
            out[key] = s.length ? s[s.length - 1] : 0
        }
        return out
    }

    // Header: TERMINAL001 and the machine; health and uptime on the right.
    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                text: root.history.hostname.toUpperCase()
                color: Kirigami.Theme.linkColor
                font.family: tokens.dotFont
                font.weight: tokens.dotWeight
                font.pixelSize: 24
                font.letterSpacing: 1
            }
            Text {
                Layout.fillWidth: true
                text: [root.machine, root.history.os, root.history.kernel].filter(s => s).join(" · ")
                elide: Text.ElideRight
                color: root.mutedColor
                font.family: tokens.uiFont
                font.pixelSize: 10
            }
        }
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            spacing: 2
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 6
                Row {
                    spacing: 2
                    Repeater {
                        model: root.health.categories
                        StatusMark {
                            required property var modelData
                            level: modelData.notes.length === 0 ? ""
                                 : modelData.notes.some(n => n.level === "critical") ? "critical"
                                 : modelData.notes.some(n => n.level === "warning") ? "warning" : "info"
                        }
                    }
                }
                Text {
                    text: i18n("Health %1 · %2", root.health.score,
                               root.health.notes.length === 1 ? i18n("1 note") : i18n("%1 notes", root.health.notes.length))
                    color: root.textColor
                    font.family: tokens.uiFont
                    font.pixelSize: 11
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.tab = 3
                    }
                }
            }
            Text {
                Layout.alignment: Qt.AlignRight
                text: [i18n("Up %1", Format.duration(root.history.uptime)),
                       root.info.boot ? i18n("Boot %1 s", root.info.boot.total.toFixed(1)) : ""].filter(s => s).join(" · ")
                color: root.mutedColor
                font.family: tokens.uiFont
                font.pixelSize: 10
            }
        }
    }

    // Tabs.
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        Row {
            spacing: 28
            Repeater {
                model: [i18n("Overview"), i18n("Processes"), i18n("Drives"), i18n("Health"), i18n("System")]
                Choice {
                    required property string modelData
                    required property int index
                    label: modelData.toUpperCase()
                    current: root.tab === index
                    onPicked: root.tab = index
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: root.lineColor
        }
    }

    // --- Overview ---

    RowLayout {
        Layout.fillWidth: true
        visible: root.tab === 0
        spacing: 8
        StatCard {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: "CPU"
            corner: root.history.cpuTemp > 0 ? Math.round(root.history.cpuTemp) + " °C" : ""
            value: Format.percent(root.history.cpu)
            detail: (root.history.cpuFreq / 1000).toFixed(1) + " GHz"
            history: root.history
            series: "cpu"
            maxValue: 100
            selected: root.selected === "cpu"
            onClicked: root.selected = "cpu"
        }
        StatCard {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: "GPU"
            corner: root.history.gpuTemp > 0 ? Math.round(root.history.gpuTemp) + " °C" : ""
            value: Format.percent(root.history.gpu)
            // Integrated GPUs share system memory and report no VRAM.
            detail: root.history.vramTotal > 0
                ? i18n("VRAM %1 / %2", Format.bytes(root.history.vramUsed), Format.bytes(root.history.vramTotal))
                : root.history.gpuName
            history: root.history
            series: "gpu"
            maxValue: 100
            selected: root.selected === "gpu"
            onClicked: root.selected = "gpu"
        }
        StatCard {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: "RAM"
            value: Format.percent(root.history.ram)
            detail: i18n("%1 of %2", Format.bytes(root.history.ramUsed), Format.bytes(root.history.ramTotal))
            history: root.history
            series: "ram"
            maxValue: 100
            selected: root.selected === "ram"
            onClicked: root.selected = "ram"
        }
        StatCard {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: i18n("Net").toUpperCase()
            value: Format.rate(root.history.netDown)
            detail: "↑ " + Format.rate(root.history.netUp)
            history: root.history
            series: "netDown"
            selected: root.selected === "net"
            onClicked: root.selected = "net"
        }
    }

    // The selected metric over the chosen window.
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.tab === 0
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: root.metric.title
                color: root.textColor
                font.family: tokens.uiFont
                font.weight: Font.Medium
                font.pixelSize: 12
            }
            Text {
                Layout.fillWidth: true
                text: root.metric.device
                elide: Text.ElideRight
                color: root.mutedColor
                font.family: tokens.uiFont
                font.pixelSize: 10
            }
            Row {
                spacing: 10
                Repeater {
                    model: [
                        { label: i18n("15 min"), span: 15 * 60 * 1000 },
                        { label: i18n("1 h"), span: 3600 * 1000 },
                        { label: i18n("6 h"), span: 6 * 3600 * 1000 },
                        { label: i18n("Since start"), span: 0 },
                    ]
                    Choice {
                        required property var modelData
                        label: modelData.label.toUpperCase()
                        current: root.span === modelData.span
                        font.pixelSize: 12
                        onPicked: root.span = modelData.span
                    }
                }
            }
        }

        Graph {
            Layout.fillWidth: true
            Layout.preferredHeight: 150
            visible: root.shown
            axes: true
            values: root.history.series[root.metric.series]
            times: root.history.times
            revision: root.history.revision
            span: root.span
            maxValue: root.metric.max
            format: root.metric.format
            lineColor: root.textColor
            gridColor: root.lineColor
            labelColor: root.mutedColor
            font: tokens.monoFont
        }

        Text {
            visible: root.history.revision < 2
            text: i18n("Collecting history since %1…", Qt.formatTime(root.history.started, "HH:mm"))
            color: root.dimColor
            font.family: tokens.uiFont
            font.pixelSize: 10
        }
    }

    // Secondary graphs for the selected metric: frequency and temperature for
    // the CPU, VRAM and temperature for the GPU, and so on.
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        visible: root.tab === 0
        spacing: 16
        Repeater {
            model: root.metric.extra
            ColumnLayout {
                id: extra
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: extra.modelData.title
                        color: root.mutedColor
                        font.family: tokens.uiFont
                        font.pixelSize: 11
                    }
                    Text {
                        text: extra.modelData.format(root.latest[extra.modelData.series] || 0)
                        color: root.textColor
                        font.family: tokens.monoFont
                        font.pixelSize: 11
                    }
                }
                Graph {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    visible: root.shown
                    axes: true
                    values: root.history.series[extra.modelData.series]
                    times: root.history.times
                    revision: root.history.revision
                    span: root.span
                    maxValue: extra.modelData.max
                    limit: extra.modelData.limit === undefined ? -1 : extra.modelData.limit
                    format: extra.modelData.format
                    lineColor: root.textColor
                    gridColor: root.lineColor
                    labelColor: root.mutedColor
                    limitColor: Kirigami.Theme.negativeTextColor
                    font: tokens.monoFont
                }
            }
        }
    }

    Notable {
        Layout.fillWidth: true
        Layout.topMargin: 8
        visible: root.tab === 0
        events: root.events
        limit: 3
    }

    // --- The other tabs, loaded only while shown ---

    Loader {
        Layout.fillWidth: true
        active: root.shown && root.tab === 1
        visible: active
        sourceComponent: ProcessList {}
    }
    Loader {
        Layout.fillWidth: true
        active: root.shown && root.tab === 2
        visible: active
        sourceComponent: DrivesTab { info: root.info; history: root.history }
    }
    Loader {
        Layout.fillWidth: true
        active: root.shown && root.tab === 3
        visible: active
        sourceComponent: HealthTab { health: root.health; events: root.events }
    }
    Loader {
        Layout.fillWidth: true
        active: root.shown && root.tab === 4
        visible: active
        sourceComponent: SystemTab { info: root.info; history: root.history }
    }
}
