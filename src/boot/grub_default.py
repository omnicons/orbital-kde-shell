#!/usr/bin/env python3
"""Points /etc/default/grub at Orbiter's GRUB theme, or undoes it.

  grub_default.py apply  <file> <theme.txt path>
  grub_default.py remove <file>

Sets GRUB_THEME; makes sure GRUB draws graphically (GRUB_GFXMODE=auto if
nothing sets a mode, and a console-only GRUB_TERMINAL_OUTPUT is switched to
gfxterm, since themes need it). Settings go in one marked block at the end;
lines they replace are commented out with a marker, so `remove` restores the
file exactly. Run grub-mkconfig afterwards.
"""
import os
import re
import sys

BEGIN = "# >>> orbiter theme (added by install-boot.sh; uninstall-boot.sh removes it)"
END = "# <<< orbiter theme"
DISABLED = "#orbiter-disabled# "
SETTING = re.compile(r"^\s*(GRUB_[A-Z_]+)=(.*)$")


def remove(text):
    out, inside = [], False
    for line in text.splitlines():
        if line == BEGIN:
            inside = True
        elif line == END:
            inside = False
        elif not inside:
            out.append(line[len(DISABLED):] if line.startswith(DISABLED) else line)
    while out and out[-1] == "":
        out.pop()
    return "\n".join(out) + "\n"


def apply(text, theme_path):
    lines = remove(text).splitlines()
    active = {}
    for i, line in enumerate(lines):
        m = SETTING.match(line)
        if m:
            active[m.group(1)] = (i, m.group(2))

    block = [f'GRUB_THEME="{theme_path}"']
    disable = ["GRUB_THEME"]
    if "GRUB_GFXMODE" not in active:
        block.append("GRUB_GFXMODE=auto")
    if "GRUB_TERMINAL_OUTPUT" in active and "console" in active["GRUB_TERMINAL_OUTPUT"][1]:
        disable.append("GRUB_TERMINAL_OUTPUT")
        block.append("GRUB_TERMINAL_OUTPUT=gfxterm")

    for key in disable:
        if key in active:
            i = active[key][0]
            lines[i] = DISABLED + lines[i]
    return "\n".join(lines + ["", BEGIN, *block, END]) + "\n"


def main():
    if len(sys.argv) < 3 or sys.argv[1] not in ("apply", "remove"):
        sys.exit(__doc__)
    path = sys.argv[2]
    text = open(path).read()
    new = apply(text, sys.argv[3]) if sys.argv[1] == "apply" else remove(text)
    if new != text:
        tmp = path + ".orbiter-tmp"
        with open(tmp, "w") as f:
            f.write(new)
        os.replace(tmp, path)


if __name__ == "__main__":
    main()
