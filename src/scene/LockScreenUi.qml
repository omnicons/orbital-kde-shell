import QtQuick
import org.kde.plasma.private.sessions

// Orbiter's lock screen. The authentication flow mirrors Plasma's stock
// LockScreenUi.qml; `auth` is kscreenlocker's authenticator, or a fake one in
// LockScreenDemo.qml.
Item {
    id: ui

    required property QtObject auth
    property string userName

    property date now: new Date()
    readonly property date lockedAt: new Date()
    property string notification
    // Set when a prompt-less authenticator (no password on the account)
    // succeeded: the user confirms with Enter instead of typing anything.
    property bool confirmUnlock: false
    property string pendingPassword

    function clearPassword() {
        password.text = ""
    }

    function showMessage(msg) {
        if (!msg)
            return
        notification = msg
        notificationTimer.restart()
        activity.uiVisible = true
    }

    function submit() {
        if (confirmUnlock) {
            Qt.quit()
            return
        }
        if (auth.pamTimeout) {
            pendingPassword = password.text
            password.enabled = false
        } else {
            auth.respond(password.text)
        }
    }

    Connections {
        target: ui.auth
        function onFailed(kind) {
            if (kind !== 0) // fingerprint, smartcard and friends report their own failures
                return
            ui.showMessage(qsTr("Unlocking failed"))
            ui.clearPassword()
            ui.auth.startAuthenticating()
            shake.restart()
        }
        function onSucceeded() {
            // Stops the remaining authenticators, preventing timeouts.
            ui.auth.stopAuthenticating()
            if (ui.auth.hadPrompt)
                Qt.quit()
            else
                ui.confirmUnlock = true
        }
        function onInfoMessageChanged() { ui.showMessage(ui.auth.infoMessage) }
        function onErrorMessageChanged() { ui.showMessage(ui.auth.errorMessage) }
        function onPromptChanged() { ui.showMessage(ui.auth.prompt) }
        function onPamTimeoutChanged() {
            if (!ui.auth.pamTimeout && ui.pendingPassword.length > 0) {
                ui.auth.respond(ui.pendingPassword)
                ui.pendingPassword = ""
                password.enabled = true
            }
        }
    }

    SessionManagement {
        id: sessionManagement
        onAboutToSuspend: ui.clearPassword()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: ui.now = new Date()
    }

    Timer {
        id: notificationTimer
        interval: 3000
        onTriggered: ui.notification = ""
    }

    component Label: Text {
        font.family: "IBM Plex Mono"
        font.pixelSize: 11
        font.letterSpacing: 1
        font.capitalization: Font.AllUppercase
        color: "#7c7c7c"
    }

    // Tracks activity: the prompt shows on mouse movement or a key press and
    // fades after ten idle seconds, as in the stock lock screen.
    MouseArea {
        id: activity

        property bool uiVisible: false
        property bool seenPositionChange: false

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: uiVisible ? Qt.ArrowCursor : Qt.BlankCursor
        onPressed: uiVisible = true
        onPositionChanged: {
            // The first event is the cursor appearing, not the user moving it.
            uiVisible = seenPositionChange
            seenPositionChange = true
        }
        onUiVisibleChanged: {
            if (uiVisible) {
                Window.window.requestActivate()
                fadeTimer.restart()
            }
            ui.auth.startAuthenticating()
        }

        Timer {
            id: fadeTimer
            interval: 10000
            onTriggered: {
                if (password.text.length === 0)
                    activity.uiVisible = false
            }
        }

        // Keeps the authenticators alive while the prompt is up.
        Timer {
            interval: 1000
            repeat: true
            running: activity.uiVisible && !ui.auth.unlocked
            onTriggered: ui.auth.startAuthenticating()
        }

        AsciiScene {
            anchors.fill: parent
            // The MouseArea above takes hover, so feed it the cursor directly.
            target: activity.containsMouse
                ? Qt.point(activity.mouseX / width * 2 - 1, 1 - activity.mouseY / height * 2)
                : Qt.point(0, 0)

            asciiContent: AsciiClock {
                anchors.fill: parent
                now: ui.now
            }
        }

        // Small UI text stays crisp, outside the ASCII pass.
        Label {
            id: dateLabel
            x: parent.width * 0.03 + 4
            y: parent.height * 0.08 - 6
            text: Qt.locale().toString(ui.now, "dddd d MMMM")
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.06
            width: lockedRow.implicitWidth + 24
            height: lockedRow.implicitHeight + 12
            radius: 4
            color: "#0c0c0c"
            border.color: "#2a2a2a"

            Row {
                id: lockedRow
                anchors.centerIn: parent
                spacing: 6
                Text {
                    text: qsTr("Locked")
                    font.family: "IBM Plex Mono"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: "#e0e0e0"
                }
                Text {
                    text: qsTr("since %1").arg(Qt.formatTime(ui.lockedAt, "HH:mm"))
                    font.family: "IBM Plex Mono"
                    font.pixelSize: 12
                    color: "#8a8a8a"
                }
            }
        }

        Column {
            id: prompt
            x: dateLabel.x
            y: parent.height * 0.3
            spacing: 8
            opacity: activity.uiVisible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }

            SequentialAnimation {
                id: shake
                loops: 2
                NumberAnimation { target: prompt; property: "x"; to: dateLabel.x - 8; duration: 50 }
                NumberAnimation { target: prompt; property: "x"; to: dateLabel.x + 8; duration: 100 }
                NumberAnimation { target: prompt; property: "x"; to: dateLabel.x; duration: 50 }
            }

            Row {
                spacing: 8
                visible: !ui.confirmUnlock
                Label { text: ">"; color: "#bdbdbd" }
                TextInput {
                    id: password
                    width: 260
                    focus: true
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    font.family: "IBM Plex Mono"
                    font.pixelSize: 11
                    color: "#d8d8d8"
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

                    Label {
                        x: 12
                        text: qsTr("Password")
                        color: "#4c4c4c"
                        visible: password.text.length === 0
                    }

                    onTextEdited: {
                        activity.uiVisible = true
                        fadeTimer.restart()
                    }
                    Keys.onReturnPressed: ui.submit()
                    Keys.onEnterPressed: ui.submit()
                    // kscreenlocker turns the screen off on Esc; clear the
                    // prompt so it isn't showing when the screen wakes.
                    Keys.onEscapePressed: {
                        activity.uiVisible = false
                        ui.clearPassword()
                    }
                    Keys.onPressed: event => {
                        activity.uiVisible = true
                        event.accepted = false
                    }
                }
            }

            Row {
                spacing: 24
                Label { text: "[" + qsTr("Enter") + "] " + qsTr("Unlock") }
                Label { text: "[" + qsTr("Esc") + "] " + qsTr("Hide") }
            }

            Label {
                text: ui.notification
                color: "#d08770"
                visible: text.length > 0
            }
        }

        Label {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 16
            text: qsTr("Switch user")
            visible: sessionManagement.canSwitchUser
            opacity: activity.uiVisible ? (switchUser.containsMouse ? 1 : 0.7) : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }

            MouseArea {
                id: switchUser
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                onClicked: sessionManagement.switchUser()
            }
        }
    }
}
