#!/usr/bin/env python3
"""Draw Sofa Chat's Apple TV artwork and write it into the asset catalog.

Makes the layered app icon (back, middle and front layers, so the Apple TV
home screen can give it its tilt-and-shine effect), the App Store icon and
both Top Shelf images. Everything is drawn in code, so you can change a color
below and run it again:

    pip install pillow
    python3 Design/make_artwork.py

It writes PNGs into App/Assets.xcassets/App Icon & Top Shelf Image.brandassets,
plus the README banner at docs/banner.png.
The wordmark on the Top Shelf images uses the Inter Display font if it is
installed (it is free, under the SIL Open Font License); otherwise it falls
back to a font Pillow can find.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "App" / "Assets.xcassets"
BRAND = CATALOG / "App Icon & Top Shelf Image.brandassets"

# Colors
NIGHT_TOP = (24, 26, 58)  # deep blue at the top of the room
NIGHT_BOTTOM = (58, 34, 72)  # warm plum near the floor
LAMP = (255, 176, 102)  # the glow of a lamp off to one side
SOFA = (234, 116, 88)  # coral sofa
SOFA_SHADE = (196, 86, 66)  # cushion seams and the seat front
SOFA_LEGS = (120, 60, 52)
BUBBLE = (250, 247, 242)  # speech bubble
DOTS = (234, 116, 88)
WORDMARK = (250, 247, 242)
TAGLINE = (214, 204, 222)

SUPERSAMPLE = 2  # draw big, then shrink, for smooth edges
INFO = {"author": "xcode", "version": 1}


# Drawing helpers

def gradient_background(w: int, h: int, glow_at: tuple[float, float]) -> Image.Image:
    """An opaque vertical gradient with a soft lamp glow."""
    column = Image.new("RGB", (1, 256))
    for y in range(256):
        t = y / 255
        column.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(NIGHT_TOP, NIGHT_BOTTOM)))
    img = column.resize((w, h), Image.BILINEAR)

    # Draw the glow small and scale it up: a soft blur doesn't need detail.
    scale = 400 / max(w, h)
    sw, sh = max(1, round(w * scale)), max(1, round(h * scale))
    glow = Image.new("L", (sw, sh), 0)
    gx, gy = glow_at[0] * sw, glow_at[1] * sh
    r = 0.55 * max(sw, sh)
    ImageDraw.Draw(glow).ellipse([gx - r, gy - r, gx + r, gy + r], fill=80)
    glow = glow.filter(ImageFilter.GaussianBlur(radius=r * 0.45)).resize((w, h), Image.BILINEAR)
    lamp = Image.new("RGB", (w, h), LAMP)
    return Image.composite(lamp, img, glow)


def draw_sofa(d: ImageDraw.ImageDraw, cx: float, base_y: float, width: float) -> None:
    """A rounded two-seat sofa, centered on cx, with its feet resting on base_y."""
    u = width / 100.0  # one unit is 1% of the sofa's width
    left, right = cx - 50 * u, cx + 50 * u
    leg_h = 6 * u
    floor = base_y - leg_h

    # Legs
    for lx in (left + 10 * u, right - 14 * u):
        d.rounded_rectangle([lx, floor - 1 * u, lx + 4 * u, base_y], radius=1.2 * u, fill=SOFA_LEGS)

    # Back rest
    d.rounded_rectangle([left + 8 * u, floor - 52 * u, right - 8 * u, floor - 18 * u],
                        radius=11 * u, fill=SOFA)
    # Seat base
    d.rounded_rectangle([left + 6 * u, floor - 24 * u, right - 6 * u, floor],
                        radius=6 * u, fill=SOFA_SHADE)
    # Seat cushions, split by a seam
    d.rounded_rectangle([left + 14 * u, floor - 30 * u, right - 14 * u, floor - 14 * u],
                        radius=6 * u, fill=SOFA)
    d.rounded_rectangle([cx - 0.8 * u, floor - 29 * u, cx + 0.8 * u, floor - 15 * u],
                        radius=0.8 * u, fill=SOFA_SHADE)
    # Seam between the back cushions
    d.rounded_rectangle([cx - 0.8 * u, floor - 46 * u, cx + 0.8 * u, floor - 31 * u],
                        radius=0.8 * u, fill=SOFA_SHADE)
    # Arm rests
    for ax in (left, right - 16 * u):
        d.rounded_rectangle([ax, floor - 38 * u, ax + 16 * u, floor], radius=8 * u, fill=SOFA)


def draw_bubble(d: ImageDraw.ImageDraw, cx: float, cy: float, width: float) -> None:
    """A speech bubble with three dots and a tail pointing down and left."""
    w, h = width, width * 0.62
    x0, y0, x1, y1 = cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2
    d.rounded_rectangle([x0, y0, x1, y1], radius=h * 0.42, fill=BUBBLE)
    d.polygon([(x0 + w * 0.22, y1 - h * 0.05), (x0 + w * 0.42, y1 - h * 0.05),
               (x0 + w * 0.08, y1 + h * 0.34)], fill=BUBBLE)
    r = h * 0.11
    for i in (-1, 0, 1):
        dx = cx + i * w * 0.24
        d.ellipse([dx - r, cy - r, dx + r, cy + r], fill=DOTS)


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in ("/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf",
                 "/Library/Fonts/InterDisplay-Bold.otf",
                 "InterDisplay-Bold.otf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default(size)


def load_regular_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in ("/usr/share/fonts/opentype/inter/InterDisplay-Medium.otf",
                 "/Library/Fonts/InterDisplay-Medium.otf",
                 "InterDisplay-Medium.otf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default(size)


# Artwork

def icon_layers(w: int, h: int) -> dict[str, Image.Image]:
    """Back (opaque), Middle (sofa) and Front (bubble) layers for one icon size."""
    W, H = w * SUPERSAMPLE, h * SUPERSAMPLE
    back = gradient_background(W, H, glow_at=(0.12, 0.08))

    middle = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_sofa(ImageDraw.Draw(middle), cx=W * 0.46, base_y=H * 0.84, width=W * 0.56)

    front = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_bubble(ImageDraw.Draw(front), cx=W * 0.70, cy=H * 0.27, width=W * 0.24)

    return {name: img.resize((w, h), Image.LANCZOS)
            for name, img in (("Back", back), ("Middle", middle), ("Front", front))}


def top_shelf(w: int, h: int) -> Image.Image:
    """A wide banner: the sofa and bubble on the left, the name on the right."""
    W, H = w * SUPERSAMPLE, h * SUPERSAMPLE
    img = gradient_background(W, H, glow_at=(0.05, 0.0)).convert("RGBA")
    d = ImageDraw.Draw(img)

    art_cx = min(W * 0.22, H * 0.95)
    draw_sofa(d, cx=art_cx, base_y=H * 0.86, width=H * 1.05)
    draw_bubble(d, cx=art_cx + H * 0.42, cy=H * 0.24, width=H * 0.42)

    text_x = art_cx + H * 0.95
    title = load_font(round(H * 0.25))
    tag = load_regular_font(round(H * 0.075))
    d.text((text_x, H * 0.30), "Sofa Chat", font=title, fill=WORDMARK)
    d.text((text_x, H * 0.62), "Talk to an AI assistant from your couch.", font=tag, fill=TAGLINE)

    return img.convert("RGB").resize((w, h), Image.LANCZOS)


# Asset catalog

def write_json(path: Path, data: dict) -> None:
    path.mkdir(parents=True, exist_ok=True)
    (path / "Contents.json").write_text(json.dumps(data, indent=2) + "\n")


def write_imagestack(name: str, sizes: list[tuple[str, int, int]]) -> None:
    """sizes: (scale, width, height) for each image in each layer."""
    stack = BRAND / f"{name}.imagestack"
    layers = ["Front", "Middle", "Back"]
    write_json(stack, {"info": INFO,
                       "layers": [{"filename": f"{layer}.imagestacklayer"} for layer in layers]})
    rendered = {scale: icon_layers(w, h) for scale, w, h in sizes}
    for layer in layers:
        layer_dir = stack / f"{layer}.imagestacklayer"
        write_json(layer_dir, {"info": INFO})
        imageset = layer_dir / "Content.imageset"
        images = []
        for scale, w, h in sizes:
            filename = f"{layer.lower()}-{w}x{h}.png"
            imageset.mkdir(parents=True, exist_ok=True)
            rendered[scale][layer].save(imageset / filename, optimize=True)
            images.append({"filename": filename, "idiom": "tv", "scale": scale})
        write_json(imageset, {"images": images, "info": INFO})


def write_top_shelf(name: str, sizes: list[tuple[str, int, int]]) -> None:
    imageset = BRAND / f"{name}.imageset"
    images = []
    for scale, w, h in sizes:
        filename = f"top-shelf-{w}x{h}.png"
        imageset.mkdir(parents=True, exist_ok=True)
        top_shelf(w, h).save(imageset / filename, optimize=True)
        images.append({"filename": filename, "idiom": "tv", "scale": scale})
    write_json(imageset, {"images": images, "info": INFO})


def main() -> None:
    write_json(CATALOG, {"info": INFO})
    write_json(BRAND, {"info": INFO, "assets": [
        {"filename": "App Icon - App Store.imagestack", "idiom": "tv",
         "role": "primary-app-icon", "size": "1280x768"},
        {"filename": "App Icon.imagestack", "idiom": "tv",
         "role": "primary-app-icon", "size": "400x240"},
        {"filename": "Top Shelf Image Wide.imageset", "idiom": "tv",
         "role": "top-shelf-image-wide", "size": "2320x720"},
        {"filename": "Top Shelf Image.imageset", "idiom": "tv",
         "role": "top-shelf-image", "size": "1920x720"},
    ]})
    write_imagestack("App Icon", [("1x", 400, 240), ("2x", 800, 480)])
    write_imagestack("App Icon - App Store", [("1x", 1280, 768)])
    write_top_shelf("Top Shelf Image", [("1x", 1920, 720), ("2x", 3840, 1440)])
    write_top_shelf("Top Shelf Image Wide", [("1x", 2320, 720), ("2x", 4640, 1440)])
    docs = ROOT / "docs"
    docs.mkdir(exist_ok=True)
    top_shelf(1450, 450).save(docs / "banner.png", optimize=True)  # the README banner
    print(f"Wrote artwork to {BRAND.relative_to(ROOT)} and docs/banner.png")


if __name__ == "__main__":
    main()
