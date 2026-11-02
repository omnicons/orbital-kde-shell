import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.bluezqt as BluezQt
import org.kde.plasma.private.volume as Volume
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.workspace.dbus as DBus

// The status pill's popup: Wi-Fi, Bluetooth, volume, battery, the variant
// switcher, and the apps running in the background with a tray icon. Click
// Wi-Fi, Bluetooth or Volume to pick a network, a device or an output;
// right-click an app (or click one that only has a menu) for its menu.
ColumnLayout {
    id: root

    required property var battery
    required property var sink
    required property var trayItems     // "service/path" for each tray icon
    signal done()                       // close the popup

    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color mutedColor: Kirigami.Theme.disabledTextColor
    readonly property color dimColor: Qt.alpha(Kirigami.Theme.textColor, 0.35)
    readonly property color lineColor: Qt.alpha(Kirigami.Theme.textColor, 0.12)
    readonly property color accentColor: Kirigami.Theme.focusColor
    readonly property color cardColor: Kirigami.Theme.alternateBackgroundColor
    property string scheme
    property string open                // the expanded row: "wifi", "bluetooth", "audio" or ""
    property var trayMenu: null         // { service, path, title } while a tray menu shows

    width: 280
    spacing: 4

    Tokens { id: tokens }

    PlasmaNM.EnabledConnections { id: network }
    PlasmaNM.NetworkStatus { id: networkStatus }
    PlasmaNM.Handler { id: networkHandler }

    // Runs a command and hands its output to `callback`.
    P5Support.DataSource {
        id: shell
        engine: "executable"
        property var callbacks: ({})
        function run(command, callback) {
            callbacks[command] = callback
            connectSource(command)
        }
        onNewData: (source, data) => {
            const callback = callbacks[source]
            delete callbacks[source]
            disconnectSource(source)
            if (callback)
                callback(data.stdout)
        }
    }

    // Called when the popup opens: start collapsed.
    function reset() {
        open = ""
        trayMenu = null
    }

    function refreshScheme() {
        shell.run("kreadconfig6 --file kdeglobals --group General --key ColorScheme",
                  out => root.scheme = out.trim())
    }

    // "Wi-Fi: Connected to HYPERION\nWireGuard: ..." -> "Connected to HYPERION"
    readonly property string wifiStatus: {
        const line = networkStatus.activeConnections.split("\n")[0] || ""
        return line.includes(": ") ? line.slice(line.indexOf(": ") + 2) : line
    }

    readonly property var bluetooth: BluezQt.Manager
    readonly property bool bluetoothOn: bluetooth.bluetoothOperational && !bluetooth.bluetoothBlocked

    function setBluetooth(on) {
        bluetooth.bluetoothBlocked = !on
        for (let i = 0; i < bluetooth.adapters.length; ++i)
            bluetooth.adapters[i].powered = on
    }

    function formatDuration(msec) {
        const minutes = Math.round(msec / 60000)
        const hours = Math.floor(minutes / 60)
        return hours > 0 ? `${hours} h ${minutes % 60} min` : `${minutes} min`
    }

    component Label: Text {
        color: root.textColor
        font.family: tokens.uiFont
        font.pixelSize: 12
        elide: Text.ElideRight
    }

    // A row: icon box, title over subtitle, and a control on the right. With
    // `expands` set, clicking the icon or text opens that row's list below.
    component Setting: RowLayout {
        id: setting
        property string icon
        property string title
        property string subtitle
        property string expands
        default property alias control: controlSlot.data

        Layout.fillWidth: true
        Layout.preferredHeight: 40
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            color: "transparent"
            border.width: 1
            border.color: root.lineColor
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 14
                height: 14
                source: setting.icon
                isMask: true
                color: root.mutedColor
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                RowLayout {
                    spacing: 6
                    Label {
                        text: setting.title
                        font.weight: Font.Medium
                    }
                    Kirigami.Icon {
                        visible: setting.expands !== ""
                        Layout.preferredWidth: 10
                        Layout.preferredHeight: 10
                        source: root.open === setting.expands ? "arrow-up" : "arrow-down"
                        isMask: true
                        color: expandArea.containsMouse ? root.textColor : root.mutedColor
                    }
                }
                Label {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: setting.subtitle
                    color: root.mutedColor
                    font.pixelSize: 10
                }
            }
            MouseArea {
                id: expandArea
                anchors.fill: parent
                // Reaches back over the icon box too.
                anchors.leftMargin: -36
                enabled: setting.expands !== ""
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.open = root.open === setting.expands ? "" : setting.expands
            }
        }

        Row {
            id: controlSlot
            Layout.alignment: Qt.AlignVCenter
        }
    }

    Setting {
        icon: network.wirelessEnabled ? "network-wireless-symbolic" : "network-wireless-disconnected-symbolic"
        title: i18n("Wi-Fi")
        subtitle: !network.wirelessHwEnabled ? i18n("Unavailable")
                : !network.wirelessEnabled ? i18n("Off")
                : root.wifiStatus || i18n("Not connected")
        Toggle {
            checked: network.wirelessEnabled
            enabled: network.wirelessHwEnabled
            fillColor: checked ? root.textColor : root.dimColor
            emptyColor: root.dimColor
            font: tokens.monoFont
            onToggled: networkHandler.enableWireless(!network.wirelessEnabled)
        }
        expands: network.wirelessEnabled ? "wifi" : ""
    }

    Loader {
        Layout.fillWidth: true
        active: root.open === "wifi" && network.wirelessEnabled
        visible: active
        sourceComponent: NetworkList { handler: networkHandler }
    }

    Setting {
        icon: root.bluetoothOn ? "network-bluetooth-symbolic" : "network-bluetooth-inactive-symbolic"
        title: i18n("Bluetooth")
        subtitle: !root.bluetoothOn ? i18n("Off")
                : root.bluetooth.connectedDevices.length > 0
                    ? root.bluetooth.connectedDevices.map(d => d.name).join(", ")
                    : i18n("Not connected")
        Toggle {
            checked: root.bluetoothOn
            enabled: root.bluetooth.adapters.length > 0
            fillColor: checked ? root.textColor : root.dimColor
            emptyColor: root.dimColor
            font: tokens.monoFont
            onToggled: root.setBluetooth(!root.bluetoothOn)
        }
        expands: root.bluetoothOn ? "bluetooth" : ""
    }

    Loader {
        Layout.fillWidth: true
        active: root.open === "bluetooth" && root.bluetoothOn
        visible: active
        sourceComponent: BluetoothList {}
    }

    Setting {
        id: volume
        readonly property real level: root.sink ? root.sink.volume / Volume.PulseAudio.NormalVolume : 0
        icon: !root.sink || root.sink.muted ? "audio-volume-muted" : "audio-volume-high"
        title: i18n("Volume")
        subtitle: root.sink ? root.sink.description : i18n("No output")
        expands: "audio"

        Row {
            spacing: 8
            // Click or drag along the cells to set the level.
            Item {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: volumeMeter.implicitWidth
                implicitHeight: volumeMeter.height
                Meter {
                    id: volumeMeter
                    cells: 12
                    value: volume.level
                    fillColor: root.sink && root.sink.muted ? root.dimColor : root.textColor
                    emptyColor: root.dimColor
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    function set(x) {
                        if (!root.sink)
                            return
                        const t = Math.max(0, Math.min(1, x / volumeMeter.width))
                        root.sink.volume = Math.round(t * 20) / 20 * Volume.PulseAudio.NormalVolume
                        root.sink.muted = t === 0
                    }
                    // The margins shift mouse.x by 4.
                    onPressed: mouse => set(mouse.x - 4)
                    onPositionChanged: mouse => set(mouse.x - 4)
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                horizontalAlignment: Text.AlignRight
                text: Math.round(volume.level * 100) + "%"
                color: root.textColor
                font.family: tokens.monoFont
                font.pixelSize: 11
            }
        }
    }

    Loader {
        Layout.fillWidth: true
        active: root.open === "audio"
        visible: active
        sourceComponent: OutputList {}
    }

    Setting {
        visible: root.battery.hasBatteries
        // Breeze has battery-000-symbolic ... battery-100-charging-symbolic, in tens.
        icon: "battery-%1%2-symbolic".arg(String(Math.round(root.battery.percent / 10) * 10).padStart(3, "0"))
                                      .arg(root.battery.pluggedIn ? "-charging" : "")
        title: i18n("Battery")
        subtitle: root.battery.pluggedIn
            ? (root.battery.percent >= 100 ? i18n("Fully charged") : i18n("Plugged in"))
            : root.battery.remainingMsec > 0 ? i18n("%1 left", root.formatDuration(root.battery.remainingMsec))
            : i18n("On battery")
        Row {
            spacing: 8
            Meter {
                anchors.verticalCenter: parent.verticalCenter
                cells: 6
                brackets: true
                font: tokens.monoFont
                value: root.battery.percent / 100
                fillColor: root.battery.percent <= 15 && !root.battery.pluggedIn ? Kirigami.Theme.negativeTextColor : root.textColor
                emptyColor: root.dimColor
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                horizontalAlignment: Text.AlignRight
                text: root.battery.percent + "%"
                color: root.textColor
                font.family: tokens.monoFont
                font.pixelSize: 11
            }
        }
    }

    Setting {
        icon: "color-management-symbolic"
        title: i18n("Design")
        subtitle: (tokens.variants.find(v => v.scheme === root.scheme) || { name: i18n("Custom") }).name

        Row {
            spacing: 8
            Repeater {
                model: tokens.variants
                Rectangle {
                    id: swatch
                    required property var modelData
                    readonly property bool current: modelData.scheme === root.scheme
                    width: 14
                    height: 14
                    radius: 7
                    color: modelData.swatch
                    border.width: current ? 2 : 1
                    border.color: current ? root.accentColor : root.dimColor
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -3
                        cursorShape: Qt.PointingHandCursor
                        // The installed switcher also recolours Konsole; without
                        // it, only KDE's colours change.
                        onClicked: {
                            root.scheme = swatch.modelData.scheme
                            shell.run(`"$HOME/.local/share/orbiter/switch-variant.sh" ${swatch.modelData.key} 2>/dev/null`
                                      + ` || plasma-apply-colorscheme ${swatch.modelData.scheme}`,
                                      () => root.refreshScheme())
                        }
                    }
                }
            }
        }
    }

    // IN THE BACKGROUND ------------
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 8
        visible: root.trayItems.length > 0
        spacing: 8
        Text {
            text: i18n("In the background").toUpperCase()
            color: root.mutedColor
            font.family: tokens.displayFont
            font.pixelSize: 13
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

    GridLayout {
        Layout.fillWidth: true
        visible: !root.trayMenu
        columns: 4
        rowSpacing: 4
        columnSpacing: 4

        Repeater {
            model: root.trayItems
            TrayTile {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                textColor: root.mutedColor
                hoverTextColor: root.textColor
                cardColor: root.cardColor
                onActivated: root.done()
                onMenuRequested: (service, menuPath, title) =>
                    root.trayMenu = { service: service, path: menuPath, title: title }
            }
        }
    }

    // The app's menu, in place of the grid.
    Loader {
        Layout.fillWidth: true
        active: root.trayMenu !== null
        visible: active
        sourceComponent: TrayMenu {
            service: root.trayMenu.service
            menuPath: root.trayMenu.path
            title: root.trayMenu.title
            onClosed: root.trayMenu = null
            onDone: root.done()
        }
    }
}
