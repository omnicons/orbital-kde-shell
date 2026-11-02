import QtQuick
import org.kde.kirigami as Kirigami

// A square, thin-bordered box on the top bar that lays its children out in a
// row. Colours come from the colour scheme's Header set, so every variant
// restyles it live.
Rectangle {
    id: pill

    default property alias content: row.data
    property alias spacing: row.spacing
    property real padding: 8
    readonly property alias hovered: hover.hovered
    // Shared colour roles for the pill's contents.
    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color mutedColor: Kirigami.Theme.disabledTextColor
    readonly property color dimColor: Qt.alpha(Kirigami.Theme.textColor, 0.35)
    // Plasma maps activeTextColor elsewhere; linkColor is the scheme's heading colour.
    readonly property color headingColor: Kirigami.Theme.linkColor
    readonly property color accentColor: Kirigami.Theme.focusColor
    readonly property bool light: Kirigami.ColorUtils.brightnessForColor(color) === Kirigami.ColorUtils.Light

    Tokens { id: tokens }

    Kirigami.Theme.colorSet: Kirigami.Theme.Header
    Kirigami.Theme.inherit: false

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: tokens.barHeight
    radius: tokens.radius
    color: Kirigami.Theme.backgroundColor
    border.width: tokens.border
    border.color: Qt.alpha(Kirigami.Theme.textColor, (light ? 0.16 : 0.10) + (hovered ? 0.08 : 0))

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
    }

    HoverHandler {
        id: hover
    }
}
