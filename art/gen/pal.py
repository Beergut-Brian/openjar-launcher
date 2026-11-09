"""Loads the active palette (config.PALETTE) as {key: '#RRGGBB'}."""
import json
from pathlib import Path

import config

ROOT = Path(__file__).resolve().parents[2]
_data = json.loads((ROOT / "art" / "palettes" / f"{config.PALETTE}.json").read_text())
P = {c["key"]: c["hex"].upper() for c in _data["colours"]}
NAME = _data["title"]


def rgb(key_or_hex):
    h = P.get(key_or_hex, key_or_hex).lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def godot(key, alpha=1.0):
    r, g, b = rgb(key)
    return f"Color({r / 255:.4f}, {g / 255:.4f}, {b / 255:.4f}, {alpha:.4f})"
