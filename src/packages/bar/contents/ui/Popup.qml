import QtQuick
import org.kde.plasma.core as PlasmaCore

// A popup under a pill, sized to its content. PopupPlasmaWindow doesn't size
// itself from mainItem; left alone it opens at 500×500 and stretches it.
PlasmaCore.PopupPlasmaWindow {
    property real contentWidth: mainItem ? mainItem.implicitWidth : 0
    property real contentHeight: mainItem ? mainItem.implicitHeight : 0
    // The tallest content that still fits between the bar and the bottom of
    // the screen, padding included; wrap long content in a Scroller with it.
    readonly property real maxContentHeight: visualParent ? visualParent.Screen.height - 96 : 800

    width: contentWidth + leftPadding + rightPadding
    height: contentHeight + topPadding + bottomPadding
    popupDirection: Qt.BottomEdge
    hideOnWindowDeactivate: true
}
