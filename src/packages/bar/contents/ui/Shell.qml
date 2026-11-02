import QtQuick
import org.kde.plasma.plasma5support as P5Support

// Runs shell commands and hands each one's output to a callback:
//   shell.run("uptime", (stdout, exitCode) => ...)
// A command already running isn't started twice.
P5Support.DataSource {
    id: shell

    property var callbacks: ({})

    function run(command, callback) {
        if (command in callbacks)
            return
        callbacks[command] = callback || null
        connectSource(command)
    }

    engine: "executable"
    onNewData: (source, data) => {
        const callback = callbacks[source]
        delete callbacks[source]
        disconnectSource(source)
        if (callback)
            callback(data.stdout || "", data["exit code"])
    }
}
