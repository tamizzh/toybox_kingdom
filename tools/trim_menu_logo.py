from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "logo" / "logo.png"
DST = ROOT / "assets" / "ui" / "menu_logo.png"


def main() -> None:
    img = Image.open(SRC).convert("RGBA")
    bbox = img.getbbox()
    if bbox is None:
        raise SystemExit("Logo image is empty.")

    trimmed = img.crop(bbox)
    DST.parent.mkdir(parents=True, exist_ok=True)
    trimmed.save(DST, "PNG")
    print(f"Saved trimmed logo to {DST}")


if __name__ == "__main__":
    main()
