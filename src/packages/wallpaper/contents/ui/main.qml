import QtQuick
import org.kde.plasma.plasmoid
import org.kde.kwindowsystem
import org.kde.taskmanager as TaskManager

WallpaperItem {
    id: wallpaper

    // True while a maximised or fullscreen window on this screen hides the
    // wallpaper; the scene stops animating, and so stops rendering.
    readonly property bool covered: {
        // Show Desktop hides windows without minimising them.
        if (KWindowSystem.showingDesktop)
            return false
        for (let i = 0; i < coveringTasks.count; ++i) {
            const task = coveringTasks.itemAt(i)
            if (task && (task.maximized || task.fullScreen))
                return true
        }
        return false
    }

    AsciiScene {
        anchors.fill: parent
        animated: !wallpaper.covered
    }

    TaskManager.VirtualDesktopInfo { id: desktopInfo }
    TaskManager.ActivityInfo { id: activityInfo }

    // Windows that could be covering this wallpaper: on this screen, desktop
    // and activity, and not minimised.
    Repeater {
        id: coveringTasks
        model: TaskManager.TasksModel {
            groupMode: TaskManager.TasksModel.GroupDisabled
            filterByScreen: true
            screenGeometry: Qt.rect(wallpaper.Screen.virtualX, wallpaper.Screen.virtualY,
                                    wallpaper.Screen.width, wallpaper.Screen.height)
            filterByVirtualDesktop: true
            virtualDesktop: desktopInfo.currentDesktop
            filterByActivity: true
            activity: activityInfo.currentActivity
            filterMinimized: true
        }
        delegate: Item {
            required property var model
            readonly property bool maximized: model.IsMaximized
            readonly property bool fullScreen: model.IsFullScreen
        }
    }
}
