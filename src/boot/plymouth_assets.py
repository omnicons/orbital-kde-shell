#!/usr/bin/env python3
"""Draws the images Orbiter's Plymouth boot animation is made of, from
tokens.toml. Plymouth can't count on fonts this early in boot, so every
piece of text is an image:

  background.png     the dot grid, scanlines and corner brackets, as on
                     the Limine screen
  wordmark-NN.png    the brand name in dot-matrix type, lighting up dot by dot
  wordmark-glitch.png  the same in the accent colour, flashed offset for a
                     glitch now and then
  glyphs/<colour>-NNN.png   one printable ASCII character per file, for
                     composing the boot log at runtime
  label-*.png        the fixed text: headers, stage names, the node name
  cell-on.png, cell-off.png, cursor.png, black.png
  orbiter.script, orbiter.plymouth   the theme, from src/boot/orbiter.script.in

Sizes are for a 2400 px tall screen; the script scales them to the real one.
Writes build/boot/plymouth/.
"""
import random
import socket
import sys
from pathlib import Path

SRC = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SRC))
import tokens as design_tokens  # noqa: E402  (src/tokens.py)

ROOT = SRC.parent

from PIL import Image, ImageDraw, ImageFont  # noqa: E402
import system_fonts  # noqa: E402  (src/boot/system_fonts.py)

OUT = ROOT / "build" / "boot" / "plymouth"
FONTS = SRC / "theme" / "fonts"

WORDMARK_FRAMES = 24
WORDMARK_SIZE = 260
GLYPH_SIZE = 34


def rgb(hex_colour, alpha=255):
    h = hex_colour.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def dots(image):
    """The separate dots of a dot-matrix rendering, as lists of pixels."""
    alpha = image.getchannel("A").load()
    w, h = image.size
    seen = set()
    found = []
    for y in range(h):
        for x in range(w):
            if alpha[x, y] < 40 or (x, y) in seen:
                continue
            stack, pixels = [(x, y)], []
            seen.add((x, y))
            while stack:
                px, py = stack.pop()
                pixels.append((px, py))
                for nx, ny in ((px + 1, py), (px - 1, py), (px, py + 1), (px, py - 1)):
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and alpha[nx, ny] >= 40:
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            found.append(pixels)
    return found


def wordmark(v, brand):
    """The brand in dots, lighting up one whole dot at a time in random order."""
    f = ImageFont.truetype(str(FONTS / "Doto.ttf"), WORDMARK_SIZE)
    f.set_variation_by_name("Bold")
    left, top, right, bottom = f.getbbox(brand)
    pad = 12
    full = Image.new("RGBA", (right - left + pad * 2, bottom - top + pad * 2), (0, 0, 0, 0))
    ImageDraw.Draw(full).text((pad - left, pad - top), brand, font=f, fill=rgb(v["heading"]))

    order = dots(full)
    random.Random(3).shuffle(order)
    frames = []
    for n in range(1, WORDMARK_FRAMES + 1):
        # Ease out: most dots arrive early, the last few trickle in.
        shown = round(len(order) * (1 - (1 - n / WORDMARK_FRAMES) ** 2))
        mask = Image.new("L", full.size, 0)
        pixels = mask.load()
        for dot in order[:shown]:
            for xy in dot:
                pixels[xy] = 255
        frame = Image.new("RGBA", full.size, (0, 0, 0, 0))
        frame.paste(full, (0, 0), mask)
        frames.append(frame)
    glitch = Image.new("RGBA", full.size, rgb(v["accent"]))
    glitch.putalpha(full.getchannel("A"))
    return frames, glitch


def background(v, width=3840, height=2400):
    image = Image.new("RGBA", (width, height), rgb(v["bar"]))
    # Translucent marks go on an overlay and are blended in; drawn straight
    # onto the image they'd replace the pixels at full strength.
    overlay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    for gx in range(24, width, 48):
        for gy in range(24, height, 48):
            d.rectangle((gx, gy, gx + 2, gy + 2), fill=rgb(v["text"], 14))
    for sy in range(0, height, 6):
        d.line((0, sy, width, sy), fill=rgb(v["text"], 5))
    inset, arm, w = 80, 70, 5
    for cx, cy, dx, dy in ((inset, inset, 1, 1), (width - inset, inset, -1, 1),
                           (inset, height - inset, 1, -1), (width - inset, height - inset, -1, -1)):
        d.line((cx, cy, cx + dx * arm, cy), fill=rgb(v["accent"]), width=w)
        d.line((cx, cy, cx, cy + dy * arm), fill=rgb(v["accent"]), width=w)
    image.alpha_composite(overlay)
    return image.convert("RGB")


