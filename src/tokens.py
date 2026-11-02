"""Loads the design tokens: tokens.toml at the repository root, with this
machine's overrides from ~/.config/orbiter/tokens.toml merged over it (any
subset of the same tables and keys). chezmoi writes that file; it's also the
place for local tweaks that shouldn't go into the repository.
"""
import os
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def override_path():
    config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    return config / "orbiter" / "tokens.toml"


def merge(base, over):
    for key, value in over.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            merge(base[key], value)
        else:
            base[key] = value
    return base


def load():
    tokens = tomllib.loads((ROOT / "tokens.toml").read_text())
    path = override_path()
    if path.is_file():
        merge(tokens, tomllib.loads(path.read_text()))
    return tokens
