import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.dbus as DBus

// One app with a tray icon, read straight from its StatusNotifierItem. Click
// to activate it, middle-click for its secondary action, right-click for its
// menu. Apps that only offer a menu (or refuse activation) open it on click.
Rectangle {
    id: tile

    required property string modelData      // "service/path"
    property color textColor
    property color hoverTextColor
    property color cardColor
    signal activated()
    signal menuRequested(string service, string menuPath, string title)

    readonly property string service: modelData.split("/")[0]
    readonly property string path: "/" + modelData.split("/").slice(1).join("/")
    // D-Bus hands back wrapped values; String() unwraps them.
    readonly property string iconName: String(properties.properties.IconName || "")
    readonly property string itemId: String(properties.properties.Id || "")
    readonly property string title: String(properties.properties.Title || "") || itemId
    // The app's dbusmenu object, if it publishes one.
    readonly property string menuPath: String(properties.properties.Menu || "")
    readonly property bool itemIsMenu: properties.properties.ItemIsMenu === true

    // Click position, as the exact int32s the interface wants.
    property DBus.int32 clickX: 0
    property DBus.int32 clickY: 0

    Tokens { id: tokens }

    color: area.containsMouse ? Qt.lighter(cardColor, 1.25) : cardColor

    DBus.Properties {
        id: properties
        busType: DBus.BusType.Session
        service: tile.service
        path: tile.path
        iface: "org.kde.StatusNotifierItem"
    }

    function call(member) {
        const pos = tile.mapToGlobal(width / 2, height / 2)
        clickX = Math.round(pos.x)
        clickY = Math.round(pos.y)
        return DBus.SessionBus.asyncCall({service: tile.service, path: tile.path, iface: "org.kde.StatusNotifierItem",
                                          member: member, arguments: [clickX, clickY]})
    }

    function openMenu() {
        tile.menuRequested(tile.service, tile.menuPath, tile.title)
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 8
        spacing: 4

        // Apps that only send pixel data (no icon name) fall back to their id.
        Kirigami.Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 16
            height: 16
            source: tile.iconName || tile.itemId.toLowerCase()
            fallback: "application-x-executable"
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: tile.title
            elide: Text.ElideRight
            color: area.containsMouse ? tile.hoverTextColor : tile.textColor
            font.family: tokens.uiFont
            font.pixelSize: 10
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                tile.call("SecondaryActivate")
                tile.activated()
            } else if (mouse.button === Qt.RightButton || tile.itemIsMenu) {
                // Draw the app's menu ourselves; without one, ask the app to.
                if (tile.menuPath)
                    tile.openMenu()
                else
                    tile.call("ContextMenu")
            } else {
                const reply = tile.call("Activate")
                reply.finished.connect(() => {
                    if (reply.isError && tile.menuPath)
                        tile.openMenu()
                    else
                        tile.activated()
                })
            }
        }
    }
}