def glyphs(v):
    """Every printable ASCII character in Plex Mono, once per log colour, all
    on the same fixed-size cell so lines can be laid out by index."""
    regular = ImageFont.truetype(system_fonts.plex_mono(), GLYPH_SIZE)
    advance = round(regular.getlength("M"))
    ascent, descent = regular.getmetrics()
    colours = {"text": v["text"], "muted": v["muted"], "dim": v["ansi"][8],
               "accent": v["accent"], "ok": v["positive"], "heading": v["heading"]}
    out = {}
    for name, colour in colours.items():
        for code in range(32, 127):
            cell = Image.new("RGBA", (advance, ascent + descent), (0, 0, 0, 0))
            ImageDraw.Draw(cell).text((0, 0), chr(code), font=regular, fill=rgb(colour))
            out[f"{name}-{code:03d}.png"] = cell
    return out, (advance, ascent + descent)


def labels(v, brand, host):
    """Fixed strings, in the display font: (file, text, size, colour)."""
    display = lambda size: ImageFont.truetype(str(FONTS / "ShareTechMono-Regular.ttf"), size)
    mono = lambda size: ImageFont.truetype(system_fonts.plex_mono(), size)
    specs = [
        ("label-header-boot.png", f"{brand} // BOOT SEQUENCE", display(42), v["muted"]),
        ("label-header-shutdown.png", f"{brand} // SHUTDOWN SEQUENCE", display(42), v["muted"]),
        ("label-node.png", f"NODE {host.upper()}", display(34), v["muted"]),
        ("label-stage-kernel.png", "> STAGE 1 OF 3  KERNEL", mono(30), v["accent"]),
        ("label-stage-services.png", "> STAGE 2 OF 3  SERVICES", mono(30), v["accent"]),
        ("label-stage-login.png", "> STAGE 3 OF 3  LOGIN", mono(30), v["accent"]),
        ("label-stage-shutdown.png", "> POWERING DOWN", mono(30), v["accent"]),
        ("label-boot.png", "BOOT", display(42), v["heading"]),
    ]
    out = {}
    for name, words, f, colour in specs:
        left, top, right, bottom = f.getbbox(words)
        image = Image.new("RGBA", (right + 4, bottom + 4), (0, 0, 0, 0))
        ImageDraw.Draw(image).text((0, 0), words, font=f, fill=rgb(colour))
        out[name] = image
    return out


def shapes(v):
    """Progress cells (a bar, or a dot when empty), the cursor, and black."""
    on = Image.new("RGBA", (12, 44), rgb(v["text"]))
    off = Image.new("RGBA", (12, 44), (0, 0, 0, 0))
    ImageDraw.Draw(off).rectangle((3, 19, 8, 24), fill=rgb(v["ansi"][8]))
    cursor = Image.new("RGBA", (18, 38), rgb(v["accent"]))
    black = Image.new("RGBA", (4, 4), (0, 0, 0, 255))
    return {"cell-on.png": on, "cell-off.png": off, "cursor.png": cursor, "black.png": black}


def script(template, glyph_size):
    """The theme script: the template with the character table filled in.
    Plymouth's script language can't turn a character into its code, so the
    table maps each one to its glyph file. Quote and backslash are left out
    (they'd need escaping) and show as '?'."""
    table = "\n".join(f'glyph_file["{chr(c)}"] = "{c:03d}";'
                       for c in range(32, 127) if chr(c) not in '"\\')
    return (template.replace("@GLYPH_TABLE@", table)
                    .replace("@GLYPH_W@", str(glyph_size[0]))
                    .replace("@GLYPH_H@", str(glyph_size[1])))


THEME_FILE = """[Plymouth Theme]
Name=Orbiter
Description=Orbiter's boot sequence: a dot-matrix wordmark, a typed-out boot log and block-cell progress
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/orbiter
ScriptFile=/usr/share/plymouth/themes/orbiter/orbiter.script
"""


def main():
    tokens = design_tokens.load()
    v = tokens["variants"]["black"]
    brand = tokens["brand"]["name"].upper()
    OUT.mkdir(parents=True, exist_ok=True)
    frames, glitch = wordmark(v, brand)
    for i, frame in enumerate(frames):
        frame.save(OUT / f"wordmark-{i:02d}.png", optimize=True)
    glitch.save(OUT / "wordmark-glitch.png", optimize=True)
    background(v).save(OUT / "background.png", optimize=True)
    (OUT / "glyphs").mkdir(exist_ok=True)
    cells, size = glyphs(v)
    for name, image in cells.items():
        image.save(OUT / "glyphs" / name, optimize=True)
    for name, image in {**labels(v, brand, socket.gethostname()), **shapes(v)}.items():
        image.save(OUT / name, optimize=True)
    template = (SRC / "boot" / "orbiter.script.in").read_text()
    (OUT / "orbiter.script").write_text(script(template, size))
    (OUT / "orbiter.plymouth").write_text(THEME_FILE)
    print(f"{WORDMARK_FRAMES} wordmark frames, {len(cells)} glyphs of {size[0]}x{size[1]}")


if __name__ == "__main__":
    main()
