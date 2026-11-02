#!/bin/sh
# Builds the shaders and theme, assembles the Plasma packages under build/
# with the shared scene copied into each, and installs (or upgrades) them
# for the current user. The first run also adds the top bar's panel.
set -e
# Everything runs from the repository root.
cd "$(dirname "$0")/.."
./scripts/build-shaders.sh

rm -rf build
mkdir -p build
# Colour schemes, the Plasma style and Tokens.qml, into build/theme.
python3 src/theme/generate.py

# $1: package name under src/packages/, $2: directory inside it that gets the scene
assemble() {
    cp -r "src/packages/$1" "build/$1"
    mkdir -p "build/$1/$2/shaders"
    cp src/scene/AsciiScene.qml src/scene/AsciiClock.qml "build/$1/$2/"
    cp src/scene/shaders/*.qsb "build/$1/$2/shaders/"
    cp -r src/scene/textures "build/$1/$2/"
}

assemble wallpaper contents/ui
assemble lockscreen contents/lockscreen
cp src/scene/LockScreenUi.qml build/lockscreen/contents/lockscreen/
# SDDM themes live in /usr/share; install-sddm.sh copies this one there as root.
assemble sddm .
assemble splash contents/splash
cp build/theme/Tokens.qml build/splash/contents/splash/
# Boot theme images and config, sized for this screen; install-boot.sh
# installs them as root.
size="$(tr , x < /sys/class/graphics/fb0/virtual_size 2>/dev/null || echo 3840x2400)"
python3 src/boot/limine_wallpaper.py --size "$size"
python3 src/boot/grub_theme.py --size "$size"
python3 src/boot/plymouth_assets.py >/dev/null
# The bar doesn't use the scene, only the tokens.
cp -r src/packages/bar build/bar
cp build/theme/Tokens.qml build/bar/contents/ui/

# $1: package type, $2: package name under build/
install_package() {
    kpackagetool6 --type "$1" --upgrade "build/$2" >/dev/null 2>&1 \
        || kpackagetool6 --type "$1" --install "build/$2"
}

install_package Plasma/Wallpaper wallpaper
install_package Plasma/Shell lockscreen
install_package Plasma/Applet bar
install_package Plasma/LookAndFeel splash

# Puts the bar in its own top panel the first time; later runs leave the
# panel, and wherever you've moved it, alone. Meta+Space opens the launcher
# unless the bar already has a shortcut.
busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s '
    const exists = panels().some(p => p.widgets("org.orbiter.bar").length > 0)
    if (!exists) {
        const panel = new Panel("org.kde.panel")
        panel.location = "top"
        panel.height = 30
        panel.floating = false
        panel.hiding = "none"
        panel.addWidget("org.orbiter.bar")
    }
    for (const panel of panels())
        for (const bar of panel.widgets("org.orbiter.bar"))
            if (!bar.globalShortcut)
                bar.globalShortcut = "Meta+Space"
' >/dev/null
# Other panels (a default install's taskbar) keep a background of their own.
./scripts/taskbar.sh keep

# The first install also makes Orbiter the wallpaper on every desktop; later
# runs leave whatever wallpaper you've picked since.
marker="${XDG_DATA_HOME:-$HOME/.local/share}/orbiter/wallpaper-set"
if [ ! -f "$marker" ]; then
    busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s '
        for (const desktop of desktops())
            desktop.wallpaperPlugin = "org.orbiter.wallpaper"
    ' >/dev/null
    mkdir -p "$(dirname "$marker")"
    touch "$marker"
fi
