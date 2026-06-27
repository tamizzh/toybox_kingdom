"""Slice assets/main_men_atlas.png into individual button PNGs under assets/ui/buttons/.
Run: python tools/slice_menu_atlas.py
The menu code (ui/main_menu.gd) uses AtlasTexture to reference these regions directly
from the atlas at runtime — slicing is only needed if individual exports are required.
"""
from PIL import Image
from pathlib import Path

SRC = "assets/main_men_atlas.png"
OUT = Path("assets/ui/buttons")
OUT.mkdir(parents=True, exist_ok=True)

REGIONS = {
    "play":      (215,  82,  809, 267),
    "kingdom":   (224, 383,  538, 649),
    "shop":      (606, 383,  929, 649),
    "rewards":   (1000,383, 1324, 649),
    "settings":  (121, 718,  385, 889),
    "howtoplay": (452, 718,  721, 889),
    "coinbar":   (796, 718, 1422, 889),
}

im = Image.open(SRC).convert("RGBA")
for name, (x1, y1, x2, y2) in REGIONS.items():
    crop = im.crop((x1, y1, x2, y2))
    out = OUT / f"{name}.png"
    crop.save(out)
    print(f"  {name}: {x2-x1}x{y2-y1} -> {out}")
print("Done.")
