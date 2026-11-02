import QtQuick

// The reusable core: a space scene drawn as ASCII, shared by the wallpaper
// and the lock screen. It animates itself and eases the view toward the
// cursor; turn `animated` off to drive `time` and `mouse` from outside.
Item {
    id: root

    property bool animated: true
    property real maxFps: 30
    property real time: 0
    property point mouse: Qt.point(0, 0)   // smoothed, -1..1, y up
    // Where the view drifts toward, -1..1, y up. Follows the cursor by default;
    // bind it yourself when something on top swallows hover events.
    property point target: hover.hovered
        ? Qt.point(hover.point.position.x / width * 2 - 1, 1 - hover.point.position.y / height * 2)
        : Qt.point(0, 0)
    // Items assigned here are drawn into the same grid as the planet, so they
    // turn into characters too (the lock screen's clock, for example).
    property alias asciiContent: asciiLayer.data
    property string ramp: " .-=+*#%@"      // darkest to brightest
    property string fontFamily: "IBM Plex Mono"
    property int fontSize: 8
    property real lineHeight: 0.9           // the reference packs rows tightly
    property real gain: 1.0

    // A property, not advanceWidth(): method calls don't re-run when the font changes.
    readonly property real cellWidth: Math.ceil(metrics.averageCharacterWidth)
    readonly property real cellHeight: Math.ceil(metrics.height * lineHeight)
    readonly property int columns: Math.max(1, Math.floor(width / cellWidth))
    readonly property int rows: Math.max(1, Math.floor(height / cellHeight))

    FontMetrics {
        id: metrics
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
        font.weight: Font.Medium
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    // Pass 1 renders at one pixel per cell, so the scene shader stays cheap.
    ShaderEffect {
        id: scene
        width: root.columns
        height: root.rows
        property real time: root.time
        property real aspect: (root.columns * root.cellWidth) / (root.rows * root.cellHeight)
        property size grid: Qt.size(root.columns, root.rows)
        property point mouse: root.mouse
        property var earthMap: earthImage
        property var cloudMap: cloudImage
        property var moonMap: moonImage
        property var starMap: starImage
        fragmentShader: Qt.resolvedUrl("shaders/scene.frag.qsb")
    }

    // NASA imagery (public domain): Blue Marble, its cloud layer, and LRO's Moon.
    Image { id: earthImage; source: Qt.resolvedUrl("textures/earth.jpg"); visible: false }
    Image { id: cloudImage; source: Qt.resolvedUrl("textures/earth_clouds.jpg"); visible: false }
    Image { id: moonImage; source: Qt.resolvedUrl("textures/moon.jpg"); visible: false }
    // Yale Bright Star Catalogue, one texel per star; unfiltered so stars stay crisp.
    Image { id: starImage; source: Qt.resolvedUrl("textures/stars.png"); visible: false; smooth: false }

    ShaderEffectSource {
        id: sceneTexture
        sourceItem: scene
        // Exactly one pixel per cell, whatever the display scale, so every
        // sample sits at a cell centre.
        textureSize: Qt.size(root.columns, root.rows)
        hideSource: true
        smooth: false
    }

    Item {
        id: asciiLayer
        width: root.width
        height: root.height
    }

    ShaderEffectSource {
        id: asciiLayerTexture
        sourceItem: asciiLayer
        textureSize: Qt.size(root.columns, root.rows)
        hideSource: true
    }

    // One cell per ramp character, rendered once into a texture.
    Row {
        id: atlasRow
        Repeater {
            model: root.ramp.length
            Text {
                width: root.cellWidth
                height: root.cellHeight
                text: root.ramp.charAt(index)
                color: "white"
                font: metrics.font
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    ShaderEffectSource {
        id: atlasTexture
        sourceItem: atlasRow
        hideSource: true
        live: false
    }

    // Pass 2 swaps every cell for a glyph.
    ShaderEffect {
        anchors.centerIn: parent
        width: root.columns * root.cellWidth
        height: root.rows * root.cellHeight
        property var source: sceneTexture
        property var atlas: atlasTexture
        property var overlay: asciiLayerTexture
        property size grid: Qt.size(root.columns, root.rows)
        property real glyphCount: root.ramp.length
        property real gain: root.gain
        fragmentShader: Qt.resolvedUrl("shaders/ascii.frag.qsb")
    }

    // Passive: it never blocks clicks or hover for anything else.
    HoverHandler {
        id: hover
    }

    // A timer rather than FrameAnimation: the planet moves slowly enough that
    // 30 fps looks the same, and the renderer only wakes when something changed
    // instead of on every display refresh.
    Timer {
        property real last: 0
        interval: 1000 / root.maxFps
        repeat: true
        running: root.animated
        onRunningChanged: last = Date.now()
        onTriggered: {
            const now = Date.now()
            // Capped, so the scene resumes where it paused instead of jumping.
            const dt = Math.min((now - last) / 1000, 0.1)
            last = now
            root.time += dt
            // Ease toward the target rather than snapping to it.
            const k = 1 - Math.exp(-dt * 2.5)
            root.mouse = Qt.point(root.mouse.x + (root.target.x - root.mouse.x) * k,
                                  root.mouse.y + (root.target.y - root.mouse.y) * k)
        }
    }
}
