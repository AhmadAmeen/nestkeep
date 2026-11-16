#!/usr/bin/env python3
"""Generate NestKeep launcher icons (ic_launcher.png) for all densities.

The repo snapshot carries no binary files, so the mipmap PNGs are drawn
here in CI before the Android build. Design: navy rounded square, cream
house with a blue door, matching the app's brand tokens.
"""
import os

from PIL import Image, ImageDraw

SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
NAVY = (10, 30, 70, 255)      # #0A1E46
CREAM = (247, 243, 233, 255)  # paper cream
BLUE = (36, 86, 214, 255)     # #2456D6


def draw(size):
    s = size * 4  # supersample for smooth edges
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = int(s * 0.22)
    d.rounded_rectangle([0, 0, s - 1, s - 1], radius=r, fill=NAVY)
    cx = s / 2
    half = s * 0.26
    # roof
    d.polygon(
        [(cx, s * 0.24), (cx - half - s * 0.05, s * 0.48),
         (cx + half + s * 0.05, s * 0.48)],
        fill=CREAM,
    )
    # body
    d.rectangle([cx - half, s * 0.46, cx + half, s * 0.76], fill=CREAM)
    # door
    dw = s * 0.11
    d.rounded_rectangle(
        [cx - dw / 2, s * 0.58, cx + dw / 2, s * 0.76],
        radius=int(dw * 0.4),
        fill=BLUE,
    )
    return img.resize((size, size), Image.LANCZOS)


def main():
    base = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "app", "android",
        "app", "src", "main", "res",
    )
    for folder, size in SIZES.items():
        out = os.path.join(base, folder)
        os.makedirs(out, exist_ok=True)
        path = os.path.join(out, "ic_launcher.png")
        draw(size).save(path)
        print("wrote", path, size)


if __name__ == "__main__":
    main()
