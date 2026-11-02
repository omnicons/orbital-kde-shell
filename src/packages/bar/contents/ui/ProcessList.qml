import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.process as Process
import org.kde.kitemmodels as KItemModels
import "Format.js" as Format

// The dashboard's busiest processes, with processes of the same name merged
// (every `code` helper becomes one row). Hover a row for [END]; the second
// click sends SIGTERM to all of its processes. Only runs while it's shown.
ColumnLayout {
    id: root

    property string sortBy: "cpu"
    property var rows: []
    property int total: 0
    property string armed           // the row waiting for its confirming click

    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color mutedColor: Kirigami.Theme.disabledTextColor
    readonly property color dimColor: Qt.alpha(Kirigami.Theme.textColor, 0.35)

    spacing: 4

    Tokens { id: tokens }

    Process.ProcessDataModel {
        id: processes
        enabled: true
        flatList: true
        enabledAttributes: ["name", "usage", "memory", "gpu_memory", "pid"]
    }

    Process.ProcessController { id: controller }

    function refresh() {
        const valueRole = processes.KItemModels.KRoleNames.role("Value")
        const value = (row, column) => processes.data(processes.index(row, column), valueRole)
        const byName = {}
        const count = processes.rowCount()
        for (let r = 0; r < count; ++r) {
            const name = value(r, 0)
            if (!name)
                continue
            const entry = byName[name] || (byName[name] = { name: name, cpu: 0, ram: 0, vram: 0, pids: [] })
            entry.cpu += value(r, 1) || 0
            entry.ram += (value(r, 2) || 0) * 1024     // KiB
            entry.vram += (value(r, 3) || 0) * 1024
            entry.pids.push(value(r, 4))
        }
        const list = Object.values(byName)
        list.sort((a, b) => b[sortBy] - a[sortBy])
        total = count
        rows = list.slice(0, 16)
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = ""
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        Text {
            Layout.fillWidth: true
            text: i18n("%1 processes", root.total)
            color: root.mutedColor
            font.family: tokens.uiFont
            font.pixelSize: 10
        }
        Text {
            text: i18n("Sort by")
            color: root.mutedColor
            font.family: tokens.uiFont
            font.pixelSize: 10
        }
        Repeater {
            model: [{ key: "cpu", label: "CPU" }, { key: "ram", label: "RAM" }, { key: "vram", label: "VRAM" }]
            Choice {
                required property var modelData
                label: modelData.label
                current: root.sortBy === modelData.key
                font.pixelSize: 12
                onPicked: {
                    root.sortBy = modelData.key
                    root.refresh()
                }
            }
        }
    }

    Repeater {
        model: root.rows
        Rectangle {
            id: row
            required property var modelData
            readonly property real amount: modelData[root.sortBy]
            readonly property real peak: root.rows.length ? Math.max(root.rows[0][root.sortBy], 1e-9) : 1
            readonly property bool armed: root.armed === modelData.name

            Layout.fillWidth: true
            Layout.preferredHeight: 26
            color: area.containsMouse ? Qt.alpha(root.textColor, 0.05) : "transparent"

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 260
                text: row.modelData.name
                elide: Text.ElideRight
                color: root.textColor
                font.family: tokens.uiFont
                font.pixelSize: 11
            }

            // The meter is relative to the top row, as in a bar chart.
            Meter {
                anchors.right: valueText.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                visible: !area.containsMouse && !endArea.containsMouse
                cells: 14
                value: row.amount / row.peak
                fillColor: root.textColor
                emptyColor: root.dimColor
            }

            Text {
                id: endText
                anchors.right: valueText.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                visible: area.containsMouse || endArea.containsMouse
                text: "[" + (row.armed ? i18n("Confirm") : i18n("End")).toUpperCase() + "]"
                color: row.armed ? Kirigami.Theme.negativeTextColor
                     : endArea.containsMouse ? root.textColor : root.mutedColor
                font.family: tokens.displayFont
                font.pixelSize: 12
                font.letterSpacing: 1
                MouseArea {
                    id: endArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    onClicked: {
                        if (row.armed) {
                            controller.sendSignal(row.modelData.pids, Process.ProcessController.TerminateSignal)
                            root.armed = ""
                            disarm.stop()
                        } else {
                            root.armed = row.modelData.name
                            disarm.restart()
                        }
                    }
                }
            }

            Text {
                id: valueText
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 64
                horizontalAlignment: Text.AlignRight
                text: root.sortBy === "cpu" ? row.amount.toFixed(1) + " %" : Format.bytes(row.amount)
                color: root.textColor
                font.family: tokens.monoFont
                font.pixelSize: 11
            }
        }
    }

    Text {
        Layout.topMargin: 6
        text: i18n("End sends SIGTERM; the second click confirms.")
        color: root.dimColor
        font.family: tokens.uiFont
        font.pixelSize: 10
    }
}
