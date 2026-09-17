#!/usr/bin/env python3
"""Extract the supplied friendly firefly flight poses without resampling."""

from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Assets/Creatures/Gluehwuermchen/source/gluehwuermchen_sheet.png"
OUTPUT = ROOT / "Assets/Creatures/Gluehwuermchen/frames"
WIDTH = 128
ROW_EDGES = (0, 171, 341, 512, 683, 853, 1024)


def _extract(image: Image.Image, column: int, row: int) -> Image.Image:
    top, bottom = ROW_EDGES[row], ROW_EDGES[row + 1]
    cell = image.crop((column * WIDTH, top, (column + 1) * WIDTH, bottom))
    # Only the first visible pixel column of pose seven contains a sliver from
    # its neighbor. It is outside the firefly silhouette, so remove precisely
    # that narrow source artifact without filtering or altering any artwork.
    if row == 0 and column == 6:
        alpha = cell.getchannel("A")
        alpha.paste(0, (0, 0, 18, cell.height))
        cell.putalpha(alpha)
    frame = Image.new("RGBA", (WIDTH, 171), (0, 0, 0, 0))
    frame.alpha_composite(cell, (0, 0))
    return frame


def main() -> None:
    image = Image.open(SOURCE).convert("RGBA")
    if image.size != (1536, 1024):
        raise ValueError(f"Expected a 1536 x 1024 sheet, got {image.size}")
    OUTPUT.mkdir(parents=True, exist_ok=True)

    # The first twelve poses are the clean side-on wing cycle.  They provide a
    # non-repeating flight loop without borrowing special dash/heart poses.
    for index in range(12):
        _extract(image, index, 0).save(OUTPUT / f"flight_{index:02d}.png")
    # A quiet, wings-up profile is used while the creature rests on a plant or
    # ledge. It is deliberately a held pose, not a fake movement animation.
    _extract(image, 4, 3).save(OUTPUT / "rest_00.png")


if __name__ == "__main__":
    main()
