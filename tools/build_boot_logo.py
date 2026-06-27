"""Build a LOGO boot splash: the TOYBOX KINGDOMS logo (assets/logo.png, already
has correct alpha) centered on a brand vignette that fades to exactly
boot_splash/bg_color (#181426) at every edge -- so Godot's contain-letterbox is
INVISIBLE on any aspect (19.5:9, 4:3, near-square folds, ultrawide).

Source logo: assets/logo.png (RGBA, proper transparent bg -- use this directly)
Output:      assets/splash.png  (boot_splash/image)

Run:  python tools/build_boot_logo.py
"""
import numpy as np
from PIL import Image, ImageFilter

LOGO = "assets/logo.png"
DST  = "assets/splash.png"

OUT_W, OUT_H = 1920, 1080  # 16:9 canvas — letterbox bars on all sides are same BG

BG   = np.array([24, 20, 38],  dtype=np.float32)  # #181426 == boot_splash/bg_color
GLOW = np.array([54, 44, 92],  dtype=np.float32)  # brand purple central lift

LOGO_W      = 1000   # logo rendered width on canvas
LOGO_CY     = 0.46  # slightly above true center (optical centering, crown needs headroom)
SHADOW_OFF  = 28    # drop shadow nudge down (px)
SHADOW_BLUR = 32    # drop shadow blur radius
SHADOW_A    = 160   # drop shadow opacity (0-255)
EDGE_FEATHER = 110  # px: force canvas border to exact BG (seamless letterbox)


def smoothstep(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def axis_ramp(n, m):
    i = np.arange(n, dtype=np.float32)
    return np.minimum(smoothstep(i / m), smoothstep((n - 1 - i) / m))


def main():
    logo = Image.open(LOGO).convert("RGBA")
    lw, lh = logo.size
    logo_h = round(LOGO_W * lh / lw)
    logo = logo.resize((LOGO_W, logo_h), Image.LANCZOS)

    # --- 1. Brand vignette: central glow -> BG, exact BG forced at edges --------
    yy, xx = np.mgrid[0:OUT_H, 0:OUT_W].astype(np.float32)
    cx, cy = OUT_W / 2.0, OUT_H * LOGO_CY
    r = np.sqrt(((xx - cx) / (OUT_W * 0.68)) ** 2 + ((yy - cy) / (OUT_H * 0.68)) ** 2)
    t = smoothstep(r)[..., None]
    field = (1.0 - t) * GLOW + t * BG
    fx = axis_ramp(OUT_W, EDGE_FEATHER)[None, :, None]
    fy = axis_ramp(OUT_H, EDGE_FEATHER)[:, None, None]
    f  = np.minimum(fx, fy)
    field = f * field + (1.0 - f) * BG
    canvas = Image.fromarray(np.clip(field, 0, 255).astype(np.uint8), "RGB").convert("RGBA")

    # --- 2. Drop shadow (blurred alpha mask of the logo, nudged down) -----------
    lx = (OUT_W - LOGO_W) // 2
    ly = int(OUT_H * LOGO_CY - logo_h / 2)
    shadow_layer = Image.new("RGBA", (OUT_W, OUT_H), (0, 0, 0, 0))
    shadow_src   = Image.new("RGBA", (LOGO_W, logo_h), (0, 0, 0, SHADOW_A))
    shadow_src.putalpha(logo.getchannel("A").point(lambda p: int(p * SHADOW_A / 255)))
    shadow_layer.alpha_composite(shadow_src, (lx, ly + SHADOW_OFF))
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(SHADOW_BLUR))
    canvas = Image.alpha_composite(canvas, shadow_layer)

    # --- 3. Logo composited on top ----------------------------------------------
    canvas.alpha_composite(logo, (lx, ly))

    canvas.convert("RGB").save(DST)
    print(f"BOOT_LOGO_BUILT: {DST} ({OUT_W}x{OUT_H}) logo {LOGO_W}x{logo_h} at ({lx},{ly})")


if __name__ == "__main__":
    main()
