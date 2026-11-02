import QtQuick

// A level drawn as cells, filled bars then dots: ▮▮··. Optionally bracketed.
Row {
    id: meter

    property real value: 0          // 0..1
    property int cells: 4
    property bool brackets: false
    property color fillColor: "white"
    property color emptyColor: "grey"
    property string font: ""
    // Anything above zero shows at least one bar.
    readonly property int filled: value > 0.01 ? Math.max(1, Math.round(Math.min(value, 1) * cells)) : 0

    spacing: 2
    height: 12

    Text {
        visible: meter.brackets
        anchors.verticalCenter: parent.verticalCenter
        text: "["
        color: meter.emptyColor
        font.family: meter.font
        font.pixelSize: 12
    }

    Repeater {
        model: meter.cells
        Item {
            required property int index
            readonly property bool on: index < meter.filled
            width: 3
            height: meter.height
            Rectangle {
                anchors.centerIn: parent
                width: parent.on ? 3 : 2
                height: parent.on ? 9 : 2
                color: parent.on ? meter.fillColor : meter.emptyColor
            }
        }
    }

    Text {
        visible: meter.brackets
        anchors.verticalCenter: parent.verticalCenter
        text: "]"
        color: meter.emptyColor
        font.family: meter.font
        font.pixelSize: 12
    }
}
