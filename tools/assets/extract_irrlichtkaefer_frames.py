#!/usr/bin/env python3
"""Extract the Irrlichtkäfer sheet into clean, consistently anchored frames.

The supplied sheet is deliberately laid out with variable-width columns.  It
is not a uniform tile atlas: slicing it on a fixed 222px grid cuts neighbouring
sprites into the walk, attack and death animations.  This utility keeps the
source pixels intact, isolates the documented semantic regions and places them
on a common transparent canvas so AnimatedSprite2D has one stable pivot.
"""

from __future__ import annotations

from pathlib import Path
from collections import deque

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Assets/Enemies/Irrlichtkaefer/irrlichtkaefer_sheet.png"
OUTPUT = ROOT / "Assets/Enemies/Irrlichtkaefer/individual"
CANVAS_SIZE = (384, 288)
GROUND_Y = 260
ALPHA_CLEANUP_THRESHOLD = 8

# The regions are separated at the midpoint between neighbouring illustrations,
# rather than on a fixed grid.  Bounds are left, top, right, bottom in source
# pixels.  They contain every pixel of the named pose and no neighbour.
ROWS = {
    "idle": (
        (0, 0, 235, 242), (235, 0, 487, 242), (487, 0, 747, 242),
        (747, 0, 1015, 242), (1015, 0, 1264, 242), (1264, 0, 1774, 242),
    ),
    "walk": (
        (15, 263, 221, 454), (236, 261, 428, 454), (437, 265, 637, 454),
        (635, 268, 844, 454), (837, 267, 1044, 454), (1039, 272, 1229, 454),
        (1220, 268, 1423, 454), (1397, 266, 1598, 454), (1582, 269, 1760, 454),
    ),
    "attack": (
        (0, 460, 256, 710), (256, 460, 521, 710), (521, 460, 810, 710),
        (810, 460, 1141, 710), (1141, 460, 1480, 710), (1480, 460, 1774, 710),
    ),
    "death": (
        (0, 715, 285, 887), (285, 715, 560, 887), (560, 715, 861, 887),
        (861, 715, 1147, 887), (1147, 715, 1461, 887), (1461, 715, 1774, 887),
    ),
}


def _keep_center_component(candidate: Image.Image) -> Image.Image:
    """Keep the sprite component centred in a packed walk-frame crop.

    The rightmost walking poses overlap their neighbour's bounding rectangle by
    a few glowing outline pixels. They remain distinct alpha components, so
    this removes only that other component instead of shaving real sprite pixels.
    """
    alpha = candidate.getchannel("A")
    width, height = candidate.size
    pixels = alpha.load()
    center = (width // 2, height // 2)
    seed = min(
        ((x, y) for y in range(height) for x in range(width) if pixels[x, y] > 0),
        key=lambda point: (point[0] - center[0]) ** 2 + (point[1] - center[1]) ** 2,
    )
    keep = Image.new("L", candidate.size, 0)
    keep_pixels = keep.load()
    queue: deque[tuple[int, int]] = deque([seed])
    keep_pixels[seed[0], seed[1]] = 255
    while queue:
        x, y = queue.popleft()
        for offset_x, offset_y in ((-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)):
            next_x, next_y = x + offset_x, y + offset_y
            if 0 <= next_x < width and 0 <= next_y < height and pixels[next_x, next_y] > 0 and keep_pixels[next_x, next_y] == 0:
                keep_pixels[next_x, next_y] = 255
                queue.append((next_x, next_y))
    candidate.putalpha(Image.composite(alpha, Image.new("L", candidate.size, 0), keep))
    return candidate


def _tight_crop(
	image: Image.Image,
	bounds: tuple[int, int, int, int],
	keep_center_component: bool = False,
) -> Image.Image:
    candidate = image.crop(bounds)
    # The provided PNG carries near-transparent black matte pixels outside its
    # artwork.  They are not visible art and would inflate every crop into a
    # rectangle, so remove only alpha values below the documented cutoff.
    alpha = candidate.getchannel("A").point(
        lambda value: 0 if value < ALPHA_CLEANUP_THRESHOLD else value
    )
    candidate.putalpha(alpha)
    if keep_center_component:
        candidate = _keep_center_component(candidate)
    content = candidate.getchannel("A").getbbox()
    if content is None:
        raise RuntimeError(f"Empty frame region: {bounds}")
    return candidate.crop(content)


def _write_frame(image: Image.Image, frame_name: str, index: int) -> None:
    content = _tight_crop(
        image,
        ROWS[frame_name][index],
        keep_center_component=frame_name == "walk",
    )
    if content.width > CANVAS_SIZE[0] or content.height > GROUND_Y:
        raise RuntimeError(f"{frame_name}_{index:02d} does not fit its stable canvas: {content.size}")

    # Bottom-centering gives every grounded pose the same visual origin.  No
    # resampling or colour conversion happens after the original RGBA pixels
    # are read; this is strictly crop-and-place work on transparent pixels.
    canvas = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    position = ((CANVAS_SIZE[0] - content.width) // 2, GROUND_Y - content.height)
    canvas.alpha_composite(content, position)
    canvas.save(OUTPUT / f"{frame_name}_{index:02d}.png")


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(SOURCE).convert("RGBA")
    for frame_name, regions in ROWS.items():
        for index in range(len(regions)):
            _write_frame(sheet, frame_name, index)


if __name__ == "__main__":
    main()
