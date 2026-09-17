#!/usr/bin/env python3
"""Extract the supplied Leuchtmaul sheet into stable, pixel-perfect frames.

The source is a transparent 6 x 4 presentation sheet.  Frames retain their
native 256 px cell and therefore share both canvas size and ground pivot; this
keeps the creature from hopping between animation poses in Godot.
"""

from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Assets/Enemies/Leuchtmaul/source/leuchtmaul_sheet.png"
OUTPUT = ROOT / "Assets/Enemies/Leuchtmaul/frames"
CELL_SIZE = 256

# Only self-contained poses are used for the monster.  The presentation sheet
# intentionally lets some tongue/particle poses bleed over a neighboring cell;
# those are excluded instead of turning them into broken gameplay frames.
FRAMES = {
    "idle": [(0, 0), (1, 0), (2, 0), (3, 0), (4, 0), (5, 0)],
    "bite": [(0, 1), (1, 1), (2, 1), (3, 1), (4, 1), (5, 1)],
    "recoil": [(3, 3)],  # third cell from the right, bottom row: requested curl-up pose
    "death": [(0, 3), (1, 3), (2, 3), (3, 3), (4, 3), (5, 3)],
}


def main() -> None:
    image = Image.open(SOURCE).convert("RGBA")
    expected_size = (CELL_SIZE * 6, CELL_SIZE * 4)
    if image.size != expected_size:
        raise ValueError(f"Expected {expected_size}, got {image.size}")

    OUTPUT.mkdir(parents=True, exist_ok=True)
    for animation, cells in FRAMES.items():
        for index, (column, row) in enumerate(cells):
            frame = image.crop(
                (
                    column * CELL_SIZE,
                    row * CELL_SIZE,
                    (column + 1) * CELL_SIZE,
                    (row + 1) * CELL_SIZE,
                )
            )
            # The provided alpha is already clean.  No resampling, colour
            # alteration or bounding-box crop is performed here.
            frame.save(OUTPUT / f"{animation}_{index:02d}.png")


if __name__ == "__main__":
    main()
