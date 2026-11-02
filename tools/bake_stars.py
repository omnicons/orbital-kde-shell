#!/usr/bin/env python3
"""Bakes the Yale Bright Star Catalogue into src/scene/textures/stars.png: an
equirectangular sky map, u = right ascension / 360°, v = 0.5 - declination /
180°, one texel per star, brightness by magnitude and a faint tint by colour.

  curl -LO http://tdc-www.harvard.edu/catalogs/bsc5.dat.gz && gunzip bsc5.dat.gz
  python3 tools/bake_stars.py bsc5.dat src/scene/textures/stars.png

The catalogue (5th revised edition, Hoffleit & Warren, 1991) is distributed
freely by NASA's Astronomical Data Center and the Harvard-Smithsonian CfA.
"""
import sys

from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
W, H = 8192, 4096
px = {}
count = 0
for line in open(src, encoding="latin-1"):
    try:
        ra = (int(line[75:77]) + int(line[77:79]) / 60 + float(line[79:83]) / 3600) * 15
        dec = int(line[84:86]) + int(line[86:88]) / 60 + int(line[88:90]) / 3600
        dec = -dec if line[83] == "-" else dec
        mag = float(line[102:107])
    except ValueError:
        continue  # a handful of entries (novae, galaxies) have no position
    try:
        bv = float(line[109:114])
    except ValueError:
        bv = 0.6
    lum = min(1.0, max(0.55, 1.05 - 0.08 * (mag + 1.5)))
    # Blue-white to orange by B-V, then mostly washed out to white.
    t = min(1.0, max(0.0, (bv + 0.3) / 1.8))
    tint = (0.8 + 0.2 * min(1, t * 2), 0.87 + 0.13 * (1 - abs(t - 0.5) * 2), 1.0 - 0.35 * max(0, t - 0.5) * 2)
    tint = [0.6 + 0.4 * c for c in tint]
    x = int(ra / 360 * W) % W
    y = min(H - 1, max(0, int((0.5 - dec / 180) * H)))
    rgb = tuple(c * lum for c in tint)
    if max(px.get((x, y), (0, 0, 0))) < max(rgb):
        px[(x, y)] = rgb
    count += 1

im = Image.new("RGB", (W, H))
for (x, y), rgb in px.items():
    im.putpixel((x, y), tuple(round(c * 255) for c in rgb))
im.save(dst, optimize=True)
print(count, "stars")
