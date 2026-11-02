import QtQuick
import QtQuick.Window
import "../src/scene"

// The wallpaper's scene in a window, following the mouse. Build the shaders
// first (./orbiter install, or scripts/build-shaders.sh); Esc or Q quits.
//   qml6 dev/scene.qml
Window {
    width: 1600
    height: 900
    visible: true
    color: "black"
    title: "Orbiter prototype"

    AsciiScene {
        anchors.fill: parent
    }

    Shortcut {
        sequences: ["Esc", "Q"]
        onActivated: Qt.quit()
    }
}
