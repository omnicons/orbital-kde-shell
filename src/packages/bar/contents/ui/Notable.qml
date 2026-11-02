import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// NOTABLE SINCE START: hot spells, memory pressure and full drives, newest
// first, each with when it happened.
ColumnLayout {
    id: root

    required property var events        // Health.events()
    property int limit: 0               // 0 shows them all

    Tokens { id: tokens }

    spacing: 6

    Text {
        text: i18n("Notable since start").toUpperCase()
        color: Kirigami.Theme.linkColor
        font.family: tokens.displayFont
        font.pixelSize: 14
        font.letterSpacing: 1
    }

    Repeater {
        model: root.limit > 0 ? root.events.slice(0, root.limit) : root.events
        RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 5
                Layout.preferredHeight: 5
                color: modelData.level === "critical" ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.focusColor
            }
            Text {
                Layout.preferredWidth: 90
                text: modelData.when === "now" ? i18n("now") : modelData.when
                color: Kirigami.Theme.disabledTextColor
                font.family: tokens.monoFont
                font.pixelSize: 10
            }
            Text {
                Layout.fillWidth: true
                text: modelData.text
                elide: Text.ElideRight
                color: Kirigami.Theme.textColor
                font.family: tokens.uiFont
                font.pixelSize: 11
            }
        }
    }

    Text {
        visible: root.events.length === 0
        text: i18n("Nothing so far.")
        color: Qt.alpha(Kirigami.Theme.textColor, 0.35)
        font.family: tokens.uiFont
        font.pixelSize: 11
    }
}
