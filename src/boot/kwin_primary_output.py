#!/usr/bin/env python3
"""Prints the connector name of the primary display in a KWin monitor config,
for the layout matching the monitors plugged in now; nothing if none matches.

  kwin_primary_output.py <kwinoutputconfig.json> [sysfs drm dir]

The config keeps a layout for every set of monitors it has seen, so monitors
are matched by connector and EDID. KWin's identifier is the EDID's manufacturer,
product, serial, week and year, then a trailing 0.
"""
import json
import sys
from pathlib import Path


def edid_identifier(edid):
    packed = int.from_bytes(edid[8:10], "big")
    maker = "".join(chr(((packed >> shift) & 31) + 64) for shift in (10, 5, 0))
    product = int.from_bytes(edid[10:12], "little")
    serial = int.from_bytes(edid[12:16], "little")
    return f"{maker} {product} {serial} {edid[16]} {edid[17] + 1990} 0"


def connected(drm):
    """{connector: EDID identifier} for what's plugged in, without the cardN- prefix."""
    found = {}
    for path in Path(drm).glob("card*-*"):
        if (path / "status").read_text().strip() != "connected":
            continue
        edid = (path / "edid").read_bytes()
        found[path.name.split("-", 1)[1]] = edid_identifier(edid) if len(edid) >= 18 else None
    return found


def primary_output(config, monitors):
    sections = {section["name"]: section["data"] for section in config}
    outputs = sections["outputs"]
    for setup in sections["setups"]:
        enabled = [o for o in setup["outputs"] if o["enabled"]]
        names = {outputs[o["outputIndex"]]["connectorName"]: outputs[o["outputIndex"]].get("edidIdentifier")
                 for o in enabled}
        if names == monitors:
            first = min(enabled, key=lambda o: o["priority"])
            return outputs[first["outputIndex"]]["connectorName"]
    return ""


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    drm = sys.argv[2] if len(sys.argv) > 2 else "/sys/class/drm"
    print(primary_output(json.loads(Path(sys.argv[1]).read_text()), connected(drm)))


if __name__ == "__main__":
    main()
