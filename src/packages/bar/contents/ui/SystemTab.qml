import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.bluezqt as BluezQt
import org.kde.plasma.private.sessions as Sessions
import "Format.js" as Format

// Boot timing, maintenance (updates, restarts, services), connections, and
// power: the profile and suspend / restart / shut down.
ColumnLayout {
    id: root

    required property var info
    required property var history

    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color mutedColor: Kirigami.Theme.disabledTextColor
    readonly property color dimColor: Qt.alpha(Kirigami.Theme.textColor, 0.35)
    readonly property color lineColor: Qt.alpha(Kirigami.Theme.textColor, 0.10)

    spacing: 16

    Tokens { id: tokens }
    Sessions.SessionManagement { id: session }

    component Heading: Text {
        color: Kirigami.Theme.linkColor
        font.family: tokens.displayFont
        font.pixelSize: 14
        font.letterSpacing: 1
    }

    // label   value   [ACTION]
    component Fact: RowLayout {
        id: fact
        property string label
        property string value
        property color valueColor: root.textColor
        default property alias action: actionSlot.data
        Layout.fillWidth: true
        spacing: 10
        Text {
            Layout.preferredWidth: 96
            text: fact.label
            color: root.mutedColor
            font.family: tokens.uiFont
            font.pixelSize: 11
        }
        // Shrinks and elides rather than widening the column.
        Text {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.minimumWidth: 0
            text: fact.value
            elide: Text.ElideRight
            color: fact.valueColor
            font.family: tokens.uiFont
            font.pixelSize: 11
        }
        Row { id: actionSlot }
    }

    readonly property var stageNames: ({ firmware: i18n("Firmware"), loader: i18n("Loader"), kernel: i18n("Kernel"),
                                         initrd: i18n("Initrd"), userspace: i18n("Userspace") })
    readonly property var profileNames: ({ performance: i18n("Performance"), balanced: i18n("Balanced"),
                                           "power-saver": i18n("Power saver") })

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 28
        rowSpacing: 18

        // START
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignTop
            spacing: 6
            Heading { text: i18n("Start").toUpperCase() }
            Row {
                spacing: 8
                Text {
                    id: bootTotal
                    text: root.info.boot ? root.info.boot.total.toFixed(1) + " s" : "…"
                    color: root.textColor
                    font.family: tokens.dotFont
                    font.weight: tokens.dotWeight
                    font.pixelSize: 22
                }
                Text {
                    anchors.baseline: bootTotal.baseline
                    text: i18n("Boot time")
                    color: root.mutedColor
                    font.family: tokens.uiFont
                    font.pixelSize: 10
                }
            }
            // Each stage's share of the boot, brightest first.
            Row {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: root.info.boot ? root.info.boot.stages : []
                    Rectangle {
                        required property var modelData
                        required property int index
                        width: Math.max(2, (parent.width - 8) * modelData.seconds / Math.max(root.info.boot.total, 0.001))
                        height: 6
                        color: Qt.alpha(root.textColor, [0.9, 0.6, 0.45, 0.32, 0.22][index % 5])
                    }
                }
            }
            Repeater {
                model: root.info.boot ? root.info.boot.stages : []
                RowLayout {
                    required property var modelData
                    required property int index
                    spacing: 8
                    Rectangle {
                        Layout.preferredWidth: 7
                        Layout.preferredHeight: 7
                        color: Qt.alpha(root.textColor, [0.9, 0.6, 0.45, 0.32, 0.22][index % 5])
                    }
                    Text {
                        Layout.preferredWidth: 80
                        text: root.stageNames[modelData.name] || modelData.name
                        color: root.mutedColor
                        font.family: tokens.uiFont
                        font.pixelSize: 10
                    }
                    Text {
                        text: modelData.seconds.toFixed(1) + " s"
                        color: root.textColor
                        font.family: tokens.monoFont
                        font.pixelSize: 10
                    }
                }
            }
            Item { Layout.preferredHeight: 4 }
            Fact {
                label: i18n("Started")
                value: Qt.locale().toString(new Date(Date.now() - root.history.uptime * 1000), "ddd d MMM · HH:mm")
            }
            Fact {
                label: i18n("Up")
                value: Format.duration(root.history.uptime)
            }
            Fact {
                label: i18n("Slowest service")
                value: root.info.boot && root.info.boot.slowest
                    ? `${root.info.boot.slowest.unit} · ${root.info.boot.slowest.seconds.toFixed(1)} s` : "…"
            }
        }

        // MAINTENANCE
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignTop
            spacing: 8
            Heading { text: i18n("Maintenance").toUpperCase() }
            Fact {
                label: i18n("Updates")
                value: root.info.updates.checking ? i18n("Checking…")
                     : root.info.updates.repo < 0 ? i18n("Not checked")
                     : i18n("%1 repo · %2 %3", root.info.updates.repo, root.info.updates.extra, root.info.updates.extraLabel)
                Choice {
                    label: i18n("Check").toUpperCase()
                    bracketed: true
                    font.pixelSize: 12
                    visible: !root.info.updates.checking
                    onPicked: root.info.fetchUpdates()
                }
            }
            Fact {
                label: i18n("Restart")
                value: root.info.rebootNeeded ? i18n("Needed: the kernel was updated") : i18n("Not needed")
                valueColor: root.info.rebootNeeded ? Kirigami.Theme.focusColor : root.textColor
            }
            Fact {
                label: i18n("Services")
                value: root.info.failedUnits.length === 0 ? i18n("All running")
                     : i18n("%1 failed: %2", root.info.failedUnits.length, root.info.failedUnits.join(", "))
                valueColor: root.info.failedUnits.length ? Kirigami.Theme.negativeTextColor : root.textColor
            }
            Fact {
                visible: root.info.batteryHealth >= 0
                label: i18n("Battery health")
                value: i18n("%1 % of design capacity", Math.round(root.info.batteryHealth))
            }
        }

        // CONNECTIONS
        ColumnLayout {
            Layout.fillWidth: true
            Layout.columnSpan: 2
            spacing: 8
            Heading { text: i18n("Connections").toUpperCase() }
            Fact {
                visible: root.info.netbird.present
                label: "NetBird"
                value: root.info.netbird.connected
                    ? [root.info.netbird.ip, root.info.netbird.peers ? i18n("peers %1", root.info.netbird.peers) : ""].filter(s => s).join(" · ")
                    : i18n("Disconnected")
                valueColor: root.info.netbird.connected ? root.textColor : root.mutedColor
            }
            Fact {
                visible: root.info.tailscale.running
                label: "Tailscale"
                value: root.info.tailscale.ip || ""
            }
            Fact {
                label: "LAN"
                value: root.info.lan.ip ? `${root.info.lan.ip} · ${root.info.lan.device}` : i18n("Offline")
            }
            // Bluetooth devices that report a battery level.
            Repeater {
                model: BluezQt.Manager.connectedDevices
                Fact {
                    id: device
                    required property var modelData
                    label: modelData.name
                    value: modelData.battery ? modelData.battery.percentage + " %" : i18n("Connected")
                    Meter {
                        visible: !!device.modelData.battery
                        anchors.verticalCenter: parent.verticalCenter
                        value: device.modelData.battery ? device.modelData.battery.percentage / 100 : 0
                        fillColor: root.textColor
                        emptyColor: root.dimColor
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: root.lineColor
    }

    // Power profile on the left, session actions on the right.
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Text {
            visible: root.info.power.available.length > 0
            text: i18n("Power")
            color: root.mutedColor
            font.family: tokens.uiFont
            font.pixelSize: 11
        }
        Repeater {
            model: root.info.power.available
            Choice {
                required property string modelData
                label: (root.profileNames[modelData] || modelData).toUpperCase()
                bracketed: true
                current: root.info.power.current === modelData
                font.pixelSize: 12
                onPicked: root.info.setPowerProfile(modelData)
            }
        }
        Item { Layout.fillWidth: true }
        Choice {
            visible: session.canSuspend
            label: i18n("Suspend").toUpperCase()
            bracketed: true
            font.pixelSize: 12
            onPicked: session.suspend()
        }
        Choice {
            visible: session.canReboot
            label: i18n("Restart").toUpperCase()
            bracketed: true
            font.pixelSize: 12
            onPicked: session.requestReboot()
        }
        Choice {
            visible: session.canShutdown
            label: i18n("Shut down").toUpperCase()
            bracketed: true
            font.pixelSize: 12
            onPicked: session.requestShutdown()
        }
    }
}
