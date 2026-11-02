import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import org.kde.bluezqt as BluezQt

// Bluetooth devices: paired ones to connect or disconnect with a click, and
// [SCAN] to find nearby ones and pair them. Pairing prompts (PINs, codes to
// confirm) come from Plasma's own Bluetooth service, as usual.
ColumnLayout {
    id: root

    property var busy: ({})             // address -> "connecting" | "disconnecting" | "pairing"
    readonly property var adapter: BluezQt.Manager.usableAdapter
    readonly property bool scanning: adapter && adapter.discovering

    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color mutedColor: Kirigami.Theme.disabledTextColor
    readonly property color dimColor: Qt.alpha(Kirigami.Theme.textColor, 0.35)
    readonly property color lineColor: Qt.alpha(Kirigami.Theme.textColor, 0.10)

    spacing: 0

    readonly property int maxRows: 7
    // Rows step in from the right while the scrollbar shows.
    readonly property real scrollGap: bar.visible ? bar.width + 4 : 0

    Tokens { id: tokens }
    Shell { id: shell }

    BluezQt.DevicesModel { id: devices }
    KItemModels.KSortFilterProxyModel {
        id: paired
        sourceModel: devices
        filterRowCallback: (row, parent) =>
            sourceModel.data(sourceModel.index(row, 0, parent), sourceModel.KItemModels.KRoleNames.role("Paired")) === true
    }
    // Unpaired devices with a real name. Nameless ones, and the many that
    // only show their address as a name ("56-07-68-8E-7D-2D"), are noise.
    KItemModels.KSortFilterProxyModel {
        id: nearby
        sourceModel: devices
        filterRowCallback: (row, parent) => {
            const index = sourceModel.index(row, 0, parent)
            const role = name => sourceModel.data(index, sourceModel.KItemModels.KRoleNames.role(name))
            const name = String(role("Name") || "")
            return role("Paired") !== true && name.length > 0
                && !/^([0-9a-f]{2}[-:]){5}[0-9a-f]{2}$/i.test(name)
        }
    }

    // Stop looking once the list closes; scanning costs power.
    Component.onDestruction: if (scanning) adapter.stopDiscovery()

    function setBusy(address, state) {
        const next = Object.assign({}, busy)
        if (state)
            next[address] = state
        else
            delete next[address]
        busy = next
    }

    // Runs a BluezQt pending call, clearing the busy state when it ends.
    function track(address, state, call, then) {
        setBusy(address, state)
        call.finished.connect(() => {
            setBusy(address, "")
            if (!call.error && then)
                then()
        })
    }

    component DeviceRow: ColumnLayout {
        id: row
        required property var model
        readonly property string state: root.busy[model.Address] || ""
        readonly property var battery: model.Device ? model.Device.battery : null
        signal clicked()

        Layout.fillWidth: true
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            color: area.containsMouse ? Qt.alpha(root.textColor, 0.05) : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 36
                anchors.rightMargin: 4 + root.scrollGap
                spacing: 10
                Kirigami.Icon {
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 14
                    source: (row.model.Icon || "preferences-system-bluetooth") + "-symbolic"
                    fallback: "network-bluetooth-symbolic"
                    isMask: true
                    color: row.model.Connected ? Kirigami.Theme.focusColor : root.mutedColor
                }
                Text {
                    Layout.fillWidth: true
                    text: row.model.Name
                    elide: Text.ElideRight
                    color: root.textColor
                    font.family: tokens.uiFont
                    font.weight: row.model.Connected ? Font.Medium : Font.Normal
                    font.pixelSize: 12
                }
                Meter {
                    visible: !!row.battery && row.state === ""
                    cells: 4
                    value: row.battery ? row.battery.percentage / 100 : 0
                    fillColor: root.textColor
                    emptyColor: root.dimColor
                }
                Text {
                    text: row.state === "connecting" ? i18n("Connecting…")
                        : row.state === "disconnecting" ? i18n("Disconnecting…")
                        : row.state === "pairing" ? i18n("Pairing…")
                        : row.model.Connected ? (row.battery ? row.battery.percentage + "%" : i18n("Connected"))
                        : ""
                    color: row.model.Connected && row.state === "" ? Kirigami.Theme.focusColor : root.mutedColor
                    font.family: tokens.uiFont
                    font.pixelSize: 10
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                enabled: row.state === ""
                cursorShape: Qt.PointingHandCursor
                onClicked: row.clicked()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 36
            Layout.preferredHeight: 1
            color: root.lineColor
        }
    }

    // Paired and nearby devices scroll in their own area past seven rows,
    // like the Wi-Fi list, rather than stretching the whole popup.
    Flickable {
        id: deviceArea
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, root.maxRows * 35)
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        QQC2.ScrollBar.vertical: QQC2.ScrollBar {
            id: bar
            visible: deviceArea.contentHeight > deviceArea.height
        }

        ColumnLayout {
            id: column
            width: deviceArea.width
            spacing: 0

            // Paired devices.
            Repeater {
                model: paired
                DeviceRow {
                    onClicked: {
                        const device = model.Device
                        if (model.Connected)
                            root.track(model.Address, "disconnecting", device.disconnectFromDevice())
                        else
                            root.track(model.Address, "connecting", device.connectToDevice())
                    }
                }
            }

            Text {
                Layout.leftMargin: 36
                Layout.topMargin: 6
                Layout.bottomMargin: 6
                visible: paired.count === 0
                text: i18n("No paired devices yet.")
                color: root.dimColor
                font.family: tokens.uiFont
                font.pixelSize: 11
            }

            // NEARBY - - - -, while scanning.
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 36
                Layout.topMargin: 6
                visible: root.scanning || nearby.count > 0
                spacing: 8
                Text {
                    text: i18n("Nearby").toUpperCase()
                    color: root.mutedColor
                    font.family: tokens.displayFont
                    font.pixelSize: 12
                    font.letterSpacing: 1
                }
                Text {
                    Layout.fillWidth: true
                    text: "- ".repeat(40)
                    clip: true
                    color: root.dimColor
                    font.family: tokens.monoFont
                    font.pixelSize: 10
                }
            }

            // Pair, trust (so it reconnects on its own later), then connect.
            Repeater {
                model: nearby
                DeviceRow {
                    onClicked: {
                        const device = model.Device
                        const address = model.Address
                        root.track(address, "pairing", device.pair(), () => {
                            device.trusted = true
                            root.track(address, "connecting", device.connectToDevice())
                        })
                    }
                }
            }

            Text {
                Layout.leftMargin: 36
                Layout.topMargin: 4
                visible: root.scanning && nearby.count === 0
                text: i18n("Looking for devices…")
                color: root.dimColor
                font.family: tokens.uiFont
                font.pixelSize: 11
            }
        }
    }

    // [SCAN]  [SETTINGS]
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 36
        Layout.topMargin: 6
        Layout.bottomMargin: 4
        spacing: 16
        Choice {
            visible: !!root.adapter
            label: (root.scanning ? i18n("Stop") : i18n("Scan")).toUpperCase()
            bracketed: true
            current: root.scanning
            font.pixelSize: 12
            onPicked: root.scanning ? root.adapter.stopDiscovery() : root.adapter.startDiscovery()
        }
        Choice {
            label: i18n("Settings").toUpperCase()
            bracketed: true
            font.pixelSize: 12
            onPicked: shell.run("kcmshell6 kcm_bluetooth")
        }
    }
}
