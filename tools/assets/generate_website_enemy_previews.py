#!/usr/bin/env python3
"""Build small pixel-perfect idle GIF previews for the official website.

The website receives its previews from the gameplay frames, never from
upscaled screenshots or newly drawn art. Each animation is composited onto a
stable canvas, so it cannot visibly jump while looping in an enemy card.
"""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
MEDIA = ROOT / "joeyslime.com/assets/media"


def _load_frames(paths: list[Path], crop: tuple[int, int, int, int] | None = None) -> list[Image.Image]:
    frames: list[Image.Image] = []
    for path in paths:
        frame = Image.open(path).convert("RGBA")
        frames.append(frame.crop(crop) if crop else frame)
    return frames


def _save_preview(name: str, frames: list[Image.Image], canvas_size: tuple[int, int], duration: int, scale: int = 1) -> None:
    composed: list[Image.Image] = []
    for frame in frames:
        if scale != 1:
            frame = frame.resize((frame.width * scale, frame.height * scale), Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
        x = (canvas.width - frame.width) // 2
        y = canvas.height - frame.height
        canvas.alpha_composite(frame, (x, y))
        # GIF supports palette transparency. Keeping the transparent background
        # avoids a rectangular preview panel in the card.
        composed.append(canvas.convert("P", palette=Image.Palette.ADAPTIVE, colors=255))
    output = MEDIA / name
    composed[0].save(output, save_all=True, append_images=composed[1:], duration=duration, loop=0, disposal=2, transparency=0)


def main() -> None:
    MEDIA.mkdir(parents=True, exist_ok=True)

    bat_sheet = Image.open(ROOT / "Assets/Enemies/Bat/Standard/BatStandard_Flying.png").convert("RGBA")
    bat_frames = [bat_sheet.crop((frame * 32, 0, (frame + 1) * 32, 32)) for frame in range(4)]
    _save_preview("bat.gif", bat_frames, (160, 160), 130, scale=4)

    _save_preview(
        "irrlichtkaefer.gif",
        _load_frames(sorted((ROOT / "Assets/Enemies/Irrlichtkaefer/individual").glob("idle_*.png")), (80, 60, 304, 264)),
        (256, 220),
        120,
    )
    _save_preview(
        "leuchtmaul.gif",
        _load_frames(sorted((ROOT / "Assets/Enemies/Leuchtmaul/frames").glob("idle_*.png"))),
        (256, 256),
        125,
    )
    _save_preview(
        "kristallruecken.gif",
        _load_frames(sorted((ROOT / "Assets/Enemies/Kristallruecken/frames").glob("idle_*.png")), (96, 60, 288, 246)),
        (256, 220),
        135,
    )


if __name__ == "__main__":
    main()
