#!/usr/bin/env python3
"""Bakes src/theme/fastfetch/logo.txt: the wallpaper's ASCII Earth and Moon as
a still, for fastfetch. Shades the same textures with the same sun and glyph
ramp as src/scene, at terminal size. Each cell gets one of fastfetch's logo
colours, which config.jsonc maps to the terminal's named colours so the logo
follows variant switches like everything else in Konsole:
  $1 ocean (blue, the heading colour)   $2 land (yellow, the accent)
  $3 night side and stars (dim)         $4 clouds and the Moon (white)

  python3 tools/bake_fastfetch_logo.py src/theme/fastfetch/logo.txt
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
TEXTURES = ROOT / "src" / "scene" / "textures"
RAMP = " .-=+*#%@"                     # AsciiScene.qml's, darkest first
SUN = (-0.65, 0.55, 0.55)
COLS, ROWS = 38, 17                    # the logo's size in cells
ASPECT = 2.1                           # a cell's height over its width
EARTH = (15.5, 9.0, 12.5)              # centre column, centre row, radius in columns
MOON = (32.5, 3.5, 4.2)
SPIN, TILT = 0.9, 0.35                 # radians: Africa and Europe, the scene's tilt

earth = Image.open(TEXTURES / "earth.jpg").convert("RGB")
clouds = Image.open(TEXTURES / "earth_clouds.jpg").convert("L")
moon = Image.open(TEXTURES / "moon.jpg").convert("RGB")
length = math.sqrt(sum(c * c for c in SUN))
SUN = tuple(c / length for c in SUN)


def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def sample(image, s):
    """The texel under unit vector s, sphereUv() from scene.frag."""
    u = 0.5 + math.atan2(s[0], s[2]) / (2 * math.pi)
    v = 0.5 - math.asin(max(-1.0, min(1.0, s[1]))) / math.pi
    w, h = image.size
    return image.getpixel((int(u * w) % w, min(h - 1, int(v * h))))


def rotate(n, spin, tilt):
    x, y, z = n
    y, z = y * math.cos(tilt) - z * math.sin(tilt), y * math.sin(tilt) + z * math.cos(tilt)
    x, z = x * math.cos(spin) + z * math.sin(spin), -x * math.sin(spin) + z * math.cos(spin)
    return x, y, z


def normal(col, row, body):
    cx, cy, r = body
    x = (col + 0.5 - cx) / r
    y = -(row + 0.5 - cy) * ASPECT / r
    d = x * x + y * y
    return None if d > 1 else (x, y, math.sqrt(1 - d))


def glyph(lum):
    # Never blank inside a body, so the night side still shows the outline.
    return RAMP[max(1, min(len(RAMP) - 1, int(lum * len(RAMP))))]


def earth_cell(n):
    light = smoothstep(-0.35, 0.75, sum(a * b for a, b in zip(n, SUN)))
    s = rotate(n, SPIN, TILT)
    r, g, b = (0.64 * (c / 255) ** 0.55 for c in sample(earth, s))
    land = smoothstep(0.0, 0.12, r - b)
    cloud = smoothstep(0.1, 0.55, sample(clouds, s) / 255)
    lum = (0.3 * r + 0.5 * g + 0.2 * b) * (1 - cloud) + 0.87 * cloud
    lum *= 0.12 + 0.88 * light
    lum += 0.35 * (1 - n[2]) ** 2.5 * light   # the blue rim
    if light < 0.2:
        colour = 3
    elif cloud > 0.5:
        colour = 4
    elif land > 0.5:
        colour = 2
    else:
        colour = 1
    return glyph(lum * 1.15), colour


def moon_cell(n):
    light = smoothstep(-0.2, 0.8, sum(a * b for a, b in zip(n, SUN)))
    lum = sum(sample(moon, rotate(n, 0.0, 0.0))) / 765 * 0.6 * (0.08 + 0.92 * light)
    return glyph(lum * 1.6), 4 if light > 0.2 else 3


stars = random.Random(7)
lines = []
for row in range(ROWS):
    line, current = "", None
    for col in range(COLS):
        n = normal(col, row, EARTH)
        m = normal(col, row, MOON)
        if n:
            ch, colour = earth_cell(n)
        elif m:
            ch, colour = moon_cell(m)
        else:
            ch, colour = (stars.choice(".....+*") if stars.random() < 0.035 else " "), 3
        if ch != " " and colour != current:
            line += f"${colour}"
            current = colour
        line += ch
    lines.append(line.rstrip())

Path(sys.argv[1]).parent.mkdir(parents=True, exist_ok=True)
Path(sys.argv[1]).write_text("\n".join(lines) + "\n")
