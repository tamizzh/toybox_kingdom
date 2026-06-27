"""Build the boot-splash image as a FULL-BLEED composite so it shows no black
bars on the real targets, matching the in-game menu background.

Godot's boot splash can only *contain* (letterbox) a single static image -- it
has no cover/fill mode. So instead of shipping a bare 16:9 poster (which Godot
pads with bg_color -> dark bars on every wider-than-16:9 screen), we bake the
menu's two-layer look (ui/main_menu.gd _build_background) straight into the
image at the window's own aspect (1560x720 = 2.167:1):

  1. Backdrop: the art scaled to COVER the canvas, blurred + dimmed toward the
     boot bg colour -- fills every pixel, so there is no flat bar to see.
  2. Poster:   the crisp original centred on top, its left/right edges feathered
     into the backdrop so there's no hard seam (just like the menu's centred
     poster over its covered backdrop).
  3. A light feather of the outer canvas edge into bg_color hides the small
     residual letterbox bars on aspect ratios that differ from 2.167:1.

Source art:  tools/art_src/splash_source.png  (pristine 1280x720 marketing
             render; folder has a .gdignore so Godot never imports/bundles it)
Output:      assets/splash.png               (boot_splash/image)

Run:  python tools/build_splash.py
"""
import numpy as np
from PIL import Image, ImageFilter

SRC = "tools/art_src/splash_source.png"
DST = "assets/splash.png"

# Output aspect = the display/window aspect (project.godot 1560x720) so the boot
# splash fills the desktop window and ~19.5:9 phones with no/near-no bars.
OUT_W, OUT_H = 1560, 720

# Must match application/boot_splash/bg_color in project.godot (#181426).
BG = np.array([24, 20, 38], dtype=np.float32)

DIM = 0.50            # how far the backdrop is pulled toward BG (0=art, 1=flat BG)
BLUR = 6.0            # backdrop blur so it recedes behind the crisp poster
POSTER_FEATHER = 150  # px: poster L/R edges melt into the backdrop
EDGE_FEATHER = 70     # px: outer canvas edges melt into BG (residual letterbox)


def smoothstep(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def axis_ramp(n, left, right):
    """1.0 in the middle, smoothly ramping to 0 over `left`/`right` px at ends."""
    i = np.arange(n, dtype=np.float32)
    r = np.ones(n, dtype=np.float32)
    if left > 0:
        r = np.minimum(r, smoothstep(i / left))
    if right > 0:
        r = np.minimum(r, smoothstep((n - 1 - i) / right))
    return r


def main():
    src = Image.open(SRC).convert("RGB")
    sw, sh = src.size

    # --- 1. Backdrop: cover the canvas, blur, dim toward BG -------------------
    scale = max(OUT_W / sw, OUT_H / sh)
    bw, bh = round(sw * scale), round(sh * scale)
    back = src.resize((bw, bh), Image.LANCZOS)
    left, top = (bw - OUT_W) // 2, (bh - OUT_H) // 2
    back = back.crop((left, top, left + OUT_W, top + OUT_H))
    back = back.filter(ImageFilter.GaussianBlur(BLUR))
    canvas = (1.0 - DIM) * np.asarray(back, np.float32) + DIM * BG  # HxWx3

    # --- 2. Poster: crisp original centred, L/R feathered into the backdrop ---
    px = (OUT_W - sw) // 2
    py = (OUT_H - sh) // 2
    poster = np.asarray(src, np.float32)
    alpha = axis_ramp(sw, POSTER_FEATHER, POSTER_FEATHER)[None, :, None]  # 1xWx1
    region = canvas[py:py + sh, px:px + sw, :]
    canvas[py:py + sh, px:px + sw, :] = alpha * poster + (1.0 - alpha) * region

    # --- 3. Outer edge feather into BG (hides residual letterbox bars) --------
    fx = axis_ramp(OUT_W, EDGE_FEATHER, EDGE_FEATHER)[None, :, None]
    fy = axis_ramp(OUT_H, EDGE_FEATHER, EDGE_FEATHER)[:, None, None]
    f = np.minimum(fx, fy)
    canvas = f * canvas + (1.0 - f) * BG

    out = Image.fromarray(np.clip(canvas, 0, 255).astype(np.uint8), "RGB")
    out.save(DST)
    print(f"SPLASH_BUILT: {DST} ({OUT_W}x{OUT_H})")


if __name__ == "__main__":
    main()
