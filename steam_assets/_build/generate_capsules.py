from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter


ROOT = Path("/Users/pond/joeysslimeventure")
OUT = ROOT / "steam_assets"
POSTER_PATH = Path("/private/tmp/joey_steam_refs/reddit/feedback.jpeg")
STEAM_SET_PATH = ROOT / "steam-set.png"
SCREENSHOT_PATH = ROOT / "joeyslime.com/assets/media/hero-screenshot.png"
TORCH_BG_PATH = ROOT / "joeyslime.com/bg.png"
VINE_PATH = ROOT / "Assets/Deko/vine.png"


POSTER = Image.open(POSTER_PATH).convert("RGBA")
STEAM_SET = Image.open(STEAM_SET_PATH).convert("RGBA")
STEAM_HERO_PANEL = STEAM_SET.crop((0, 0, STEAM_SET.width, 500)).copy()
SCREENSHOT = Image.open(SCREENSHOT_PATH).convert("RGBA")
TORCH_BG = Image.open(TORCH_BG_PATH).convert("RGBA")
VINE = Image.open(VINE_PATH).convert("RGBA")


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def scale_to_width(image: Image.Image, width: int, *, resample=Image.Resampling.NEAREST) -> Image.Image:
    ratio = width / image.width
    return image.resize((width, int(image.height * ratio)), resample)


def scale_to_height(image: Image.Image, height: int, *, resample=Image.Resampling.NEAREST) -> Image.Image:
    ratio = height / image.height
    return image.resize((int(image.width * ratio), height), resample)


def cover(image: Image.Image, size: tuple[int, int], *, resample=Image.Resampling.LANCZOS) -> Image.Image:
    width, height = size
    source_ratio = image.width / image.height
    target_ratio = width / height
    if source_ratio > target_ratio:
        scaled = scale_to_height(image, height, resample=resample)
        left = (scaled.width - width) // 2
        return scaled.crop((left, 0, left + width, height))
    scaled = scale_to_width(image, width, resample=resample)
    top = (scaled.height - height) // 2
    return scaled.crop((0, top, width, top + height))


def fit_inside(image: Image.Image, size: tuple[int, int], *, resample=Image.Resampling.NEAREST) -> Image.Image:
    width, height = size
    ratio = min(width / image.width, height / image.height)
    new_size = (max(1, int(image.width * ratio)), max(1, int(image.height * ratio)))
    return image.resize(new_size, resample)


def with_alpha(image: Image.Image, alpha: int) -> Image.Image:
    layer = image.copy().convert("RGBA")
    layer.putalpha(alpha)
    return layer


def key_near_black(image: Image.Image, cutoff: int = 12) -> Image.Image:
    result = image.convert("RGBA")
    px = result.load()
    for y in range(result.height):
        for x in range(result.width):
            r, g, b, a = px[x, y]
            if r <= cutoff and g <= cutoff and b <= cutoff:
                px[x, y] = (0, 0, 0, 0)
            else:
                px[x, y] = (r, g, b, a)
    return result


def paste_center(canvas: Image.Image, layer: Image.Image, center: tuple[int, int]) -> None:
    x = int(center[0] - layer.width / 2)
    y = int(center[1] - layer.height / 2)
    canvas.alpha_composite(layer, (x, y))


def paste_bottom(canvas: Image.Image, layer: Image.Image, center_x: int, bottom_y: int) -> None:
    x = int(center_x - layer.width / 2)
    y = int(bottom_y - layer.height)
    canvas.alpha_composite(layer, (x, y))


def shadow(layer: Image.Image, *, blur: int = 24, alpha: int = 160, offset: tuple[int, int] = (0, 0)) -> Image.Image:
    mask = layer.getchannel("A")
    base = Image.new("RGBA", layer.size, (2, 16, 28, 0))
    base.putalpha(mask)
    base = base.filter(ImageFilter.GaussianBlur(blur))
    if alpha != 255:
        base.putalpha(base.getchannel("A").point(lambda v: min(255, int(v * alpha / 255))))
    result = Image.new("RGBA", (layer.width + abs(offset[0]), layer.height + abs(offset[1])), (0, 0, 0, 0))
    ox = max(0, offset[0])
    oy = max(0, offset[1])
    result.alpha_composite(base, (ox, oy))
    return result


