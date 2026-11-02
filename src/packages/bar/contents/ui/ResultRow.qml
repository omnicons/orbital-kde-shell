import QtQuick
import org.kde.kirigami as Kirigami

// A launcher result: icon, title over subtitle, and its kind on the right.
// The current row gets a card background and an accent edge.
Rectangle {
    id: row

    property bool current: false
    property var icon
    property string title
    property string subtitle
    property string tag
    signal clicked()
    signal hovered()

    Tokens { id: tokens }

    color: current ? Kirigami.Theme.alternateBackgroundColor : "transparent"

    Rectangle {
        visible: row.current
        width: 2
        height: parent.height
        color: Kirigami.Theme.focusColor
    }

    Kirigami.Icon {
        id: iconItem
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: 22
        source: row.icon
    }

    Column {
        anchors.left: iconItem.right
        anchors.leftMargin: 12
        anchors.right: tagText.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        Text {
            width: parent.width
            text: row.title
            elide: Text.ElideRight
            color: Kirigami.Theme.textColor
            font.family: tokens.uiFont
            font.weight: Font.Medium
            font.pixelSize: 12
        }
        Text {
            width: parent.width
            visible: text.length > 0
            text: row.subtitle
            elide: Text.ElideRight
            color: Kirigami.Theme.disabledTextColor
            font.family: tokens.uiFont
            font.pixelSize: 10
        }
    }

    Text {
        id: tagText
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: row.tag.toUpperCase()
        color: Qt.alpha(Kirigami.Theme.textColor, 0.35)
        font.family: tokens.displayFont
        font.pixelSize: 11
        font.letterSpacing: 1
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: row.clicked()
        onEntered: row.hovered()
    }
}
