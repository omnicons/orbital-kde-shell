import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

// The whole top bar is one widget filling a transparent panel; it draws its
// own pills, so the panel itself draws nothing. The widget's global shortcut
// (Meta+Space, set by install.sh) opens the launcher.
PlasmoidItem {
    id: plasmoid

    signal launcherToggled()

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.constraintHints: Plasmoid.CanFillArea
    preferredRepresentation: fullRepresentation
    activationTogglesExpanded: false

    Connections {
        target: Plasmoid
        function onActivated() {
            plasmoid.launcherToggled()
        }
    }

    fullRepresentation: Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: left.implicitWidth + clock.implicitWidth + right.implicitWidth + 32

        Tokens { id: tokens }

        Row {
            id: left
            x: tokens.barGap * 2
            y: tokens.barGap
            spacing: tokens.barGap
            Workspaces {
                onLauncherRequested: launcherPopup.visible = !launcherPopup.visible
            }
            Activity {}
        }

        Clock {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            y: tokens.barGap
        }

        Connections {
            target: plasmoid
            function onLauncherToggled() {
                launcherPopup.visible = !launcherPopup.visible
            }
        }

        // Wide, under the clock.
        Popup {
            id: launcherPopup
            visualParent: clock
            contentWidth: Math.min(1000, Math.round(clock.Screen.width * 0.55))
            onVisibleChanged: {
                if (!visible)
                    return
                requestActivate()
                launcher.reset()
            }

            mainItem: Launcher {
                id: launcher
                onDone: launcherPopup.visible = false
            }
        }

        Row {
            id: right
            anchors.right: parent.right
            anchors.rightMargin: tokens.barGap * 2
            y: tokens.barGap
            spacing: tokens.barGap
            Status {}
        }
    }
}
