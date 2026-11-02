import QtQuick

// Orbiter's SDDM login screen: the lock screen's look, with user, session and
// power controls in place of the unlock prompt. SDDM loads this once per
// screen and provides `sddm`, `userModel`, `sessionModel` and `primaryScreen`.
Item {
    id: root

    width: 1600
    height: 900

    property date now: new Date()
    property string notification
    property int sessionIndex: Math.max(0, sessionModel.lastIndex)
    // SDDM's primaryScreen is just the output Qt lists first, so the installer
    // records the real one in theme.conf. Falls back if it isn't plugged in.
    readonly property string chosenOutput: typeof config === "undefined" ? "" : (config.primaryOutput || "")
    readonly property bool chosenConnected: {
        for (const screen of Qt.application.screens) {
            if (screen.name === chosenOutput)
                return true
        }
        return false
    }
    readonly property bool isPrimary: chosenConnected ? Screen.name === chosenOutput
                                                      : typeof primaryScreen === "undefined" || primaryScreen

    function login() {
        sddm.login(user.text, password.text, sessionIndex)
    }

    function showMessage(msg) {
        notification = msg
        notificationTimer.restart()
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.showMessage(qsTr("Login failed"))
            password.text = ""
            shake.restart()
        }
        function onInformationMessage(message) {
            root.showMessage(message)
        }
    }

    // Model data is only reachable through delegates, so read the names
    // through invisible repeaters.
    Repeater {
        id: sessions
        model: sessionModel
        Item { required property string name }
    }
    Repeater {
        id: users
        model: userModel
        Item { required property string name }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // SDDM activates the window on its own primary screen; typing has to reach
    // the one showing the prompt. Delayed so this comes after SDDM's request.
    Timer {
        interval: 300
        running: root.isPrimary && root.chosenConnected
        onTriggered: root.Window.window.requestActivate()
    }

    Timer {
        id: notificationTimer
        interval: 3000
        onTriggered: root.notification = ""
    }

    component Label: Text {
        font.family: "IBM Plex Mono"
        font.pixelSize: 11
        font.letterSpacing: 1
        font.capitalization: Font.AllUppercase
        color: "#7c7c7c"
    }

    component Action: Label {
        id: action
        signal clicked()
        opacity: actionArea.containsMouse ? 1 : 0.7
        MouseArea {
            id: actionArea
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            onClicked: action.clicked()
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true

        AsciiScene {
            anchors.fill: parent
            // The MouseArea above takes hover, so feed it the cursor directly.
            target: pointer.containsMouse
                ? Qt.point(pointer.mouseX / width * 2 - 1, 1 - pointer.mouseY / height * 2)
                : Qt.point(0, 0)
            asciiContent: AsciiClock {
                anchors.fill: parent
                now: root.now
            }
        }
    }

    // Small UI text stays crisp, outside the ASCII pass.
    Label {
        id: dateLabel
        x: parent.width * 0.03 + 4
        y: parent.height * 0.08 - 6
        text: Qt.locale().toString(root.now, "dddd d MMMM")
    }

    Column {
        id: prompt
        x: dateLabel.x
        y: parent.height * 0.3
        spacing: 8
        visible: root.isPrimary

        SequentialAnimation {
            id: shake
            loops: 2
            NumberAnimation { target: prompt; property: "x"; to: dateLabel.x - 8; duration: 50 }
            NumberAnimation { target: prompt; property: "x"; to: dateLabel.x + 8; duration: 100 }
            NumberAnimation { target: prompt; property: "x"; to: dateLabel.x; duration: 50 }
        }

        Row {
            spacing: 8
            Label { text: "@"; color: "#bdbdbd" }
            TextInput {
                id: user
                width: 260
                text: userModel.lastUser || (users.count > 0 ? users.itemAt(0).name : "")
                focus: text.length === 0
                font.family: "IBM Plex Mono"
                font.pixelSize: 11
                color: "#d8d8d8"
                selectByMouse: true
                KeyNavigation.tab: password
                Keys.onReturnPressed: password.forceActiveFocus()
                Keys.onEnterPressed: password.forceActiveFocus()

                Label {
                    text: qsTr("User")
                    color: "#4c4c4c"
                    visible: user.text.length === 0
                }
            }
        }

        Row {
            spacing: 8
            Label { text: ">"; color: "#bdbdbd" }
            TextInput {
                id: password
                width: 260
                focus: user.text.length > 0
                echoMode: TextInput.Password
                passwordCharacter: "•"
                font.family: "IBM Plex Mono"
                font.pixelSize: 11
                color: "#d8d8d8"
                KeyNavigation.backtab: user
                cursorDelegate: Rectangle {
                    width: 7
                    color: "#d8d8d8"
                    visible: password.activeFocus
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0; duration: 500; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutQuad }
                    }
                }
                Keys.onReturnPressed: root.login()
                Keys.onEnterPressed: root.login()

                Label {
                    x: 12
                    text: qsTr("Password")
                    color: "#4c4c4c"
                    visible: password.text.length === 0
                }
            }
        }

        Row {
            spacing: 24
            Label { text: "[" + qsTr("Enter") + "] " + qsTr("Log in") }
            Action {
                text: "[F2] " + (sessions.count > 0 ? sessions.itemAt(root.sessionIndex).name : "")
                onClicked: root.sessionIndex = (root.sessionIndex + 1) % sessions.count
            }
        }

        Label {
            text: root.notification
            color: "#d08770"
            visible: text.length > 0
        }
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        spacing: 24
        visible: root.isPrimary

        Action {
            text: qsTr("Suspend")
            visible: sddm.canSuspend
            onClicked: sddm.suspend()
        }
        Action {
            text: qsTr("Reboot")
            visible: sddm.canReboot
            onClicked: sddm.reboot()
        }
        Action {
            text: qsTr("Power off")
            visible: sddm.canPowerOff
            onClicked: sddm.powerOff()
        }
    }

    Shortcut {
        sequence: "F2"
        enabled: sessions.count > 0
        onActivated: root.sessionIndex = (root.sessionIndex + 1) % sessions.count
    }
}
