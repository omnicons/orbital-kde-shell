import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.milou as Milou

// The launcher: one search field for apps and KRunner actions (settings,
// calculator, files, commands...).
//   ↑↓ select · Enter open · Tab filter · Esc close
ColumnLayout {
    id: root

    signal done()

    property alias query: input.text

    // "all" searches every KRunner plugin, "apps" only applications.
    property string filter: "all"
    readonly property var filters: [
        { key: "all", label: i18n("All") },
        { key: "apps", label: i18n("Apps") },
    ]

    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color mutedColor: Kirigami.Theme.disabledTextColor
    readonly property color dimColor: Qt.alpha(Kirigami.Theme.textColor, 0.35)
    readonly property color lineColor: Qt.alpha(Kirigami.Theme.textColor, 0.10)
    readonly property color cardColor: Kirigami.Theme.alternateBackgroundColor

    spacing: 8

    Tokens { id: tokens }

    // Called when the popup opens.
    function reset() {
        input.text = ""
        filter = "all"
        list.currentIndex = 0
        input.forceActiveFocus()
    }

    function activate(index) {
        if (results.run(results.index(index, 0)))
            done()
    }

    function cycleFilter() {
        const i = filters.findIndex(f => f.key === filter)
        filter = filters[(i + 1) % filters.length].key
    }

    Milou.ResultsModel {
        id: results
        queryString: input.text
        singleRunner: root.filter === "apps" ? "krunner_services" : ""
        limit: 12
    }

    // [⊞ All]  Apps and actions ...
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
            Layout.preferredHeight: 28
            Layout.preferredWidth: chip.implicitWidth + 16
            color: chipArea.containsMouse ? Qt.lighter(root.cardColor, 1.3) : root.cardColor
            border.width: 1
            border.color: root.lineColor
            Row {
                id: chip
                anchors.centerIn: parent
                spacing: 6
                Kirigami.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    source: "view-app-grid-symbolic"
                    isMask: true
                    color: root.textColor
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.filters.find(f => f.key === root.filter).label
                    color: root.textColor
                    font.family: tokens.uiFont
                    font.weight: Font.Medium
                    font.pixelSize: 12
                }
            }
            MouseArea {
                id: chipArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    root.cycleFilter()
                    input.forceActiveFocus()
                }
            }
        }

        TextInput {
            id: input
            Layout.fillWidth: true
            color: root.textColor
            selectionColor: Kirigami.Theme.highlightColor
            selectedTextColor: Kirigami.Theme.highlightedTextColor
            font.family: tokens.uiFont
            font.pixelSize: 16
            clip: true
            focus: true
            onTextChanged: list.currentIndex = 0

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text.length === 0
                text: i18n("Apps and actions …")
                color: root.dimColor
                font: input.font
            }

            Keys.onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
            Keys.onDownPressed: list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1)
            Keys.onTabPressed: root.cycleFilter()
            Keys.onEscapePressed: root.done()
            Keys.onReturnPressed: root.activate(list.currentIndex)
            Keys.onEnterPressed: root.activate(list.currentIndex)
        }
    }

    // Results.
    ListView {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 8 * 40)
        visible: input.text.length > 0
        clip: true
        model: results
        currentIndex: 0
        highlightMoveDuration: 0
        boundsBehavior: Flickable.StopAtBounds

        delegate: ResultRow {
            required property int index
            required property var model
            width: ListView.view.width
            height: 40
            current: ListView.isCurrentItem
            icon: model.decoration
            title: model.display
            subtitle: model.subtext || ""
            tag: model.category || ""
            onClicked: root.activate(index)
            onHovered: list.currentIndex = index
        }
    }

    Text {
        Layout.fillWidth: true
        text: i18n("↑↓ select · Enter open · Tab filter · Esc close")
        color: root.dimColor
        font.family: tokens.monoFont
        font.pixelSize: 10
    }
}
