import QtQuick

// A preview of the Plymouth boot animation, played in a window and looped:
// the same images and timing the real theme will use, with sample service
// names. Positions are for a 3840x2400 screen, scaled. After ./orbiter install
// (which draws the images):
//   qml6 dev/boot-animation.qml
Window {
    id: root

    width: 1280
    height: 800
    visible: true
    color: "black"
    title: "Orbiter boot preview"

    readonly property real k: height / 2400
    readonly property string assets: Qt.resolvedUrl("../build/boot/plymouth/")
    readonly property real duration: 7.5
    property real t: 0                  // seconds since the splash appeared

    // Colours from the tokens (Black).
    readonly property color text: "#eceff3"
    readonly property color muted: "#8f9397"
    readonly property color dim: "#5b5f66"
    readonly property color accent: "#eaa067"
    readonly property color ok: "#8fb58a"
    readonly property color heading: "#b5baf1"

    // Playful lines while the kernel starts, then real services.
    readonly property var playful: [
        "POWER CORE", "CALIBRATING STAR CHARTS", "SPOOLING REACTOR",
        "HANDSHAKE WITH NAV COMPUTER", "WARMING DOT MATRIX",
    ]
    readonly property var services: [
        "Save/Restore Sound Card State", "Ananicy-Cpp - ANother Auto NICe daemon in C++",
        "Avahi mDNS/DNS-SD Stack", "Bluetooth service", "D-Bus System Message Bus",
        "IIO Sensor Proxy service", "Intel Linux Energy Optimizer (lpmd) Service",
        "Create List of Static Device Nodes", "NetBird mesh network client",
        "Network Manager", "Power Profiles daemon", "User Login Management",
        "Disk Manager", "Simple Desktop Display Manager",
    ]
    // [{ text, kind: "playful" | "service" | "final", at }]
    readonly property var lines: {
        const out = []
        playful.forEach((p, i) => out.push({ text: p, kind: "playful", at: 0.3 + i * 0.2 }))
        services.forEach((s, i) => out.push({ text: s, kind: "service", at: 1.3 + i * 0.3 }))
        out.push({ text: "ALL SYSTEMS NOMINAL // HANDING OFF TO LOGIN", kind: "final", at: 5.6 })
        return out
    }
    readonly property real progress: Math.min(1, t / 5.6)
    // No fade in: the splash starts at full brightness; it ends by cutting to the login screen.
    readonly property real fade: t > 6.6 ? 0 : 1

    Timer {
        interval: 33
        running: true
        repeat: true
        onTriggered: root.t = (root.t + 0.033) % root.duration
    }

    component Mono: Text {
        font.family: "IBM Plex Mono"
        font.pixelSize: 34 * root.k
        color: root.text
    }
    component Label: Text {
        font.family: "Share Tech Mono"
        font.pixelSize: 42 * root.k
        font.letterSpacing: 2 * root.k
        color: root.muted
    }

    Item {
        anchors.fill: parent
        opacity: root.fade

        // Mipmapped, or the fine grid aliases into grey when shrunk to the window.
        Image {
            anchors.fill: parent
            source: root.assets + "background.png"
            mipmap: true
        }

        // Top left: what's happening.
        Column {
            x: 150 * root.k
            y: 150 * root.k
            spacing: 14 * root.k
            Label { text: "ORBITER // BOOT SEQUENCE" }
            Mono {
                text: root.t < 1.3 ? "> STAGE 1 OF 3  KERNEL" : root.t < 5.6 ? "> STAGE 2 OF 3  SERVICES" : "> STAGE 3 OF 3  LOGIN"
                color: root.accent
                font.pixelSize: 30 * root.k
            }
        }

        // Top right: mission clock.
        Column {
            anchors.right: parent.right
            anchors.rightMargin: 150 * root.k
            y: 150 * root.k
            spacing: 14 * root.k
            Mono {
                anchors.right: parent.right
                text: "T+" + String(Math.floor(root.t / 60)).padStart(2, "0") + ":" + (root.t % 60).toFixed(2).padStart(5, "0")
                font.pixelSize: 42 * root.k
            }
            Label {
                anchors.right: parent.right
                text: "NODE ARCHON"
                font.pixelSize: 34 * root.k
            }
        }

        // The wordmark, dots arriving from t = 0.2 s, with the odd glitch.
        Item {
            id: mark
            x: 150 * root.k
            y: 560 * root.k
            width: wordmark.width
            height: wordmark.height
            readonly property int frame: Math.max(0, Math.min(23, Math.floor(root.t / 0.5 * 24)))
            readonly property bool glitching: root.t > 1 && (root.t % 2.7) < 0.09
            Image {
                anchors.fill: parent
                visible: mark.glitching
                x: 14 * root.k
                opacity: 0.8
                source: root.assets + "wordmark-glitch.png"
                transform: Translate { x: 14 * root.k }
            }
            Image {
                id: wordmark
                visible: true
                source: root.assets + "wordmark-" + String(mark.frame).padStart(2, "0") + ".png"
                width: sourceSize.width * root.k
                height: sourceSize.height * root.k
                transform: Translate { x: mark.glitching ? -8 * root.k : 0 }
            }
        }

        // The log: the latest nine lines, typed out as they arrive.
        Column {
            x: 150 * root.k
            y: 1020 * root.k
            spacing: 8 * root.k
            Repeater {
                model: {
                    const shown = root.lines.filter(l => l.at <= root.t)
                    return shown.slice(Math.max(0, shown.length - 9))
                }
                Row {
                    required property var modelData
                    required property int index
                    readonly property real age: root.t - modelData.at
                    readonly property int typed: Math.min(label.length, Math.floor(age * 70))
                    readonly property string label: modelData.kind === "service" ? "Started " + modelData.text : modelData.text
                    readonly property bool done: typed >= label.length && age > label.length / 70 + 0.12
                    spacing: 0
                    // Older lines dim, so the eye follows the newest.
                    opacity: 0.45 + 0.55 * (index + 1) / 9

                    Mono {
                        visible: modelData.kind === "service"
                        text: parent.done ? "[  OK  ] " : "[  ..  ] "
                        color: parent.done ? root.ok : root.dim
                    }
                    Mono {
                        visible: modelData.kind === "playful"
                        text: "> "
                        color: root.accent
                    }
                    Mono {
                        text: parent.label.slice(0, parent.typed)
                        color: modelData.kind === "final" ? root.accent : root.text
                    }
                    Mono {
                        visible: modelData.kind === "playful"
                        text: " " + ".".repeat(Math.max(2, 34 - parent.label.length)) + (parent.done ? " [ OK ]" : "")
                        color: parent.done ? root.ok : root.dim
                        opacity: parent.typed >= parent.label.length ? 1 : 0
                    }
                    // The cursor rides the newest line.
                    Rectangle {
                        visible: index === Math.min(8, root.lines.filter(l => l.at <= root.t).length - 1)
                                 && Math.floor(root.t * 3) % 2 === 0
                        width: 18 * root.k
                        height: 38 * root.k
                        color: root.accent
                    }
                }
            }
        }

        // Bottom: boot progress as block cells.
        Row {
            x: 150 * root.k
            y: 2130 * root.k
            spacing: 24 * root.k
            Label { text: "BOOT"; color: root.heading; anchors.verticalCenter: parent.verticalCenter }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.k
                Repeater {
                    model: 48
                    Item {
                        required property int index
                        readonly property bool on: index < Math.round(root.progress * 48)
                        width: 12 * root.k
                        height: 44 * root.k
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.on ? 12 * root.k : 6 * root.k
                            height: parent.on ? 44 * root.k : 6 * root.k
                            color: parent.on ? root.text : root.dim
                        }
                    }
                }
            }
            Mono {
                anchors.verticalCenter: parent.verticalCenter
                text: String(Math.round(root.progress * 100)).padStart(3, " ") + " %"
            }
        }
    }
}
