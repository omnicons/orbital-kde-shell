import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.volume as Volume

// Audio outputs: click one to make it the default, which is where sound
// goes. The current one is marked in the accent colour. Outputs on the same
// card share a long name ("Meteor Lake-P HD Audio Controller ..."), so that
// shared part is dropped and only what tells them apart is shown.
ColumnLayout {
    id: root

    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color mutedColor: Kirigami.Theme.disabledTextColor
    readonly property color lineColor: Qt.alpha(Kirigami.Theme.textColor, 0.10)

    spacing: 0

    // The words every output's name starts with, when there's more than one.
    property string shared

    function updateShared() {
        const names = []
        for (let i = 0; i < outputs.count; ++i) {
            const item = outputs.itemAt(i)
            if (item && item.model.Name !== "auto_null")
                names.push(String(item.model.Description).split(" "))
        }
        if (names.length < 2) {
            shared = ""
            return
        }
        let n = 0
        while (names.every(words => n < words.length - 1 && words[n] === names[0][n]))
            ++n
        shared = names[0].slice(0, n).join(" ")
    }

    Tokens { id: tokens }

    Repeater {
        id: outputs
        model: Volume.SinkModel {}
        // After the batch of rows is in, not as each arrives.
        onItemAdded: Qt.callLater(root.updateShared)
        onItemRemoved: Qt.callLater(root.updateShared)

        ColumnLayout {
            id: output
            required property var model
            readonly property bool current: model.Default
            // PulseAudio's "auto_null" placeholder isn't a real output.
            visible: model.Name !== "auto_null"
            Layout.fillWidth: true
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                color: area.containsMouse ? Qt.alpha(root.textColor, 0.05) : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 36
                    anchors.rightMargin: 4
                    spacing: 10
                    Text {
                        text: output.current ? "(•)" : "( )"
                        color: output.current ? Kirigami.Theme.focusColor : root.mutedColor
                        font.family: tokens.monoFont
                        font.pixelSize: 12
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.shared && output.model.Description.startsWith(root.shared + " ")
                            ? output.model.Description.slice(root.shared.length + 1)
                            : output.model.Description
                        elide: Text.ElideRight
                        color: root.textColor
                        font.family: tokens.uiFont
                        font.weight: output.current ? Font.Medium : Font.Normal
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: output.model.PulseObject.default = true
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
}
