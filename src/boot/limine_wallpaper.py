#!/usr/bin/env python3
"""Draws Orbiter's Limine wallpaper, a cyberpunk "boot select" HUD, and the
matching limine.conf theme lines, from tokens.toml.

Limine's menu is a text grid inset from the screen edge by `term_margin`, so
the wallpaper frames exactly that rectangle and keeps its decoration in the
margin around it.

  limine_wallpaper.py [--size WxH] [--host NAME] [--preview]

Writes build/boot/limine/: wallpaper.png, theme.conf, and with --preview a
mock of the whole screen with the menu drawn in (preview.png).
"""
import argparse
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

OUT = ROOT / "build" / "boot" / "limine"
FONTS = SRC / "theme" / "fonts"

# Layout, as fractions of the screen so any resolution works.
MARGIN_X = 0.19          # the menu's inset from the left and right edges
MARGIN_Y = 0.25          # ...and from the top and bottom
CELL_W, CELL_H = 9, 16   # Limine's font, before scaling
# Below 16 text rows Limine drops the whole graphical theme, wallpaper included,
# and shows a plain menu. Keep a couple spare.
MIN_ROWS = 18


def rgb(hex_colour, alpha=255):
    h = hex_colour.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def font(name, size, variation=None):
    path = {"display": FONTS / "ShareTechMono-Regular.ttf",
            "dot": FONTS / "Doto.ttf",
            "mono": system_fonts.plex_mono(),
            "mono-bold": system_fonts.plex_mono(bold=True)}[name]
    f = ImageFont.truetype(str(path), size)
    if variation:
        f.set_variation_by_name(variation)
    return f


def font_scale(height):
    """Limine's font scale, keeping text the same share of the screen height."""
    return max(1, round(height / 800))


