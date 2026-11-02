import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// The health score, its five categories with their notes, and everything
// notable recorded since the bar started.
ColumnLayout {
    id: root

    required property var health        // Health.check()
    required property var events        // Health.events()

    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color mutedColor: Kirigami.Theme.disabledTextColor
    readonly property color dimColor: Qt.alpha(Kirigami.Theme.textColor, 0.35)
    readonly property color lineColor: Qt.alpha(Kirigami.Theme.textColor, 0.10)

    spacing: 14

    Tokens { id: tokens }

    function worst(notes) {
        for (const level of ["critical", "warning", "info"])
            if (notes.some(n => n.level === level))
                return level
        return ""
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 24

        // The score.
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 120
            spacing: 0
            Text {
                text: root.health.score
                color: root.health.score >= 80 ? root.textColor
                     : root.health.score >= 50 ? Kirigami.Theme.focusColor : Kirigami.Theme.negativeTextColor
                font.family: tokens.dotFont
                font.weight: tokens.dotWeight
                font.pixelSize: 56
            }
            Text {
                text: i18n("Health").toUpperCase()
                color: Kirigami.Theme.linkColor
                font.family: tokens.displayFont
                font.pixelSize: 13
                font.letterSpacing: 1
            }
            Text {
                text: root.health.notes.length === 0 ? i18n("Nothing to report")
                    : root.health.notes.length === 1 ? i18n("1 note") : i18n("%1 notes", root.health.notes.length)
                color: root.mutedColor
                font.family: tokens.uiFont
                font.pixelSize: 10
            }
        }

        // The categories, each with all of its notes.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Repeater {
                model: root.health.categories
                Rectangle {
                    id: category
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: rows.implicitHeight + 14
                    color: "transparent"
                    Rectangle {
                        visible: category.index > 0
                        width: parent.width
                        height: 1
                        color: root.lineColor
                    }
                    RowLayout {
                        id: rows
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        StatusMark {
                            Layout.alignment: Qt.AlignTop
                            level: root.worst(category.modelData.notes)
                        }
                        Text {
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: 100
                            text: category.modelData.name
                            color: root.textColor
                            font.family: tokens.uiFont
                            font.weight: Font.Medium
                            font.pixelSize: 12
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Repeater {
                                model: category.modelData.notes.length
                                    ? category.modelData.notes.map(n => n.text)
                                    : [category.modelData.summary]
                                Text {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    text: modelData
                                    wrapMode: Text.Wrap
                                    color: category.modelData.notes.length ? root.textColor : root.mutedColor
                                    font.family: tokens.uiFont
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Notable {
        Layout.fillWidth: true
        events: root.events
    }
}
