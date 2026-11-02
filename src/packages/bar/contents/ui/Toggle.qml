import QtQuick

// An on/off switch drawn as a bracketed meter: [▮▮▮] on, [▮··] off.
Item {
    id: toggle

    property bool checked: false
    property alias fillColor: meter.fillColor
    property alias emptyColor: meter.emptyColor
    property alias font: meter.font
    signal toggled()

    implicitWidth: meter.implicitWidth
    implicitHeight: meter.height
    opacity: enabled ? 1 : 0.5

    Meter {
        id: meter
        cells: 3
        brackets: true
        value: toggle.checked ? 1 : 0.34
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggled()
    }
}