def layout(width, height):
    """Limine applies one margin on all sides; returns it and the menu box."""
    margin = round(min(width * MARGIN_X, height * MARGIN_Y))
    margin = max(0, min(margin, (height - MIN_ROWS * CELL_H * font_scale(height)) // 2))
    return margin, (margin, margin, width - margin, height - margin)


def draw_wallpaper(width, height, v, host, brand, box=None):
    """The HUD, framing `box` (x0, y0, x1, y1), by default Limine's menu area.
    The GRUB theme passes its own menu box."""
    s = height / 2400            # sizes below are for a 2400 px tall screen
    px = lambda n: max(1, round(n * s))
    image = Image.new("RGBA", (width, height), rgb(v["bar"]))
    overlay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    text, muted, heading, accent = v["text"], v["muted"], v["heading"], v["accent"]
    x0, y0, x1, y1 = box or layout(width, height)[1]

    # A dot grid over everything, and faint scanlines.
    step = px(48)
    for gx in range(step // 2, width, step):
        for gy in range(step // 2, height, step):
            d.rectangle((gx, gy, gx + px(2), gy + px(2)), fill=rgb(text, 14))
    for sy in range(0, height, px(6)):
        d.line((0, sy, width, sy), fill=rgb(text, 5))

    # Scattered crosshairs, as on the dashboard's panels.
    rng = random.Random(7)
    for _ in range(26):
        cx, cy = rng.randrange(width), rng.randrange(height)
        if x0 - px(40) < cx < x1 + px(40) and y0 - px(40) < cy < y1 + px(40):
            continue
        arm = px(9)
        d.line((cx - arm, cy, cx + arm, cy), fill=rgb(text, 60), width=px(2))
        d.line((cx, cy - arm, cx, cy + arm), fill=rgb(text, 60), width=px(2))

    # The menu's frame: a dark panel, a hairline, accent corner brackets.
    pad = px(28)
    fx0, fy0, fx1, fy1 = x0 - pad, y0 - pad, x1 + pad, y1 + pad
    d.rectangle((fx0, fy0, fx1, fy1), fill=rgb(v["window"], 200), outline=rgb(text, 34), width=px(2))
    arm, w = px(56), px(5)
    for cx, cy, dx, dy in ((fx0, fy0, 1, 1), (fx1, fy0, -1, 1), (fx0, fy1, 1, -1), (fx1, fy1, -1, -1)):
        d.line((cx, cy, cx + dx * arm, cy), fill=rgb(accent), width=w)
        d.line((cx, cy, cx, cy + dy * arm), fill=rgb(accent), width=w)

    label = font("display", px(38))
    # Tabs sitting on the frame's top edge.
    def tab(x, y, words, colour):
        bbox = d.textbbox((0, 0), words, font=label)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        d.rectangle((x - px(14), y - th // 2 - px(12), x + tw + px(14), y + th // 2 + px(14)), fill=rgb(v["bar"]))
        d.text((x, y), words, font=label, fill=colour, anchor="lm")
        return tw
    tab(fx0 + px(90), fy0, "[ SELECT BOOT IMAGE ]", rgb(accent))
    words = f"NODE {host.upper()} :: UEFI"
    tw = d.textbbox((0, 0), words, font=label)[2]
    tab(fx1 - px(90) - tw, fy0, words, rgb(muted))
    hints = "ARROWS SELECT   ENTER BOOT   E EDIT   C CONSOLE"
    tw = d.textbbox((0, 0), hints, font=label)[2]
    tab(fx1 - px(90) - tw, fy1, hints, rgb(muted))
    tab(fx0 + px(90), fy1, "AWAITING OPERATOR", rgb(muted))

    # Top left: the wordmark in dots, and what this screen is.
    left = px(150)
    top = px(150)
    d.text((left, top), brand.upper(), font=font("dot", px(170), "Bold"), fill=rgb(heading), anchor="lt")
    d.text((left + px(6), top + px(205)), "BOOT INTERFACE // STAGE 0 OF 3",
           font=font("display", px(42)), fill=rgb(muted), anchor="lt")
    d.text((left + px(6), top + px(262)), "> SYS.INIT  0x7F3A  MEMORY MAP VERIFIED",
           font=font("mono", px(30)), fill=rgb(accent), anchor="lt")

    # Top right: playful system readouts with block meters.
    readouts = [("PWR", 6, 6, "NOMINAL"), ("CORE", 4, 6, "WARMING"),
                ("NAV", 5, 6, "LOCKED"), ("LINK", 0, 6, "STANDBY")]
    rx = width - px(150)
    for i, (name, on, cells, state) in enumerate(readouts):
        y = top + px(18) + i * px(62)
        d.text((rx, y), state, font=font("mono", px(30)), fill=rgb(text if on else muted), anchor="rm")
        state_w = d.textbbox((0, 0), "NOMINAL", font=font("mono", px(30)))[2]
        mx = rx - state_w - px(40)
        for c in range(cells - 1, -1, -1):
            cx = mx - (cells - 1 - c) * px(16)
            if c < on:
                d.rectangle((cx - px(8), y - px(16), cx, y + px(16)), fill=rgb(text))
            else:
                d.rectangle((cx - px(6), y - px(3), cx - px(2), y + px(3)), fill=rgb(text, 90))
        d.text((mx - cells * px(16) - px(30), y), name, font=font("display", px(38)), fill=rgb(heading), anchor="rm")

    # Bottom left: a telemetry column of hex, fading out.
    hexfont = font("mono", px(24))
    for i in range(9):
        words = "  ".join(f"{rng.randrange(1 << 16):04X}" for _ in range(4))
        d.text((left, height - px(140) - (8 - i) * px(34)), f"{0x7F3A00 + i * 16:06X}  {words}",
               font=hexfont, fill=rgb(text, 22 + i * 9), anchor="lt")

    # Bottom right: a barcode strip and build stamp.
    bx = width - px(150)
    by = height - px(150)
    x = bx
    while x > bx - px(520):
        bw = rng.choice((px(3), px(3), px(6), px(10)))
        d.rectangle((x - bw, by - px(56), x, by), fill=rgb(text, 120))
        x -= bw + rng.choice((px(4), px(6), px(10)))
    d.text((bx, by + px(30)), f"{brand.upper()}  //  BUILD 2026.11  //  SECTOR 7G",
           font=font("display", px(30)), fill=rgb(muted), anchor="rm")

    image.alpha_composite(overlay)
    return image.convert("RGB")


def draw_menu(image, v, brand, entries):
    """A rough mock of Limine's menu in its frame: branding on top, the
    entries below, the first highlighted. Limine's own font and exact layout
    will differ a little."""
    width, height = image.size
    margin, (x0, y0, x1, y1) = layout(width, height)
    d = ImageDraw.Draw(image)
    cell_w, cell_h = CELL_W * font_scale(height), CELL_H * font_scale(height)
    f = font("mono-bold", round(cell_h * 0.72))
    cols = (x1 - x0) // cell_w
    branding = f"{brand.upper()} // BOOT SELECT"
    d.text((x0 + (cols - len(branding)) // 2 * cell_w, y0 + cell_h), branding, font=f, fill=rgb(v["accent"]))
    for i, entry in enumerate(entries):
        y = y0 + (4 + i) * cell_h
        x = x0 + 4 * cell_w
        words = f"{'>' if i == 0 else ' '} {entry}"
        if i == 0:
            d.rectangle((x - cell_w, y - cell_h * 0.1, x + (len(words) + 1) * cell_w, y + cell_h * 0.9),
                        fill=rgb(v["text"]))
            d.text((x, y), words, font=f, fill=rgb(v["bar"]))
        else:
            d.text((x, y), words, font=f, fill=rgb(v["text"] if not entry.startswith("+") else v["heading"]))
    d.text((x0 + 4 * cell_w, y0 + (5 + len(entries)) * cell_h), "Booting automatically in 5, press any key to stop.",
           font=f, fill=rgb(v["muted"]))
    return image


def theme_conf(v, brand, width, height, wallpaper_hash):
    """Global limine.conf options: wallpaper, menu text and palette."""
    margin, _ = layout(width, height)
    scale = font_scale(height)
    hexes = lambda colours: ";".join(c.lstrip("#") for c in colours)
    ansi = v["ansi"]
    return "\n".join([
        f"wallpaper: boot():/orbiter/limine-wallpaper.png#{wallpaper_hash}",
        "wallpaper_style: stretched",
        "backdrop: " + v["bar"].lstrip("#"),
        f"interface_resolution: {width}x{height}",
        f"interface_branding: {brand.upper()} // BOOT SELECT",
        "interface_branding_colour: " + v["accent"].lstrip("#"),
        "interface_help_hidden: yes",
        f"term_font_scale: {scale}x{scale}",
        "term_palette: " + hexes(ansi[:8]),
        "term_palette_bright: " + hexes(ansi[8:]),
        "term_background: ff000000",
        "term_foreground: " + v["text"].lstrip("#"),
        "term_background_bright: " + ansi[8].lstrip("#"),
        "term_foreground_bright: " + ansi[15].lstrip("#"),
        f"term_margin: {margin}",
        "term_margin_gradient: 0",
        "",
    ])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--size", default="3840x2400")
    parser.add_argument("--host", default=socket.gethostname())
    parser.add_argument("--variant", default="black")
    parser.add_argument("--preview", action="store_true")
    args = parser.parse_args()
    width, height = (int(n) for n in args.size.split("x"))
    tokens = design_tokens.load()
    v = tokens["variants"][args.variant]
    brand = tokens["brand"]["name"]

    OUT.mkdir(parents=True, exist_ok=True)
    wallpaper = draw_wallpaper(width, height, v, args.host, brand)
    path = OUT / "wallpaper.png"
    wallpaper.save(path, optimize=True)

    import hashlib
    digest = hashlib.blake2b(path.read_bytes()).hexdigest()
    (OUT / "theme.conf").write_text(theme_conf(v, brand, width, height, digest))

    if args.preview:
        entries = ["CachyOS", "CachyOS LTS", "CachyOS (fallback)", "+Snapshots"]
        draw_menu(wallpaper.copy(), v, brand, entries).save(OUT / "preview.png")


if __name__ == "__main__":
    main()
