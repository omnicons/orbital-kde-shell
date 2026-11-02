import QtQuick
import QtQuick.Window
import "../src/scene"

// Runs the real LockScreenUi.qml in a window, with a fake authenticator in
// place of kscreenlocker's. The password is "orbiter"; Ctrl+Q quits.
//   qml6 dev/lockscreen.qml
Window {
    width: 1600
    height: 900
    visible: true
    color: "black"
    title: "Orbiter lock screen"

    LockScreenUi {
        anchors.fill: parent
        userName: "demo"
        auth: QtObject {
            signal succeeded()
            signal failed(int kind)
            property bool hadPrompt: true
            property bool pamTimeout: false
            property bool unlocked: false
            property string infoMessage
            property string errorMessage
            property string prompt
            function startAuthenticating() {}
            function stopAuthenticating() {}
            function respond(password) {
                if (password === "orbiter")
                    succeeded()
                else
                    failed(0)
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+Q"
        onActivated: Qt.quit()
    }
}
