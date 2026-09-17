#!/usr/bin/env python3
"""Extract the supplied unique cave/lush chapter landmark sheets.

No source artwork is resized. Every exported texture preserves its native cell
canvas so a Godot Sprite2D can use a stable bottom anchor.
"""

from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
LUSH_SOURCE = ROOT / "Assets/Deko/landmarks/source/lush_landmarks_sheet.png"
CAVE_SOURCE = ROOT / "Assets/Deko/landmarks/source/cave_landmarks_sheet.png"
LUSH_OUTPUT = ROOT / "Assets/Deko/landmarks/lush"
CAVE_OUTPUT = ROOT / "Assets/Deko/landmarks/cave"


def _save_lush() -> None:
    source = Image.open(LUSH_SOURCE).convert("RGBA")
    if source.size != (1536, 1024):
        raise ValueError(f"Unexpected lush landmark size: {source.size}")
    LUSH_OUTPUT.mkdir(parents=True, exist_ok=True)
    # First four cells of both rows are the eight supplied lush landmarks.
    for index in range(8):
        column, row = index % 4, index // 4
        frame = source.crop((column * 256, row * 256, (column + 1) * 256, (row + 1) * 256))
        frame.save(LUSH_OUTPUT / f"lush_landmark_{index:02d}.png")


def _save_cave() -> None:
    source = Image.open(CAVE_SOURCE).convert("RGBA")
    if source.size != (1448, 1086):
        raise ValueError(f"Unexpected cave landmark size: {source.size}")
    CAVE_OUTPUT.mkdir(parents=True, exist_ok=True)
    # The sheet is four equally sized columns by two rows. Its near-black
    # backdrop is an opaque export artifact, not part of the landmarks.  A
    # small threshold removes its compression/noise pixels as well, preventing
    # rectangular dark panels in-game. The remaining dark rock is far brighter
    # than this cutoff and retains its original source pixels.
    for index in range(8):
        column, row = index % 4, index // 4
        frame = source.crop((column * 362, row * 543, (column + 1) * 362, (row + 1) * 543))
        pixels = frame.load()
        for y in range(frame.height):
            for x in range(frame.width):
                red, green, blue, _alpha = pixels[x, y]
                if max(red, green, blue) <= 20:
                    pixels[x, y] = (0, 0, 0, 0)
        frame.save(CAVE_OUTPUT / f"cave_landmark_{index:02d}.png")


def main() -> None:
    _save_lush()
    _save_cave()


if __name__ == "__main__":
    main()
