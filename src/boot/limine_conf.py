#!/usr/bin/env python3
"""Adds Orbiter's theme lines to limine.conf, or takes them out again.

  limine_conf.py apply  <limine.conf> <theme.conf>
  limine_conf.py remove <limine.conf>

Only the global section (everything before the first `/Entry`) is touched.
The theme goes in as one marked block just before the first entry, and any
existing global line that sets the same option is commented out with a
marker rather than deleted, so `remove` restores the file exactly.
"""
import os
import re
import sys

BEGIN = "# >>> orbiter theme (added by install-boot.sh; uninstall-boot.sh removes it)"
END = "# <<< orbiter theme"
DISABLED = "#orbiter-disabled# "
OPTION = re.compile(r"^\s*([A-Za-z_]+)\s*:")


def remove(text):
    out, inside, after_block = [], False, False
    for line in text.splitlines():
        if line == BEGIN:
            inside = True
        elif line == END:
            inside, after_block = False, True
        elif not inside:
            # The block is followed by one blank line of its own.
            if not (after_block and line == ""):
                out.append(line[len(DISABLED):] if line.startswith(DISABLED) else line)
            after_block = False
    return "\n".join(out) + "\n"


def apply(text, theme):
    lines = remove(text).splitlines()
    first_entry = next((i for i, l in enumerate(lines) if l.lstrip().startswith("/")), len(lines))
    keys = set()
    for line in theme.splitlines():
        m = OPTION.match(line)
        if m:
            key = m.group(1).lower()
            # Limine accepts both spellings of colour.
            keys |= {key, key.replace("colour", "color"), key.replace("color", "colour")}
    for i in range(first_entry):
        m = OPTION.match(lines[i])
        if m and m.group(1).lower() in keys:
            lines[i] = DISABLED + lines[i]
    block = [BEGIN, *theme.strip().splitlines(), END, ""]
    return "\n".join(lines[:first_entry] + block + lines[first_entry:]) + "\n"


def write_atomically(path, text):
    tmp = path + ".orbiter-tmp"
    with open(tmp, "w") as f:
        f.write(text)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def main():
    if len(sys.argv) < 3 or sys.argv[1] not in ("apply", "remove"):
        sys.exit(__doc__)
    path = sys.argv[2]
    text = open(path).read()
    if sys.argv[1] == "apply":
        new = apply(text, open(sys.argv[3]).read())
    else:
        new = remove(text)
    if new != text:
        write_atomically(path, new)


if __name__ == "__main__":
    main()
