#!/usr/bin/env python3
"""Shrinks NASA's Earth, cloud and Moon maps to the sizes the scene uses
(the ASCII grid needs far less detail than the originals have).

  mkdir originals && cd originals
  curl -LO https://eoimages.gsfc.nasa.gov/images/imagerecords/57000/57752/land_shallow_topo_2048.jpg
  curl -LO https://eoimages.gsfc.nasa.gov/images/imagerecords/57000/57747/cloud_combined_2048.jpg
  curl -LO https://svs.gsfc.nasa.gov/vis/a000000/a004700/a004720/lroc_color_poles_1k.jpg
  cd .. && python3 tools/prep_textures.py originals src/scene/textures

Blue Marble land and clouds (NASA Earth Observatory) and the LRO Moon colour
map (NASA Scientific Visualization Studio) are public domain.
"""
import sys

from PIL import Image

src, out = sys.argv[1], sys.argv[2]
jobs = [("land_shallow_topo_2048.jpg", "earth.jpg", (1024, 512), "RGB"),
        ("cloud_combined_2048.jpg", "earth_clouds.jpg", (1024, 512), "L"),
        ("lroc_color_poles_1k.jpg", "moon.jpg", (512, 256), "RGB")]
for name, dst, size, mode in jobs:
    im = Image.open(f"{src}/{name}").convert(mode).resize(size, Image.LANCZOS)
    im.save(f"{out}/{dst}", quality=90)
    print(dst, im.size, im.mode)
