import QtQuick
import org.kde.kirigami as Kirigami

// A bracketed choice: [OVERVIEW], [15 MIN], [CPU]. The current one is bright
// with accent brackets. With `bracketed`, the others keep plain brackets,
// which makes it a button: [FETCH], [SUSPEND].
Text {
    id: choice

    property bool current: false
    property string label
    property bool bracketed: false
    signal picked()

    Tokens { id: tokens }

    textFormat: Text.StyledText
    text: current
        ? `<font color="${Kirigami.Theme.focusColor}">[</font>${label}<font color="${Kirigami.Theme.focusColor}">]</font>`
        : bracketed ? `[${label}]` : label
    color: current || area.containsMouse ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
    font.family: tokens.displayFont
    font.pixelSize: 14
    font.letterSpacing: 1

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        onClicked: choice.picked()
    }
}
