#!/usr/bin/env python3
"""Generate NestKeep launcher icons (ic_launcher.png) for all densities,
plus the 512px brand artwork used in-app (app/assets/icon.png).

The repo snapshot carries no binary files, so the PNGs are drawn here in
CI before the Android build. Design: deep navy rounded square, a white
roof chevron, and a woven amber nest holding two eggs (one cream, one
purple, the app accent). Bold shapes only, so the nest reads at 48px.
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
NAVY = (10, 30, 70, 255)        # #0A1E46
WHITE = (255, 255, 255, 255)
CREAM = (247, 243, 233, 255)    # egg cream
EGG_PURPLE = (109, 77, 246, 255)  # egg in the accent purple #6D4DF6
AMBER = (245, 166, 35, 255)     # #F5A623 nest straw
RUST = (199, 101, 38, 255)      # nest shadow tone
DARK = (146, 64, 14, 255)       # nest deep tone


def draw(size):
    s = size * 4  # supersample for smooth edges
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.22), fill=NAVY)

    def X(f):
        return f * s

    # Roof chevron above the nest.
    w = max(2, int(s * 0.058))
    d.line(
        [(X(0.265), X(0.355)), (X(0.50), X(0.185)), (X(0.735), X(0.355))],
        fill=WHITE,
        width=w,
        joint="curve",
    )
    # Round the chevron joints/ends.
    for px, py in ((0.265, 0.355), (0.50, 0.185), (0.735, 0.355)):
        d.ellipse(
            [X(px) - w / 2, X(py) - w / 2, X(px) + w / 2, X(py) + w / 2],
            fill=WHITE,
        )

    # Eggs first: the bowl is painted over their bottoms so they sit IN
    # the nest. Right egg slightly lower and behind the left one.
    d.ellipse([X(0.478), X(0.405), X(0.648), X(0.725)], fill=EGG_PURPLE)
    d.ellipse([X(0.352), X(0.385), X(0.522), X(0.72)], fill=CREAM)

    # Bowl silhouette: a filled half-ellipse in the rust tone.
    d.pieslice([X(0.17), X(0.47), X(0.83), X(0.85)], start=0, end=180,
               fill=RUST)
    # Woven bands: lower-half arcs in alternating straw tones, each
    # lower and tighter, following the bowl's curve.
    arc_w = max(2, int(s * 0.046))
    for x1, y1, x2, y2, color in (
        (0.20, 0.515, 0.80, 0.85, AMBER),
        (0.235, 0.565, 0.765, 0.855, DARK),
        (0.275, 0.615, 0.725, 0.85, AMBER),
    ):
        d.arc([X(x1), X(y1), X(x2), X(y2)], start=0, end=180,
              fill=color, width=arc_w)
    # Front rim: one thick amber arc on a flatter ellipse, crossing in
    # front of the eggs so they read as nestled behind it.
    d.arc([X(0.155), X(0.575), X(0.845), X(0.735)], start=0, end=180,
          fill=AMBER, width=max(2, int(s * 0.058)))

    return img.resize((size, size), Image.LANCZOS)


def main():
    root = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "app")
    res = os.path.join(root, "android", "app", "src", "main", "res")
    for folder, size in SIZES.items():
        out = os.path.join(res, folder)
        os.makedirs(out, exist_ok=True)
        path = os.path.join(out, "ic_launcher.png")
        draw(size).save(path)
        print("wrote", path, size)
    # Brand artwork for the intro and splash screens.
    asset = os.path.join(root, "assets", "icon.png")
    os.makedirs(os.path.dirname(asset), exist_ok=True)
    draw(512).save(asset)
    print("wrote", asset, 512)


if __name__ == "__main__":
    main()
