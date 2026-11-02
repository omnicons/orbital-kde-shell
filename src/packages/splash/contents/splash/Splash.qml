import QtQuick

// Orbiter's Plasma splash, between the login screen and the desktop. The clock
// and date stay where the login screen had them, the prompt's place gets a
// status log, and near the end they fade so only the wallpaper's Earth is left.
// ksplashqml loads this once per screen and raises `stage` as Plasma starts.
Item {
    id: root

    property int stage: 0
    property date now: new Date()
    readonly property bool leaving: stage >= 5

    // One per stage. Stages only count up, and don't reliably mean the same
    // step on every start, so these don't claim to be particular services.
    readonly property var steps: ["PRESSURE SEAL", "ATTITUDE CONTROL", "NAV COMPUTER",
                                  "COMMS ARRAY", "HABITAT LIGHTS"]

    Tokens { id: tokens }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    component Label: Text {
        font.family: tokens.monoFont
        font.pixelSize: 11
        font.letterSpacing: 1
        font.capitalization: Font.AllUppercase
        color: "#7c7c7c"
    }

    AsciiScene {
        anchors.fill: parent
        // Nothing to follow here, and the wallpaper starts centred too.
        target: Qt.point(0, 0)
        asciiContent: AsciiClock {
            anchors.fill: parent
            now: root.now
            opacity: root.leaving ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }
    }

    // Small UI text stays crisp, outside the ASCII pass.
    Item {
        anchors.fill: parent
        opacity: root.leaving ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 400 } }

        Label {
            id: dateLabel
            x: parent.width * 0.03 + 4
            y: parent.height * 0.08 - 6
            text: Qt.locale().toString(root.now, "dddd d MMMM")
        }

        Column {
            x: dateLabel.x
            y: parent.height * 0.3
            spacing: 8

            Label {
                text: tokens.brand + " // SYSTEM START"
                color: "#eaa067"
            }

            Repeater {
                model: root.steps
                Label {
                    id: step
                    required property string modelData
                    required property int index
                    property int typed: 0
                    readonly property bool started: root.stage > index
                    readonly property bool finished: typed >= modelData.length

                    text: modelData.substring(0, typed) + (finished && root.stage > index + 1 ? "  [ OK ]" : "")
                    color: finished ? "#bdbdbd" : "#7c7c7c"

                    Timer {
                        interval: 18
                        repeat: true
                        running: step.started && !step.finished
                        onTriggered: step.typed++
                    }
                }
            }
        }
    }
}
