"""Generate app icons from blob.png for Android launcher + web."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import numpy as np
import sys

ROOT = Path(__file__).parent.parent
SRC  = ROOT / "assets" / "blob.png"
OUT  = ROOT / "assets" / "icons"
OUT.mkdir(exist_ok=True)

def remove_bg(img: Image.Image) -> Image.Image:
    """
    Remove the gradient sky/ground background using saturation gating
    + flood-fill from border seeds to avoid removing shadow on the blob itself.
    Background = low-saturation bluish-white gradient.
    Blob        = high-saturation rich blue.
    """
    img = img.convert("RGBA")
    arr = np.array(img, dtype=np.float32)
    h, w = arr.shape[:2]

    r, g, b = arr[:,:,0], arr[:,:,1], arr[:,:,2]
    cmax = np.maximum(np.maximum(r, g), b)
    cmin = np.minimum(np.minimum(r, g), b)
    lightness  = (cmax + cmin) / 2.0
    chroma     = cmax - cmin
    saturation = np.where(cmax == 0, 0.0, chroma / cmax)

    # Hue (degrees, 0-360) — sky is cyan-blue ~190-210°, blob is royal-blue ~210-230°
    hue = np.zeros_like(r)
    eps = 1e-6
    mask_r = (cmax == r) & (chroma > eps)
    mask_g = (cmax == g) & (chroma > eps)
    mask_b = (cmax == b) & (chroma > eps)
    hue[mask_r] = (60 * ((g[mask_r] - b[mask_r]) / chroma[mask_r])) % 360
    hue[mask_g] = (60 * ((b[mask_g] - r[mask_g]) / chroma[mask_g]) + 120)
    hue[mask_b] = (60 * ((r[mask_b] - g[mask_b]) / chroma[mask_b]) + 240)

    # Background = washed-out white/light OR cyan-leaning sky blue (hue 175-215, sat < 0.6)
    # Blob body  = deeper royal blue (hue ~215-235, sat > 0.4, not too bright)
    is_sky    = (hue >= 175) & (hue < 218) & (saturation < 0.60) & (lightness > 110)
    is_ground = (lightness > 195)
    bg_mask   = is_sky | is_ground

    # Flood-fill from every border pixel to only erase CONNECTED background
    # (prevents eating shadow/dark areas inside the blob)
    reachable = np.zeros((h, w), dtype=bool)
    visited   = np.zeros((h, w), dtype=bool)
    stack = []
    for bx in range(w):
        if bg_mask[0, bx]:   stack.append((0, bx))
        if bg_mask[h-1, bx]: stack.append((h-1, bx))
    for by in range(h):
        if bg_mask[by, 0]:   stack.append((by, 0))
        if bg_mask[by, w-1]: stack.append((by, w-1))

    while stack:
        y, x = stack.pop()
        if visited[y, x]: continue
        visited[y, x] = True
        if bg_mask[y, x]:
            reachable[y, x] = True
            for dy, dx in ((-1,0),(1,0),(0,-1),(0,1)):
                ny, nx_ = y+dy, x+dx
                if 0 <= ny < h and 0 <= nx_ < w and not visited[ny, nx_]:
                    stack.append((ny, nx_))

    alpha = np.array(img.getchannel("A"), dtype=np.uint8)
    alpha[reachable] = 0

    result = Image.fromarray(arr.astype(np.uint8), "RGBA")
    result.putalpha(Image.fromarray(alpha))
    # Light erode to clean fringe
    a_ch = result.getchannel("A").filter(ImageFilter.MinFilter(3))
    result.putalpha(a_ch)
    return result


def make_icon(src: Image.Image, size: int, bg_color=None) -> Image.Image:
    """Resize src onto a square canvas, centered with padding."""
    pad = int(size * 0.08)
    inner = size - pad * 2
    src_copy = src.copy()
    src_copy.thumbnail((inner, inner), Image.LANCZOS)
    iw, ih = src_copy.size
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if bg_color:
        canvas = Image.new("RGBA", (size, size), bg_color)
    x = (size - iw) // 2
    y = (size - ih) // 2
    canvas.paste(src_copy, (x, y), src_copy)
    return canvas


def rounded_rect_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, size-1, size-1], radius=radius, fill=255)
    return mask


def save(img: Image.Image, path: Path, rounded=False):
    if rounded:
        r = int(img.width * 0.22)
        mask = rounded_rect_mask(img.width, r)
        out = Image.new("RGBA", img.size, (0, 0, 0, 0))
        out.paste(img, mask=mask)
        img = out
    img.save(path)
    print(f"  wrote {path.relative_to(ROOT)}  ({img.width}x{img.height})")


# ── Load & strip background ────────────────────────────────────────────────
print("Loading blob.png …")
raw = Image.open(SRC).convert("RGBA")
fg  = remove_bg(raw)

# Light edge anti-alias
fg = fg.filter(ImageFilter.SMOOTH)

# Background fill color (royal blue matching the blob)
BG_BLUE  = (76, 144, 222, 255)   # icon bg
BG_LIGHT = (200, 225, 255, 255)  # adaptive bg (lighter ring)

# ── Main launcher icon: 192×192 ────────────────────────────────────────────
print("\nGenerating icons …")
icon_192 = make_icon(fg, 192, bg_color=BG_BLUE)
save(icon_192, OUT / "icon_192.png")

# Also a rounded version (looks better on most launchers)
save(make_icon(fg, 192, bg_color=BG_BLUE), OUT / "icon_192_rounded.png", rounded=True)

# ── Adaptive foreground: 432×432 (blob, no background) ────────────────────
adpt_fg = make_icon(fg, 432)
save(adpt_fg, OUT / "adaptive_fg_432.png")

# ── Adaptive background: 432×432 (solid blue) ─────────────────────────────
adpt_bg = Image.new("RGBA", (432, 432), BG_BLUE)
save(adpt_bg, OUT / "adaptive_bg_432.png")

# ── Web / store icon: 512×512 ─────────────────────────────────────────────
web_512 = make_icon(fg, 512, bg_color=BG_BLUE)
save(web_512, OUT / "icon_512.png")
save(make_icon(fg, 512, bg_color=BG_BLUE), OUT / "icon_512_rounded.png", rounded=True)

# ── Small icon: 48×48 (notification / favicon) ────────────────────────────
small_48 = make_icon(fg, 48, bg_color=BG_BLUE)
save(small_48, OUT / "icon_48.png")

print("\nDone — all icons saved to assets/icons/")
