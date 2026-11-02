import QtQuick
import org.kde.kirigami as Kirigami

// One of the dashboard's overview cards: a label, a big value, a detail line
// and the last five minutes as a sparkline. The selected card picks the big
// graph below and gets an accent edge.
Rectangle {
    id: card

    property string label
    property string corner          // top right, e.g. a temperature
    property string value
    property string detail
    property var history
    property string series
    property real maxValue: 0
    property bool selected: false
    signal clicked()

    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color mutedColor: Kirigami.Theme.disabledTextColor

    Tokens { id: tokens }

    implicitHeight: 104
    color: selected || area.containsMouse
        ? Qt.lighter(Kirigami.Theme.alternateBackgroundColor, 1.3)
        : Kirigami.Theme.alternateBackgroundColor
    border.width: selected ? 0 : 1
    border.color: Qt.alpha(textColor, 0.06)

    Rectangle {
        visible: card.selected
        width: 2
        height: parent.height
        color: Kirigami.Theme.focusColor
    }

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 2

        Item {
            width: parent.width
            height: labelText.implicitHeight
            Text {
                id: labelText
                text: card.label
                color: Kirigami.Theme.linkColor
                font.family: tokens.displayFont
                font.pixelSize: 13
                font.letterSpacing: 1
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: card.corner
                color: card.mutedColor
                font.family: tokens.monoFont
                font.pixelSize: 10
            }
        }
        Text {
            text: card.value
            color: card.textColor
            font.family: tokens.dotFont
            font.weight: tokens.dotWeight
            font.pixelSize: 22
        }
        Text {
            width: parent.width
            text: card.detail
            elide: Text.ElideRight
            color: card.mutedColor
            font.family: tokens.uiFont
            font.pixelSize: 10
        }
        Graph {
            width: parent.width
            height: 24
            values: card.history.series[card.series]
            times: card.history.times
            revision: card.history.revision
            span: 5 * 60 * 1000
            maxValue: card.maxValue
            lineColor: card.textColor
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: card.clicked()
    }
}
