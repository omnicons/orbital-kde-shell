import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "Format.js" as Format

// One row per drive: where it's mounted, how full, as a long cell meter that
// turns orange past 80 % and red past 90 %. Disk activity on top.
ColumnLayout {
    id: root

    required property var info
    required property var history

    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color mutedColor: Kirigami.Theme.disabledTextColor
    readonly property color dimColor: Qt.alpha(Kirigami.Theme.textColor, 0.35)

    spacing: 10

    Tokens { id: tokens }

    Text {
        text: i18n("Read %1 · Write %2", Format.rate(root.history.diskRead), Format.rate(root.history.diskWrite))
        color: root.mutedColor
        font.family: tokens.uiFont
        font.pixelSize: 10
    }

    Repeater {
        model: root.info.drives
        ColumnLayout {
            id: drive
            required property var modelData
            readonly property real used: modelData.used / modelData.size
            readonly property color levelColor: used >= 0.9 ? Kirigami.Theme.negativeTextColor
                                              : used >= 0.8 ? Kirigami.Theme.neutralTextColor : root.textColor
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: drive.modelData.target
                    color: root.textColor
                    font.family: tokens.uiFont
                    font.weight: Font.Medium
                    font.pixelSize: 12
                }
                Text {
                    Layout.fillWidth: true
                    text: drive.modelData.source + " · " + drive.modelData.fstype
                    elide: Text.ElideRight
                    color: root.mutedColor
                    font.family: tokens.uiFont
                    font.pixelSize: 10
                }
                Text {
                    text: i18n("%1 of %2", Format.bytes(drive.modelData.used), Format.bytes(drive.modelData.size))
                    color: root.mutedColor
                    font.family: tokens.uiFont
                    font.pixelSize: 10
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Meter {
                    Layout.fillWidth: true
                    // As many cells as fit, so the meter spans the row.
                    cells: Math.max(10, Math.floor((root.width - 60) / 5))
                    value: drive.used
                    fillColor: drive.levelColor
                    emptyColor: root.dimColor
                }
                Text {
                    Layout.preferredWidth: 40
                    horizontalAlignment: Text.AlignRight
                    text: Format.percent(drive.used * 100)
                    color: drive.levelColor
                    font.family: tokens.monoFont
                    font.pixelSize: 11
                }
            }
        }
    }

    Text {
        visible: root.info.drives.length === 0
        text: i18n("Reading drives…")
        color: root.dimColor
        font.family: tokens.uiFont
        font.pixelSize: 11
    }
}
