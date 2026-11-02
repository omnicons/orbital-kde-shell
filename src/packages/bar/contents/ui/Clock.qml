import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.calendar as PlasmaCalendar

// SUN 1 NOV  17:23. Click for a month calendar.
Pill {
    id: pill

    property date now: new Date()

    Tokens { id: tokens }

    spacing: 10

    // Wakes once a minute, on the minute.
    Timer {
        id: tick
        running: true
        interval: 60000 - (Date.now() % 60000) + 50
        onTriggered: {
            pill.now = new Date()
            interval = 60000 - (Date.now() % 60000) + 50
            restart()
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        // Abbreviations lose their trailing dots: "SO 25 OKT", not "SO. 25. OKT.".
        text: Qt.locale().toString(pill.now, "ddd d MMM").replace(/\./g, "").toUpperCase()
        color: Kirigami.ColorUtils.linearInterpolation(pill.headingColor, pill.mutedColor, 0.5)
        font.family: tokens.displayFont
        font.pixelSize: 14
        font.letterSpacing: 1
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatTime(pill.now, "HH:mm")
        color: pill.textColor
        font.family: tokens.monoFont
        font.weight: Font.DemiBold
        font.pixelSize: 12
    }

    TapHandler {
        onTapped: calendar.visible = !calendar.visible
    }

    Popup {
        id: calendar
        visualParent: pill
        contentWidth: 320
        contentHeight: 300
        onVisibleChanged: if (visible) month.resetToToday()

        mainItem: PlasmaCalendar.MonthView {
            id: month
            today: pill.now
            showWeekNumbers: true
        }
    }
}
