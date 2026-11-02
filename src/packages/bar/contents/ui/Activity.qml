import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

// A pulse icon that expands into live load readings:
//   ∿ ‹ CPU ▮··· 7% 51° | GPU ▮▮·· 41% 47° | RAM ▮▮·· 27%
// The arrow expands and collapses the readings; anywhere else opens the
// dashboard, which keeps them expanded while it's open.
Pill {
    id: pill

    property bool expanded: false
    readonly property bool showReadings: expanded || dashboardPopup.visible

    Tokens { id: tokens }
    // Held in a property rather than as a child, so it stays out of the row.
    readonly property History sampler: History {}

    component Reading: Row {
        id: reading
        property string label
        property real usage
        property real temperature

        spacing: 6
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: reading.label
            color: pill.headingColor
            font.family: tokens.displayFont
            font.pixelSize: 14
        }
        Meter {
            anchors.verticalCenter: parent.verticalCenter
            value: reading.usage / 100
            fillColor: pill.textColor
            emptyColor: pill.dimColor
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            horizontalAlignment: Text.AlignRight
            text: Math.round(reading.usage) + "%"
            color: pill.textColor
            font.family: tokens.monoFont
            font.weight: Font.Medium
            font.pixelSize: 11
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: reading.temperature > 0
            text: Math.round(reading.temperature) + "°"
            color: pill.mutedColor
            font.family: tokens.monoFont
            font.pixelSize: 11
        }
    }

    component Divider: Rectangle {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 1
        height: 12
        color: pill.dimColor
    }

    Shape {
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 10
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: pill.hovered || dashboardPopup.visible ? pill.textColor : pill.mutedColor
            strokeWidth: 1.4
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            PathPolyline { path: [Qt.point(0, 5), Qt.point(4, 5), Qt.point(6, 1), Qt.point(8, 9), Qt.point(10, 5), Qt.point(14, 5)] }
        }
    }

    Kirigami.Icon {
        id: arrow
        anchors.verticalCenter: parent.verticalCenter
        width: 10
        height: 10
        source: pill.showReadings ? "arrow-left" : "arrow-right"
        isMask: true
        color: pill.mutedColor
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        visible: pill.showReadings
        spacing: 10
        Reading { label: "CPU"; usage: sampler.cpu; temperature: sampler.cpuTemp }
        Divider {}
        Reading { label: "GPU"; usage: sampler.gpu; temperature: sampler.gpuTemp }
        Divider {}
        Reading { label: "RAM"; usage: sampler.ram }
    }

    TapHandler {
        onTapped: point => {
            // A generous target around the small arrow.
            const p = arrow.mapFromItem(pill, point.position)
            if (p.x > -6 && p.x < arrow.width + 6)
                pill.expanded = !pill.expanded
            else
                dashboardPopup.visible = !dashboardPopup.visible
        }
    }

    Popup {
        id: dashboardPopup
        visualParent: pill

        mainItem: Scroller {
            maxHeight: dashboardPopup.maxContentHeight
            Dashboard {
                history: sampler
                shown: dashboardPopup.visible
            }
        }
    }
}
