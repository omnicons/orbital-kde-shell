import QtQuick

// Entry point kscreenlocker loads. The root's interface follows Plasma's
// stock LockScreen.qml.
Item {
    id: root

    property bool debug: false
    property string notification
    signal clearPassword()
    signal notificationRepeated()

    // These are magical properties that kscreenlocker looks for
    property bool viewVisible: false

    implicitWidth: 800
    implicitHeight: 600

    onClearPassword: lockUi.clearPassword()

    LockScreenUi {
        id: lockUi
        anchors.fill: parent
        auth: authenticator
        userName: kscreenlocker_userName
    }
}
