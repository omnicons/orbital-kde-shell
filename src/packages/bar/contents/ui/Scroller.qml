import QtQuick
import QtQuick.Controls as QQC2

// Holds a popup's content and keeps it on screen: it takes the content's
// height up to `maxHeight`, and scrolls past that, growing a scrollbar's
// width so the bar doesn't sit on the content.
Flickable {
    id: scroller

    required property real maxHeight
    default property alias content: holder.data

    // The content, sized by its own implicit height: a layout's height stops
    // following its implicit height once anything has set it.
    readonly property Item item: holder.children.length > 0 ? holder.children[0] : null
    readonly property bool overflowing: contentHeight > maxHeight

    implicitWidth: (item ? item.width : 0) + (overflowing ? bar.width + 4 : 0)
    implicitHeight: Math.min(contentHeight, maxHeight)
    contentWidth: width
    contentHeight: item ? item.implicitHeight : 0
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: overflowing

    QQC2.ScrollBar.vertical: QQC2.ScrollBar {
        id: bar
        policy: scroller.overflowing ? QQC2.ScrollBar.AlwaysOn : QQC2.ScrollBar.AlwaysOff
    }

    Item {
        id: holder
        width: scroller.width
    }

    Binding {
        target: scroller.item
        property: "height"
        value: scroller.contentHeight
    }
}
