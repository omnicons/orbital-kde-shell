import QtQuick
import org.kde.ksysguard.sensors as Sensors

// Live readings from KDE's sensor service, and a rolling record of them taken
// every few seconds from the moment the bar loads, for the dashboard's graphs.
// It keeps six hours.
Item {
    id: history

    readonly property int interval: 5000
    readonly property int capacity: 6 * 3600 * 1000 / interval
    readonly property date started: new Date()

    // Oldest first; `times` holds a timestamp (ms) per sample.
    property var times: []
    property var series: ({ cpu: [], cpuTemp: [], cpuFreq: [], gpu: [], gpuTemp: [], vram: [],
                            ram: [], swap: [], netDown: [], netUp: [] })
    // Bumped after every sample; bind to it to redraw.
    property int revision: 0

    // Live values.
    readonly property real cpu: cpuSensor.value || 0
    readonly property real cpuTemp: cpuTempSensor.value || 0
    readonly property real cpuFreq: cpuFreqSensor.value || 0       // MHz
    readonly property real gpu: gpuSensor.value || 0
    readonly property real gpuTemp: gpuTempSensor.value || 0
    readonly property real vramUsed: vramUsedSensor.value || 0     // bytes
    readonly property real vramTotal: vramTotalSensor.value || 0
    readonly property string gpuName: gpuNameSensor.value || ""
    readonly property real ram: ramSensor.value || 0
    readonly property real ramUsed: ramUsedSensor.value || 0       // bytes
    readonly property real ramTotal: ramTotalSensor.value || 0
    readonly property real swap: swapSensor.value || 0
    readonly property real netDown: netDownSensor.value || 0       // bytes/s
    readonly property real netUp: netUpSensor.value || 0
    readonly property real diskRead: diskReadSensor.value || 0     // bytes/s
    readonly property real diskWrite: diskWriteSensor.value || 0
    readonly property string hostname: hostnameSensor.value || ""
    readonly property string os: osSensor.value || ""
    readonly property string kernel: kernelSensor.value || ""
    readonly property real uptime: uptimeSensor.value || 0         // seconds

    Sensors.Sensor { id: cpuSensor; sensorId: "cpu/all/usage"; updateRateLimit: 2000 }
    Sensors.Sensor { id: cpuTempSensor; sensorId: "cpu/all/averageTemperature"; updateRateLimit: 2000 }
    Sensors.Sensor { id: cpuFreqSensor; sensorId: "cpu/all/averageFrequency"; updateRateLimit: 2000 }
    Sensors.Sensor { id: gpuSensor; sensorId: "gpu/all/usage"; updateRateLimit: 2000 }
    Sensors.Sensor { id: gpuTempSensor; sensorId: "gpu/gpu0/temperature"; updateRateLimit: 2000 }
    Sensors.Sensor { id: vramUsedSensor; sensorId: "gpu/gpu0/usedVram"; updateRateLimit: 2000 }
    Sensors.Sensor { id: vramTotalSensor; sensorId: "gpu/all/totalVram"; updateRateLimit: 2000 }
    Sensors.Sensor { id: gpuNameSensor; sensorId: "gpu/gpu0/name"; updateRateLimit: 2000 }
    Sensors.Sensor { id: ramSensor; sensorId: "memory/physical/usedPercent"; updateRateLimit: 2000 }
    Sensors.Sensor { id: ramUsedSensor; sensorId: "memory/physical/used"; updateRateLimit: 2000 }
    Sensors.Sensor { id: ramTotalSensor; sensorId: "memory/physical/total"; updateRateLimit: 2000 }
    Sensors.Sensor { id: swapSensor; sensorId: "memory/swap/usedPercent"; updateRateLimit: 2000 }
    Sensors.Sensor { id: netDownSensor; sensorId: "network/all/download"; updateRateLimit: 2000 }
    Sensors.Sensor { id: diskReadSensor; sensorId: "disk/all/read"; updateRateLimit: 2000 }
    Sensors.Sensor { id: diskWriteSensor; sensorId: "disk/all/write"; updateRateLimit: 2000 }
    Sensors.Sensor { id: netUpSensor; sensorId: "network/all/upload"; updateRateLimit: 2000 }
    Sensors.Sensor { id: hostnameSensor; sensorId: "os/system/hostname"; updateRateLimit: 2000 }
    Sensors.Sensor { id: osSensor; sensorId: "os/system/prettyName"; updateRateLimit: 2000 }
    Sensors.Sensor { id: kernelSensor; sensorId: "os/kernel/prettyName"; updateRateLimit: 2000 }
    Sensors.Sensor { id: uptimeSensor; sensorId: "os/system/uptime"; updateRateLimit: 60000 }

    Timer {
        interval: history.interval
        running: true
        repeat: true
        onTriggered: {
            const values = { cpu: history.cpu, cpuTemp: history.cpuTemp, cpuFreq: history.cpuFreq,
                             gpu: history.gpu, gpuTemp: history.gpuTemp, vram: history.vramUsed,
                             ram: history.ram, swap: history.swap,
                             netDown: history.netDown, netUp: history.netUp }
            history.times.push(Date.now())
            for (const key in values)
                history.series[key].push(values[key])
            if (history.times.length > history.capacity) {
                history.times.shift()
                for (const key in values)
                    history.series[key].shift()
            }
            history.revision++
        }
    }
}
