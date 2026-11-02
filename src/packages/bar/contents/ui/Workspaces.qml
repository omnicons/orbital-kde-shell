import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.plasma.workspace.dbus as DBus

// The launcher button and the virtual desktops: 1 2 [3] 4. Click a number to
// switch, scroll anywhere on the pill to step through them.
Pill {
    id: pill

    signal launcherRequested()

    Tokens { id: tokens }
    TaskManager.VirtualDesktopInfo { id: desktops }

    function kwin(member, args) {
        DBus.SessionBus.asyncCall({service: "org.kde.KWin", path: "/KWin", iface: "org.kde.KWin",
                                   member: member, arguments: args || []})
    }

    Kirigami.Icon {
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        source: "view-app-grid-symbolic"
        isMask: true
        color: launcherButton.containsMouse ? pill.textColor : pill.mutedColor
        MouseArea {
            id: launcherButton
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            onClicked: pill.launcherRequested()
        }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: 12
        color: pill.dimColor
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Repeater {
            model: desktops.desktopIds
            Item {
                id: desktop
                required property var modelData
                required property int index
                readonly property bool current: modelData === desktops.currentDesktop
                width: label.implicitWidth + 6
                height: label.implicitHeight

                Text {
                    id: label
                    anchors.centerIn: parent
                    // Only the current desktop is bracketed, in the accent colour.
                    textFormat: Text.StyledText
                    text: desktop.current
                        ? `<font color="${pill.accentColor}">[</font>${desktop.index + 1}<font color="${pill.accentColor}">]</font>`
                        : desktop.index + 1
                    color: desktop.current || area.containsMouse ? pill.textColor : pill.mutedColor
                    font.family: tokens.displayFont
                    font.pixelSize: 14
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: pill.kwin("setCurrentDesktop", [desktop.index + 1])
                }
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => pill.kwin(event.angleDelta.y > 0 ? "previousDesktop" : "nextDesktop")
    }
}
