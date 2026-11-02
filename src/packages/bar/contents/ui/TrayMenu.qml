import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.dbus as DBus

// A tray app's menu, read over D-Bus (com.canonical.dbusmenu, which most tray
// apps publish rather than drawing a menu themselves) and drawn in place:
// ‹ back, the items, submenus stepped into. Clicking an item tells the app.
ColumnLayout {
    id: root

    required property string service
    required property string menuPath
    required property string title
    signal closed()                 // back out of the menu
    signal done()                   // an item ran; close the popup

    // The menu tree from GetLayout, and the path of submenu ids we're in.
    property var tree: null
    property var trail: []
    property string error

    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color mutedColor: Kirigami.Theme.disabledTextColor
    readonly property color dimColor: Qt.alpha(Kirigami.Theme.textColor, 0.35)
    readonly property color lineColor: Qt.alpha(Kirigami.Theme.textColor, 0.10)

    // dbusmenu wants exact D-Bus types, which plain JS values don't carry.
    property DBus.int32 rootId: 0
    property DBus.int32 allLevels: -1
    property list<string> wanted: ["label", "enabled", "visible", "type", "toggle-type", "toggle-state", "children-display"]
    property DBus.int32 eventItem: 0
    property DBus.string eventName: "clicked"
    property DBus.variant eventData: 0
    property DBus.uint32 eventTime: 0

    spacing: 0

    Tokens { id: tokens }

    function call(member, args) {
        return DBus.SessionBus.asyncCall({ service: service, path: menuPath, iface: "com.canonical.dbusmenu",
                                           member: member, arguments: args })
    }

    function load() {
        // Some apps build their menu only when told it's about to show.
        call("AboutToShow", [rootId])
        const reply = call("GetLayout", [rootId, allLevels, wanted])
        reply.finished.connect(() => {
            if (reply.isError)
                root.error = reply.error.message
            else
                root.tree = reply.values[1]
        })
        event(0, "opened")
    }

    function event(id, name) {
        eventItem = id
        eventName = name
        eventTime = 0
        call("Event", [eventItem, eventName, eventData, eventTime])
    }

    // A node is [id, properties, children]; values arrive wrapped as { value }.
    function prop(node, key, fallback) {
        const p = node[1][key]
        if (p === undefined)
            return fallback
        return p !== null && typeof p === "object" && "value" in p ? p.value : p
    }

    // "_Quit" -> "Quit": underscores mark keyboard accelerators; "__" is a literal one.
    function label(node) {
        return String(prop(node, "label", "")).replace(/__/g, "\u0001").replace(/_/g, "").replace(/\u0001/g, "_")
    }

    readonly property var current: {
        let node = tree
        for (const id of trail) {
            if (!node)
                break
            node = (node[2] || []).find(child => child[0].value === id) || null
        }
        return node
    }
    readonly property var items: current ? (current[2] || []).filter(child => prop(child, "visible", true)) : []

    Component.onCompleted: load()
    Component.onDestruction: event(0, "closed")

    // ‹ NETBIRD / Exit Node
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        color: backArea.containsMouse ? Qt.alpha(root.textColor, 0.05) : "transparent"
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 4
            spacing: 8
            Kirigami.Icon {
                Layout.preferredWidth: 12
                Layout.preferredHeight: 12
                source: "arrow-left"
                isMask: true
                color: root.mutedColor
            }
            Text {
                Layout.fillWidth: true
                text: [root.title.toUpperCase()].concat(root.trail.map((id, i) => {
                    let node = root.tree
                    for (const step of root.trail.slice(0, i + 1))
                        node = (node[2] || []).find(child => child[0].value === step)
                    return node ? root.label(node) : ""
                })).join("  /  ")
                elide: Text.ElideRight
                color: Kirigami.Theme.linkColor
                font.family: tokens.displayFont
                font.pixelSize: 13
                font.letterSpacing: 1
            }
        }
        MouseArea {
            id: backArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.trail.length ? root.trail = root.trail.slice(0, -1) : root.closed()
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: root.lineColor
    }

    Repeater {
        model: root.items

        Item {
            id: entry
            required property var modelData
            readonly property bool separator: root.prop(modelData, "type", "") === "separator"
            readonly property bool enabled: root.prop(modelData, "enabled", true)
            readonly property bool submenu: root.prop(modelData, "children-display", "") === "submenu"
                                            || (modelData[2] || []).length > 0
            readonly property string toggle: root.prop(modelData, "toggle-type", "")
            readonly property bool toggled: root.prop(modelData, "toggle-state", 0) === 1

            Layout.fillWidth: true
            Layout.preferredHeight: separator ? 9 : 30

            Rectangle {
                visible: entry.separator
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 1
                color: root.lineColor
            }

            Rectangle {
                visible: !entry.separator
                anchors.fill: parent
                color: area.containsMouse && entry.enabled ? Qt.alpha(root.textColor, 0.06) : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 6
                    spacing: 8
                    Text {
                        visible: entry.toggle !== ""
                        text: entry.toggle === "radio" ? (entry.toggled ? "(•)" : "( )") : (entry.toggled ? "[x]" : "[ ]")
                        color: entry.toggled ? Kirigami.Theme.focusColor : root.mutedColor
                        font.family: tokens.monoFont
                        font.pixelSize: 12
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.label(entry.modelData)
                        elide: Text.ElideRight
                        color: entry.enabled ? root.textColor : root.dimColor
                        font.family: tokens.uiFont
                        font.pixelSize: 12
                    }
                    Kirigami.Icon {
                        visible: entry.submenu
                        Layout.preferredWidth: 10
                        Layout.preferredHeight: 10
                        source: "arrow-right"
                        isMask: true
                        color: root.mutedColor
                    }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: entry.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const id = entry.modelData[0].value
                        if (entry.submenu) {
                            root.event(id, "opened")
                            root.trail = root.trail.concat([id])
                        } else {
                            root.event(id, "clicked")
                            root.done()
                        }
                    }
                }
            }
        }
    }

    Text {
        Layout.topMargin: 8
        visible: root.error.length > 0 || (root.tree !== null && root.items.length === 0)
        text: root.error.length > 0 ? i18n("This app's menu couldn't be read.") : i18n("This menu is empty.")
        color: root.dimColor
        font.family: tokens.uiFont
        font.pixelSize: 11
    }
}
