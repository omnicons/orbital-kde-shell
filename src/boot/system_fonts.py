"""Finds installed fonts through fontconfig, so the generators work wherever
a distribution puts them (/usr/share/fonts/TTF on Arch, per-family folders
of .otf files on Fedora)."""
import subprocess
import sys


def find(pattern):
    """The file fontconfig picks for a pattern like 'IBM Plex Mono:style=Bold'.
    Falls back to whatever monospace font it would substitute."""
    try:
        path = subprocess.run(["fc-match", "-f", "%{file}", pattern],
                              capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        path = ""
    if not path:
        sys.exit(f"No font found for '{pattern}': install fontconfig and IBM Plex Mono.")
    return path


def plex_mono(bold=False):
    return find("IBM Plex Mono:style=Bold" if bold else "IBM Plex Mono:style=Regular")
