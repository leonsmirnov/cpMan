#!/usr/bin/env python3
"""
Generate the cpMan AppIcon: geometric "CP" monogram (single stroke weight) in a rounded square.

Requires: pip install Pillow
Usage:
  python3 scripts/generate-app-icon.py
  python3 scripts/generate-app-icon.py --bg '#1E3A5F' --fg '#F0F4FF'
"""
from __future__ import annotations

import argparse
import math
import pathlib
import subprocess
import sys


def _require_pil():
    try:
        from PIL import Image, ImageDraw  # noqa: F401
    except ImportError:
        print("Install Pillow:  python3 -m pip install Pillow", file=sys.stderr)
        sys.exit(1)
    from PIL import Image, ImageDraw

    return Image, ImageDraw


def _hex_rgb(s: str) -> tuple[int, int, int]:
    s = s.strip().lstrip("#")
    if len(s) == 6:
        return int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16)
    raise ValueError(f"Expected #RRGGBB, got {s!r}")


def _annular_sector(
    draw,
    cx: float,
    cy: float,
    r_outer: float,
    r_inner: float,
    deg0: float,
    deg1: float,
    fill,
    *,
    n: int = 96,
) -> None:
    """Filled ring sector. Angles in degrees, mathematics convention (CCW from +x, y up)."""
    if r_inner < 0:
        r_inner = 0
    lo, hi = min(deg0, deg1), max(deg0, deg1)
    pts: list[tuple[float, float]] = []
    for i in range(n + 1):
        t = math.radians(lo + (hi - lo) * (i / n))
        pts.append((cx + r_outer * math.cos(t), cy - r_outer * math.sin(t)))
    for i in range(n + 1):
        t = math.radians(hi - (hi - lo) * (i / n))
        pts.append((cx + r_inner * math.cos(t), cy - r_inner * math.sin(t)))
    draw.polygon(pts, fill=fill)


def _rounded_rect(draw, xy, radius: float, fill) -> None:
    draw.rounded_rectangle(xy, radius=radius, fill=fill)


def render_master(
    *,
    size: int = 1024,
    supersample: int = 2,
    bg: tuple[int, int, int],
    fg: tuple[int, int, int],
):
    Image, ImageDraw = _require_pil()
    s = max(1, supersample)
    S = size * s
    img = Image.new("RGB", (S, S), bg)
    draw = ImageDraw.Draw(img)

    # --- Layout (proportions tuned for 16×16 legibility) ---
    pad = 0.10 * S
    r_card = 0.20 * S

    _rounded_rect(draw, (0, 0, S - 1, S - 1), r_card, fill=bg)

    inner_w = S - 2 * pad
    # Stroke width ~12% of letter cap height
    cap = 0.68 * inner_w
    W = 0.12 * cap
    cx0 = S / 2
    cy0 = S / 2

    # "C": left-opening annular arc; circle center sits right of the curve (opening toward P).
    r_c = 0.38 * cap
    cx_c = cx0 - 0.065 * cap - 0.16 * W
    a0_c, a1_c = 118.0, 242.0
    _annular_sector(draw, cx_c, cy0, r_c + W / 2, r_c - W / 2, a0_c, a1_c, fg)

    # "P": bowl first, then stem on top so the join reads solid at small sizes
    stem_left = cx0 + 0.095 * cap
    stem_right = stem_left + W
    y_top = cy0 - cap / 2
    y_bot = cy0 + cap / 2
    stem_rad = W / 2

    r_p = 0.40 * cap
    cx_p = stem_right + r_p * 0.62
    cy_p = y_top + r_p * 0.72
    _annular_sector(draw, cx_p, cy_p, r_p + W / 2, r_p - W / 2, 38.0, 142.0, fg)

    _rounded_rect(draw, (stem_left, y_top, stem_right, y_bot), stem_rad, fill=fg)

    if s > 1:
        img = img.resize((size, size), Image.Resampling.LANCZOS)
    return img


def _sips_resize(src: pathlib.Path, out: pathlib.Path, w: int, h: int) -> None:
    subprocess.run(
        ["sips", "-z", str(h), str(w), str(src), "--out", str(out)],
        check=True,
        stdout=subprocess.DEVNULL,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bg", default="#1E3A5F", help="Background #RRGGBB")
    parser.add_argument("--fg", default="#EEF2FF", help="Monogram #RRGGBB")
    parser.add_argument("--size", type=int, default=1024)
    parser.add_argument("--no-sips", action="store_true", help="Only write master PNG")
    args = parser.parse_args()

    bg = _hex_rgb(args.bg)
    fg = _hex_rgb(args.fg)
    repo = pathlib.Path(__file__).resolve().parent.parent
    asset = repo / "Sources/cpMan/Resources/Assets.xcassets/AppIcon.appiconset"
    asset.mkdir(parents=True, exist_ok=True)

    im = render_master(size=args.size, supersample=2, bg=bg, fg=fg)
    out512 = asset / "icon_512x512@2x.png"
    im.save(out512, format="PNG")

    if args.no_sips:
        print(out512)
        print(
            "Only wrote 1024 master; run without --no-sips on macOS to refresh other sizes.",
            file=sys.stderr,
        )
        return
    if sys.platform != "darwin":
        print(out512)
        print(
            "Only wrote 1024 master; run on macOS to resize with sips.",
            file=sys.stderr,
        )
        return

    m = out512
    _sips_resize(m, asset / "icon_512x512.png", 512, 512)
    _sips_resize(m, asset / "icon_256x256@2x.png", 512, 512)
    _sips_resize(m, asset / "icon_256x256.png", 256, 256)
    _sips_resize(m, asset / "icon_128x128@2x.png", 256, 256)
    _sips_resize(m, asset / "icon_128x128.png", 128, 128)
    _sips_resize(m, asset / "icon_32x32@2x.png", 64, 64)
    _sips_resize(m, asset / "icon_32x32.png", 32, 32)
    _sips_resize(m, asset / "icon_16x16@2x.png", 32, 32)
    _sips_resize(m, asset / "icon_16x16.png", 16, 16)

    print(out512)


if __name__ == "__main__":
    main()