def vignette(size: tuple[int, int], strength: int = 105) -> Image.Image:
    width, height = size
    layer = Image.new("L", size, 0)
    draw = ImageDraw.Draw(layer)
    margin_x = max(40, width // 12)
    margin_y = max(30, height // 10)
    draw.rectangle((margin_x, margin_y, width - margin_x, height - margin_y), fill=255)
    layer = layer.filter(ImageFilter.GaussianBlur(max(width, height) // 6))
    inverted = ImageChops.invert(layer)
    return Image.merge("RGBA", [
        Image.new("L", size, 5),
        Image.new("L", size, 10),
        Image.new("L", size, 18),
        inverted.point(lambda v: min(255, int(v * strength / 255))),
    ])


def blurred_glow(size: tuple[int, int], bbox: tuple[int, int, int, int], color: tuple[int, int, int], alpha: int) -> Image.Image:
    glow_mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(glow_mask)
    draw.ellipse(bbox, fill=255)
    glow_mask = glow_mask.filter(ImageFilter.GaussianBlur(max(size) // 20))
    return Image.merge("RGBA", [
        Image.new("L", size, color[0]),
        Image.new("L", size, color[1]),
        Image.new("L", size, color[2]),
        glow_mask.point(lambda v: min(255, int(v * alpha / 255))),
    ])


def crop_alpha(image: Image.Image, padding: int = 0) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if not bbox:
        return image
    left = max(0, bbox[0] - padding)
    top = max(0, bbox[1] - padding)
    right = min(image.width, bbox[2] + padding)
    bottom = min(image.height, bbox[3] + padding)
    return image.crop((left, top, right, bottom))


def extract_logo() -> Image.Image:
    crop = STEAM_HERO_PANEL.crop((240, 5, 1285, 290)).convert("RGBA")
    alpha = Image.new("L", crop.size, 0)
    src = crop.load()
    dst = alpha.load()
    for y in range(crop.height):
        for x in range(crop.width):
            r, g, b, _ = src[x, y]
            strong_green = g > 105 and g - r > 15 and g - b > 25 and max(r, g, b) > 120
            strong_orange = r > 175 and g > 95 and b < 135 and r - b > 70
            if strong_green or strong_orange:
                dst[x, y] = 255

    alpha = alpha.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(3))
    fill = crop.copy()
    fill.putalpha(alpha)

    outline_mask = alpha.filter(ImageFilter.MaxFilter(17))
    outline = Image.new("RGBA", crop.size, (6, 24, 42, 0))
    outline.putalpha(outline_mask)

    glow_mask = outline_mask.filter(ImageFilter.GaussianBlur(6))
    glow = Image.new("RGBA", crop.size, (18, 58, 92, 0))
    glow.putalpha(glow_mask.point(lambda v: min(255, int(v * 0.6))))

    logo = Image.new("RGBA", crop.size, (0, 0, 0, 0))
    logo.alpha_composite(glow)
    logo.alpha_composite(outline)
    logo.alpha_composite(fill)
    return crop_alpha(logo, padding=18)


def make_scene(top: int = 420) -> Image.Image:
    scene = POSTER.crop((70, top, 1460, 1024)).convert("RGBA")
    return ImageEnhance.Sharpness(scene).enhance(1.25)


def make_backdrop(size: tuple[int, int], *, stronger_blur: bool = False) -> Image.Image:
    keyart_bg = STEAM_HERO_PANEL.crop((0, 135, STEAM_HERO_PANEL.width, STEAM_HERO_PANEL.height))
    keyart_bg = cover(keyart_bg, size)
    keyart_bg = keyart_bg.filter(ImageFilter.GaussianBlur(18 if stronger_blur else 10))
    keyart_bg = ImageEnhance.Brightness(keyart_bg).enhance(0.5 if stronger_blur else 0.62)
    keyart_bg = ImageEnhance.Color(keyart_bg).enhance(0.88)
    keyart_bg = with_alpha(keyart_bg, 168 if stronger_blur else 150)

    screen = cover(SCREENSHOT, size)
    screen = screen.filter(ImageFilter.GaussianBlur(12 if stronger_blur else 6))
    screen = ImageEnhance.Brightness(screen).enhance(0.55 if stronger_blur else 0.64)
    screen = ImageEnhance.Color(screen).enhance(0.65)
    screen = with_alpha(screen, 56 if stronger_blur else 34)

    torch = cover(TORCH_BG, size)
    torch = torch.filter(ImageFilter.GaussianBlur(18 if stronger_blur else 10))
    torch = ImageEnhance.Brightness(torch).enhance(0.55 if stronger_blur else 0.64)
    torch = ImageEnhance.Color(torch).enhance(0.9)
    torch = with_alpha(torch, 68 if stronger_blur else 54)

    canvas = Image.new("RGBA", size, (7, 21, 34, 255))
    canvas.alpha_composite(keyart_bg)
    canvas.alpha_composite(screen)
    canvas.alpha_composite(torch)
    canvas.alpha_composite(vignette(size, 122 if stronger_blur else 96))
    return canvas


def save(path: Path, image: Image.Image) -> None:
    ensure_parent(path)
    image.save(path)


def render_landscape(size: tuple[int, int], *, logo_width: float, scene_width: float, scene_bottom: float, scene_shift_x: float) -> Image.Image:
    canvas = make_backdrop(size)
    width, height = size
    scene = make_scene(505)
    scene = scale_to_width(scene, int(width * scene_width))
    scene_shadow = shadow(scene, blur=max(12, width // 70), alpha=180, offset=(0, 16))
    paste_bottom(canvas, scene_shadow, int(width * scene_shift_x), int(height * scene_bottom) + 16)
    paste_bottom(canvas, scene, int(width * scene_shift_x), int(height * scene_bottom))

    logo = extract_logo()
    logo = fit_inside(logo, (int(width * logo_width), int(height * 0.48)))
    logo_shadow = shadow(logo, blur=max(10, width // 90), alpha=200, offset=(0, 10))
    paste_center(canvas, logo_shadow, (width // 2, int(height * 0.26) + 10))
    paste_center(canvas, logo, (width // 2, int(height * 0.26)))
    return canvas


def render_vertical(size: tuple[int, int], *, logo_width: float, scene_width: float) -> Image.Image:
    canvas = make_backdrop(size)
    width, height = size

    vine_left = key_near_black(VINE)
    vine_left = scale_to_height(vine_left, int(height * 0.22))
    vine_left = with_alpha(vine_left, 115)
    canvas.alpha_composite(vine_left, (int(width * 0.08), -int(height * 0.02)))

    vine_right = key_near_black(VINE.transpose(Image.Transpose.FLIP_LEFT_RIGHT))
    vine_right = scale_to_height(vine_right, int(height * 0.18))
    vine_right = with_alpha(vine_right, 84)
    canvas.alpha_composite(vine_right, (int(width * 0.78), int(height * 0.02)))

    logo = extract_logo()
    logo = fit_inside(logo, (int(width * logo_width), int(height * 0.34)))
    logo_shadow = shadow(logo, blur=14, alpha=210, offset=(0, 12))
    paste_center(canvas, logo_shadow, (width // 2, int(height * 0.18) + 12))
    paste_center(canvas, logo, (width // 2, int(height * 0.18)))

    scene = make_scene(420)
    scene = scale_to_width(scene, int(width * scene_width))
    scene_shadow = shadow(scene, blur=16, alpha=185, offset=(0, 16))
    paste_bottom(canvas, scene_shadow, width // 2, height - 10)
    paste_bottom(canvas, scene, width // 2, height - 26)
    return canvas


def render_page_background(size: tuple[int, int]) -> Image.Image:
    canvas = make_backdrop(size, stronger_blur=True)
    width, height = size
    canvas.alpha_composite(blurred_glow(size, (int(width * 0.16), int(height * 0.2), int(width * 0.3), int(height * 0.42)), (255, 176, 72), 44))
    canvas.alpha_composite(blurred_glow(size, (int(width * 0.7), int(height * 0.16), int(width * 0.84), int(height * 0.38)), (255, 164, 78), 34))
    canvas.alpha_composite(blurred_glow(size, (int(width * 0.42), int(height * 0.45), int(width * 0.56), int(height * 0.68)), (80, 180, 96), 20))
    return ImageEnhance.Brightness(canvas).enhance(0.96)


def render_library_hero(size: tuple[int, int]) -> Image.Image:
    canvas = make_backdrop(size, stronger_blur=True)
    width, height = size
    scene = make_scene(420)
    scene = scale_to_height(scene, int(height * 0.9))
    scene_shadow = shadow(scene, blur=24, alpha=185, offset=(0, 16))
    paste_bottom(canvas, scene_shadow, int(width * 0.52), height - 8)
    paste_bottom(canvas, scene, int(width * 0.52), height - 36)

    # Keep the bottom-left a little calmer so the Steam library logo can sit there cleanly.
    quiet = Image.new("RGBA", size, (7, 14, 22, 0))
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((int(width * -0.02), int(height * 0.32), int(width * 0.42), int(height * 1.16)), fill=200)
    mask = mask.filter(ImageFilter.GaussianBlur(120))
    quiet.putalpha(mask.point(lambda v: min(255, int(v * 0.55))))
    canvas.alpha_composite(quiet)
    canvas.alpha_composite(vignette(size, 132))
    return canvas


def render_library_logo(size: tuple[int, int]) -> Image.Image:
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    logo = extract_logo()
    logo = fit_inside(logo, (int(size[0] * 0.9), int(size[1] * 0.62)))
    logo_shadow = shadow(logo, blur=14, alpha=230, offset=(0, 8))
    paste_center(canvas, logo_shadow, (size[0] // 2, size[1] // 2 + 8))
    paste_center(canvas, logo, (size[0] // 2, size[1] // 2))
    return canvas


def make_contact_sheet(paths: list[Path], out_path: Path) -> None:
    thumbs = []
    for path in paths:
        image = Image.open(path).convert("RGBA")
        thumbs.append(fit_inside(image, (420, 260), resample=Image.Resampling.LANCZOS))
    width = 900
    rows = []
    row = Image.new("RGBA", (width, 280), (10, 16, 22, 255))
    x, y = 20, 10
    for index, thumb in enumerate(thumbs):
        if x + thumb.width > width - 20:
            rows.append(row)
            row = Image.new("RGBA", (width, 280), (10, 16, 22, 255))
            x = 20
        row.alpha_composite(thumb, (x, 10 + (260 - thumb.height) // 2))
        x += thumb.width + 20
    rows.append(row)
    sheet = Image.new("RGBA", (width, len(rows) * 280), (10, 16, 22, 255))
    for i, row_img in enumerate(rows):
        sheet.alpha_composite(row_img, (0, i * 280))
    save(out_path, sheet)


def main() -> None:
    outputs = {
        OUT / "store/title_capsule_920x430.png": render_landscape((920, 430), logo_width=0.73, scene_width=0.82, scene_bottom=1.05, scene_shift_x=0.51),
        OUT / "store/small_capsule_462x174.png": render_landscape((462, 174), logo_width=0.92, scene_width=0.76, scene_bottom=1.2, scene_shift_x=0.53),
        OUT / "store/main_capsule_1232x706.png": render_landscape((1232, 706), logo_width=0.72, scene_width=0.88, scene_bottom=1.03, scene_shift_x=0.51),
        OUT / "store/vertical_capsule_748x896.png": render_vertical((748, 896), logo_width=0.92, scene_width=0.98),
        OUT / "store/page_background_1438x810.png": render_page_background((1438, 810)),
        OUT / "library/library_capsule_600x900.png": render_vertical((600, 900), logo_width=0.92, scene_width=0.98),
        OUT / "library/library_header_920x430.png": render_landscape((920, 430), logo_width=0.73, scene_width=0.82, scene_bottom=1.05, scene_shift_x=0.51),
        OUT / "library/library_hero_3840x1240.png": render_library_hero((3840, 1240)),
        OUT / "library/library_logo_1280x720.png": render_library_logo((1280, 720)),
    }
    for path, image in outputs.items():
        save(path, image)
    make_contact_sheet(list(outputs.keys()), OUT / "_build/assets_contact.png")


if __name__ == "__main__":
    main()
