import QtQuick
import org.kde.kirigami as Kirigami

// A health category at a glance: a dim square when it's fine, an asterisk
// when it has notes (red for critical ones).
Item {
    id: mark

    property string level: ""       // "", "info", "warning" or "critical"

    Tokens { id: tokens }

    implicitWidth: 12
    implicitHeight: 12

    Rectangle {
        anchors.centerIn: parent
        visible: mark.level === ""
        width: 5
        height: 5
        color: Qt.alpha(Kirigami.Theme.textColor, 0.35)
    }
    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 2
        visible: mark.level !== ""
        text: "*"
        color: mark.level === "critical" ? Kirigami.Theme.negativeTextColor
             : mark.level === "warning" ? Kirigami.Theme.focusColor
             : Kirigami.Theme.disabledTextColor
        font.family: tokens.monoFont
        font.weight: Font.Bold
        font.pixelSize: 16
    }
}
