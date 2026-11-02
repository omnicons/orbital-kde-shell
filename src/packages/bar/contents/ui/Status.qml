import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.plasma.private.volume as Volume
import org.kde.plasma.private.battery as Battery
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.workspace.dbus as DBus

// Network, volume, battery, background apps and notifications:
//   ⌘ 🔊 [▮▮▮·] 66% | ⌄ 3  🔔
// Click for quick settings, click the bell for notifications, scroll over the
// speaker to change the volume.
Pill {
    id: pill

    Tokens { id: tokens }

    PlasmaNM.ConnectionIcon { id: connection }
    Battery.BatteryControlModel { id: batteryModel }
    NotificationManager.Notifications {
        id: notificationModel
        showNotifications: true
        showJobs: false
        showExpired: true
        showDismissed: true
        groupMode: NotificationManager.Notifications.GroupDisabled
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
    }
    // Apps with a tray icon, as the tray's own watcher lists them.
    DBus.Properties {
        id: tray
        busType: DBus.BusType.Session
        service: "org.kde.StatusNotifierWatcher"
        path: "/StatusNotifierWatcher"
        iface: "org.kde.StatusNotifierWatcher"
    }
    // The watcher announces items with signals rather than PropertiesChanged.
    DBus.SignalWatcher {
        busType: DBus.BusType.Session
        service: "org.kde.StatusNotifierWatcher"
        path: "/StatusNotifierWatcher"
        iface: "org.kde.StatusNotifierWatcher"
        function onReceivedSignal(name) {
            if (name.startsWith("StatusNotifierItem"))
                tray.update()
        }
    }

    readonly property var sink: Volume.PreferredDevice.sink
    readonly property real volume: sink ? sink.volume / Volume.PulseAudio.NormalVolume : 0
    readonly property var trayItems: tray.properties.RegisteredStatusNotifierItems || []
    readonly property int trayCount: trayItems.length

    component StatusIcon: Kirigami.Icon {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 14
        height: 14
        isMask: true
        color: pill.mutedColor
    }

    StatusIcon {
        source: connection.connectionIcon || "network-disconnect"
    }

    StatusIcon {
        source: !pill.sink || pill.sink.muted || pill.volume <= 0 ? "audio-volume-muted"
              : pill.volume < 0.34 ? "audio-volume-low"
              : pill.volume < 0.67 ? "audio-volume-medium" : "audio-volume-high"
        color: speaker.containsMouse ? pill.textColor : pill.mutedColor
        MouseArea {
            id: speaker
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            acceptedButtons: Qt.NoButton    // clicks open quick settings
            onWheel: wheel => {
                if (!pill.sink)
                    return
                const step = (wheel.angleDelta.y > 0 ? 0.05 : -0.05) * Volume.PulseAudio.NormalVolume
                pill.sink.volume = Math.max(0, Math.min(Volume.PulseAudio.NormalVolume, pill.sink.volume + step))
                if (pill.sink.muted)
                    pill.sink.muted = false
            }
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        visible: batteryModel.hasBatteries
        spacing: 6
        readonly property bool low: batteryModel.percent <= 15 && !batteryModel.pluggedIn

        Meter {
            anchors.verticalCenter: parent.verticalCenter
            value: batteryModel.percent / 100
            brackets: true
            font: tokens.monoFont
            fillColor: parent.low ? Kirigami.Theme.negativeTextColor : pill.textColor
            emptyColor: pill.dimColor
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            // A plus while charging.
            text: batteryModel.percent + "%" + (batteryModel.pluggedIn && batteryModel.percent < 100 ? "+" : "")
            color: parent.low ? Kirigami.Theme.negativeTextColor : pill.textColor
            font.family: tokens.monoFont
            font.weight: Font.Medium
            font.pixelSize: 11
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
        visible: pill.trayCount > 0
        spacing: 3
        Kirigami.Icon {
            anchors.verticalCenter: parent.verticalCenter
            width: 10
            height: 10
            source: "arrow-down"
            isMask: true
            color: pill.mutedColor
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: pill.trayCount
            color: pill.textColor
            font.family: tokens.monoFont
            font.pixelSize: 11
        }
    }

    StatusIcon {
        id: bell
        source: notificationModel.unreadNotificationsCount > 0 ? "notification-active" : "notification-inactive"
        color: notificationModel.unreadNotificationsCount > 0 ? pill.accentColor
             : bellHover.hovered || notificationPopup.visible ? pill.textColor : pill.mutedColor
        HoverHandler { id: bellHover }
    }

    TapHandler {
        onTapped: (point) => {
            const onBell = bell.contains(bell.mapFromItem(pill, point.position))
            const popup = onBell ? notificationPopup : quickSettingsPopup
            const other = onBell ? quickSettingsPopup : notificationPopup
            other.visible = false
            popup.visible = !popup.visible
        }
    }

    Popup {
        id: quickSettingsPopup
        visualParent: pill
        onVisibleChanged: {
            if (!visible)
                return
            quickSettings.reset()
            quickSettings.refreshScheme()
        }

        mainItem: Scroller {
            maxHeight: quickSettingsPopup.maxContentHeight
            QuickSettings {
                id: quickSettings
                battery: batteryModel
                sink: pill.sink
                trayItems: pill.trayItems
                onDone: quickSettingsPopup.visible = false
            }
        }
    }

    Popup {
        id: notificationPopup
        visualParent: pill
        onVisibleChanged: {
            if (!visible)
                return
            notificationList.now = new Date()
            // Opening the list counts as reading everything in it.
            notificationModel.lastRead = new Date()
        }

        mainItem: Scroller {
            maxHeight: notificationPopup.maxContentHeight
            NotificationList {
                id: notificationList
                notifications: notificationModel
                onDone: notificationPopup.visible = false
            }
        }
    }
}
