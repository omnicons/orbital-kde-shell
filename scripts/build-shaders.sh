#!/bin/sh
# Compiles the GLSL shaders to Qt 6 .qsb files.
set -e
# Everything runs from the repository root.
cd "$(dirname "$0")/.."
# Qt keeps its tools in /usr/lib/qt6/bin on Arch; Fedora links qsb-qt6 into /usr/bin.
if [ -z "$QSB" ]; then
    for candidate in /usr/lib/qt6/bin/qsb /usr/lib64/qt6/bin/qsb "$(command -v qsb-qt6)" "$(command -v qsb6)" "$(command -v qsb)"; do
        if [ -x "$candidate" ]; then QSB="$candidate"; break; fi
    done
fi
if [ -z "$QSB" ]; then
    echo "qsb (Qt's shader compiler) not found: install qt6-shadertools (Arch) or qt6-qtshadertools (Fedora), or set QSB." >&2
    exit 1
fi
for f in src/scene/shaders/*.frag; do
    "$QSB" --qt6 -o "$f.qsb" "$f"
done
