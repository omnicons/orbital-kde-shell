import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager

// The bell's popup: notification history, newest first. Click one to run its
// default action; hover for its close button.
ColumnLayout {
    id: root

    required property var notifications     // a NotificationManager.Notifications model
    signal done()

    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color mutedColor: Kirigami.Theme.disabledTextColor
    readonly property color dimColor: Qt.alpha(Kirigami.Theme.textColor, 0.35)
    readonly property color cardColor: Kirigami.Theme.alternateBackgroundColor
    property date now: new Date()

    width: 340
    spacing: 8

    Tokens { id: tokens }

    function ago(date) {
        const minutes = Math.floor((now - date) / 60000)
        if (minutes < 1)
            return i18n("now")
        if (minutes < 60)
            return i18n("%1 min", minutes)
        if (minutes < 24 * 60)
            return i18n("%1 h", Math.floor(minutes / 60))
        return Qt.locale().toString(date, "d MMM")
    }

    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: i18n("Notifications").toUpperCase()
            color: Kirigami.Theme.linkColor
            font.family: tokens.displayFont
            font.pixelSize: 15
            font.letterSpacing: 1
        }
        Text {
            visible: root.notifications.count > 0
            text: "[" + i18n("Clear").toUpperCase() + "]"
            color: clearArea.containsMouse ? root.textColor : root.mutedColor
            font.family: tokens.displayFont
            font.pixelSize: 13
            MouseArea {
                id: clearArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                onClicked: root.notifications.clear(NotificationManager.Notifications.ClearExpired)
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 12
        Layout.bottomMargin: 12
        visible: root.notifications.count === 0
        horizontalAlignment: Text.AlignHCenter
        text: i18n("Nothing new")
        color: root.dimColor
        font.family: tokens.uiFont
        font.pixelSize: 11
    }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 420)
        visible: count > 0
        clip: true
        spacing: 4
        model: root.notifications
        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

        delegate: Rectangle {
            id: entry
            required property var model
            required property int index

            width: ListView.view.width
            height: content.implicitHeight + 16
            color: area.containsMouse ? Qt.lighter(root.cardColor, 1.2) : root.cardColor

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    if (entry.model.hasDefaultAction) {
                        root.notifications.invokeDefaultAction(root.notifications.index(entry.index, 0),
                                                               NotificationManager.Notifications.Close)
                        root.done()
                    }
                }
            }

            ColumnLayout {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Kirigami.Icon {
                        Layout.preferredWidth: 14
                        Layout.preferredHeight: 14
                        source: entry.model.applicationIconName || entry.model.iconName || "dialog-information"
                    }
                    Text {
                        Layout.fillWidth: true
                        text: entry.model.applicationName || ""
                        elide: Text.ElideRight
                        color: root.mutedColor
                        font.family: tokens.uiFont
                        font.pixelSize: 10
                    }
                    Text {
                        visible: !closeText.visible
                        text: root.ago(entry.model.updated || entry.model.created)
                        color: root.dimColor
                        font.family: tokens.monoFont
                        font.pixelSize: 10
                    }
                    Text {
                        id: closeText
                        visible: area.containsMouse || closeArea.containsMouse
                        text: "×"
                        color: closeArea.containsMouse ? root.textColor : root.mutedColor
                        font.family: tokens.monoFont
                        font.pixelSize: 13
                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            onClicked: root.notifications.close(root.notifications.index(entry.index, 0))
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: entry.model.summary || ""
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: root.textColor
                    font.family: tokens.uiFont
                    font.weight: Font.Medium
                    font.pixelSize: 12
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: entry.model.body || ""
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    color: root.mutedColor
                    font.family: tokens.uiFont
                    font.pixelSize: 11
                }
            }
        }
    }
}
