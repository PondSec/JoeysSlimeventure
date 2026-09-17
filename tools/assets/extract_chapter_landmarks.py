#!/usr/bin/env python3
"""Extract the supplied unique cave/lush chapter landmark sheets.

No source artwork is resized. Every exported texture preserves its native cell
canvas so a Godot Sprite2D can use a stable bottom anchor.
"""

from pathlib import Path
from collections import deque

from PIL import Image, ImageChops, ImageFilter


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
    # This is a tightly packed contact sheet, not a grid.  Several silhouettes
    # cross their nominal 384 px cell boundary, so fixed tile crops visibly
    # severed vines and roots.  Extract each connected silhouette instead.
    alpha = _painted_backdrop_alpha(source)
    labels, components = _label_components(alpha)
    targets = [
        (260, 300), (635, 365), (1050, 315), (1385, 320),
        (205, 765), (1385, 785),
    ]
    selected = [_nearest_component(components, target) for target in targets]
    _save_component(source, labels, components, selected[0], LUSH_OUTPUT / "lush_landmark_00.png")
    _save_component(source, labels, components, selected[1], LUSH_OUTPUT / "lush_landmark_01.png")
    _save_component(source, labels, components, selected[2], LUSH_OUTPUT / "lush_landmark_02.png")
    _save_component(source, labels, components, selected[3], LUSH_OUTPUT / "lush_landmark_03.png")
    _save_component(source, labels, components, selected[4], LUSH_OUTPUT / "lush_landmark_04.png")

    # The root shrine and waterfall touch by a few painted pixels in the source
    # sheet.  They are still two separate landmarks, so split only their shared
    # connected component across the clear visual gap at x=800.
    shared = _nearest_component(components, (820, 790))
    _save_component(source, labels, components, shared, LUSH_OUTPUT / "lush_landmark_05.png", (360, 800))
    _save_component(source, labels, components, shared, LUSH_OUTPUT / "lush_landmark_06.png", (800, 1265))
    _save_component(source, labels, components, selected[5], LUSH_OUTPUT / "lush_landmark_07.png")


def _painted_backdrop_alpha(frame: Image.Image) -> Image.Image:
    """Convert the smooth contact-sheet backdrop to alpha without touching art.

    The supplied lush sheet has an opaque, low-frequency green backdrop.  A
    blurred copy estimates that backdrop; strong local detail is the landmark
    silhouette.  Flood-filling from the border retains all enclosed dark roots
    and rock detail instead of cutting a rectangular panel into the level.
    """
    rgb = frame.convert("RGB")
    backdrop = rgb.filter(ImageFilter.GaussianBlur(radius=22))
    difference = ImageChops.difference(rgb, backdrop).convert("L")
    detail = difference.point(lambda value: 255 if value >= 14 else 0)
    detail = detail.filter(ImageFilter.MaxFilter(5))
    pixels = detail.load()
    width, height = detail.size
    exterior = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def add_if_background(x: int, y: int) -> None:
        index = y * width + x
        if exterior[index] or pixels[x, y] != 0:
            return
        exterior[index] = 1
        queue.append((x, y))

    for x in range(width):
        add_if_background(x, 0)
        add_if_background(x, height - 1)
    for y in range(height):
        add_if_background(0, y)
        add_if_background(width - 1, y)
    while queue:
        x, y = queue.popleft()
        for next_x, next_y in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= next_x < width and 0 <= next_y < height:
                add_if_background(next_x, next_y)

    alpha = Image.new("L", (width, height), 0)
    alpha_pixels = alpha.load()
    for y in range(height):
        for x in range(width):
            if not exterior[y * width + x]:
                alpha_pixels[x, y] = 255
    return alpha


def _label_components(alpha: Image.Image) -> tuple[list[int], list[tuple[int, tuple[int, int, int, int]]]]:
    """Label all connected opaque silhouettes and retain their native bounds."""
    width, height = alpha.size
    pixels = alpha.load()
    labels = [-1] * (width * height)
    components: list[tuple[int, tuple[int, int, int, int]]] = []
    for start_y in range(height):
        for start_x in range(width):
            start = start_y * width + start_x
            if labels[start] >= 0 or pixels[start_x, start_y] == 0:
                continue
            component_id = len(components)
            queue: deque[tuple[int, int]] = deque([(start_x, start_y)])
            labels[start] = component_id
            count = 0
            left = right = start_x
            top = bottom = start_y
            while queue:
                x, y = queue.popleft()
                count += 1
                left, right = min(left, x), max(right, x)
                top, bottom = min(top, y), max(bottom, y)
                for next_x, next_y in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if not (0 <= next_x < width and 0 <= next_y < height):
                        continue
                    next_index = next_y * width + next_x
                    if labels[next_index] < 0 and pixels[next_x, next_y] != 0:
                        labels[next_index] = component_id
                        queue.append((next_x, next_y))
            components.append((count, (left, top, right + 1, bottom + 1)))
    return labels, components


def _nearest_component(components: list[tuple[int, tuple[int, int, int, int]]], target: tuple[int, int]) -> int:
    target_x, target_y = target
    candidates = [
        (index, count, bounds)
        for index, (count, bounds) in enumerate(components)
        if count >= 10_000
    ]
    return min(
        candidates,
        key=lambda entry: (
            ((entry[2][0] + entry[2][2]) * 0.5 - target_x) ** 2
            + ((entry[2][1] + entry[2][3]) * 0.5 - target_y) ** 2
        ),
    )[0]


def _save_component(
    source: Image.Image,
    labels: list[int],
    components: list[tuple[int, tuple[int, int, int, int]]],
    component_id: int,
    output: Path,
    x_range: tuple[int, int] | None = None,
) -> None:
    left, top, right, bottom = components[component_id][1]
    if x_range is not None:
        left, right = max(left, x_range[0]), min(right, x_range[1])
    width, height = source.size
    cropped = source.crop((left, top, right, bottom))
    alpha = Image.new("L", cropped.size, 0)
    alpha_pixels = alpha.load()
    for local_y in range(alpha.height):
        source_y = top + local_y
        for local_x in range(alpha.width):
            source_x = left + local_x
            if labels[source_y * width + source_x] == component_id:
                alpha_pixels[local_x, local_y] = 255
    cropped.putalpha(alpha)
    cropped.save(output)


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
