import QtQuick
import QtQuick.Effects

// The big clock. Assign it to AsciiScene's asciiContent so it goes through the
// ASCII pass along with the planet.
Item {
    property date now: new Date()

    Text {
        id: shape
        x: parent.width * 0.03
        y: parent.height * 0.08
        text: Qt.formatTime(parent.now, "HH:mm")
        font.family: "IBM Plex Mono"
        font.weight: Font.Bold
        font.pixelSize: parent.height * 0.16
        color: "white"
        visible: false
        layer.enabled: true
    }

    // Warm vertical gradient, so the digits run from @ at the top to * and =
    // toward the bottom.
    Rectangle {
        anchors.fill: shape
        gradient: Gradient {
            GradientStop { position: 0.2; color: "#f8d6bc" }
            GradientStop { position: 0.8; color: "#94624c" }
        }
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: shape
        }
    }
}
