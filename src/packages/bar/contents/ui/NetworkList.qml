import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.networkmanagement as PlasmaNM

// Wi-Fi networks in range, connected first then by signal. Click one to
// connect (or disconnect); new secured networks ask for their password in
// place. Connection logic follows Plasma's own network widget.
ColumnLayout {
    id: root

    required property var handler       // a PlasmaNM.Handler
    property string asking              // the network whose password is wanted

    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color mutedColor: Kirigami.Theme.disabledTextColor
    readonly property color dimColor: Qt.alpha(Kirigami.Theme.textColor, 0.35)
    readonly property color lineColor: Qt.alpha(Kirigami.Theme.textColor, 0.10)

    spacing: 0

    // Rows shown before the list scrolls, as in the Bluetooth list.
    readonly property int maxRows: 7
    // Rows step in from the right while the scrollbar shows.
    readonly property real scrollGap: bar.visible ? bar.width + 4 : 0

    Tokens { id: tokens }

    PlasmaNM.NetworkModel { id: networkModel }
    PlasmaNM.AppletProxyModel { id: sorted; sourceModel: networkModel }
    KItemModels.KSortFilterProxyModel {
        id: wireless
        sourceModel: sorted
        filterRowCallback: (row, parent) =>
            sourceModel.data(sourceModel.index(row, 0, parent), sourceModel.KItemModels.KRoleNames.role("Type"))
                === PlasmaNM.Enums.Wireless
    }

    // Fresh results whenever the list opens.
    Component.onCompleted: handler.requestScan("")

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, root.maxRows * 35)
        clip: true
        model: wireless
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: QQC2.ScrollBar {
            id: bar
            visible: list.contentHeight > list.height
        }

        delegate: ColumnLayout {
            id: network
            required property var model
            readonly property bool connected: model.ConnectionState === PlasmaNM.Enums.Activated
            readonly property bool busy: model.ConnectionState === PlasmaNM.Enums.Activating
                                         || model.ConnectionState === PlasmaNM.Enums.Deactivating
            readonly property bool secured: model.SecurityType > PlasmaNM.Enums.NoneSecurity
            // Unknown networks with a plain password are asked for it here;
            // enterprise ones go to Plasma's own dialog via addAndActivate.
            readonly property bool needsPassword: !model.Uuid && [PlasmaNM.Enums.StaticWep, PlasmaNM.Enums.WpaPsk,
                PlasmaNM.Enums.Wpa2Psk, PlasmaNM.Enums.SAE].includes(model.SecurityType)
            readonly property bool asking: root.asking === model.ItemUniqueName

            width: ListView.view.width
            spacing: 0

            function activate() {
                if (connected || busy)
                    root.handler.deactivateConnection(model.ConnectionPath, model.DevicePath)
                else if (model.Uuid)
                    root.handler.activateConnection(model.ConnectionPath, model.DevicePath, model.SpecificPath)
                else if (needsPassword)
                    root.asking = asking ? "" : model.ItemUniqueName
                else
                    root.handler.addAndActivateConnection(model.DevicePath, model.SpecificPath)
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                color: area.containsMouse ? Qt.alpha(root.textColor, 0.05) : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 36
                    anchors.rightMargin: 4 + root.scrollGap
                    spacing: 10

                    Meter {
                        cells: 4
                        value: network.model.Signal / 100
                        fillColor: network.connected ? Kirigami.Theme.focusColor : root.textColor
                        emptyColor: root.dimColor
                    }
                    Text {
                        Layout.fillWidth: true
                        text: network.model.ItemUniqueName
                        elide: Text.ElideRight
                        color: root.textColor
                        font.family: tokens.uiFont
                        font.weight: network.connected ? Font.Medium : Font.Normal
                        font.pixelSize: 12
                    }
                    Text {
                        text: network.connected ? i18n("Connected")
                            : network.busy ? i18n("Connecting…")
                            : network.model.Uuid ? i18n("Saved") : ""
                        color: network.connected ? Kirigami.Theme.focusColor : root.mutedColor
                        font.family: tokens.uiFont
                        font.pixelSize: 10
                    }
                    Kirigami.Icon {
                        Layout.preferredWidth: 12
                        Layout.preferredHeight: 12
                        visible: network.secured
                        source: "object-locked-symbolic"
                        isMask: true
                        color: root.mutedColor
                    }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: network.activate()
                }
            }

            // > password ●●●●   [CONNECT]
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 36
                Layout.rightMargin: 4 + root.scrollGap
                Layout.preferredHeight: visible ? 34 : 0
                visible: network.asking
                spacing: 8

                Text {
                    text: ">"
                    color: Kirigami.Theme.focusColor
                    font.family: tokens.monoFont
                    font.pixelSize: 12
                }
                TextInput {
                    id: password
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: root.textColor
                    font.family: tokens.monoFont
                    font.pixelSize: 12
                    clip: true
                    onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                    Keys.onReturnPressed: connect.picked()
                    Keys.onEnterPressed: connect.picked()
                    Keys.onEscapePressed: root.asking = ""
                    Text {
                        visible: password.text.length === 0
                        text: i18n("Password")
                        color: root.dimColor
                        font: password.font
                    }
                }
                Choice {
                    id: connect
                    label: i18n("Connect").toUpperCase()
                    bracketed: true
                    font.pixelSize: 12
                    onPicked: {
                        if (password.text.length === 0)
                            return
                        root.handler.addAndActivateConnection(network.model.DevicePath, network.model.SpecificPath, password.text)
                        root.asking = ""
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 36
                Layout.preferredHeight: 1
                color: root.lineColor
            }
        }
    }

    Text {
        Layout.leftMargin: 36
        Layout.topMargin: 6
        Layout.bottomMargin: 6
        visible: list.count === 0
        text: root.handler.scanning ? i18n("Scanning…") : i18n("No networks in range")
        color: root.dimColor
        font.family: tokens.uiFont
        font.pixelSize: 11
    }
}
