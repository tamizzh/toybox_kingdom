from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(r"C:\Users\rpandian\Downloads\Firefly_remove background 963790.png")
DEST = ROOT / "assets" / "sprites"

SHEET_W = 1024
SHEET_H = 1024
COLS = 3
ROWS = 4
CELL_W = SHEET_W // COLS
CELL_H = SHEET_H // ROWS
INNER_PAD = 20

# Best matching cells from the sheet for the required gameplay bodies.
SPRITES = {
    "tank_battle.png": (0, 0),
    "snake_battle.png": (1, 0),
    "blob_growth.png": (2, 0),
    "lava_rising.png": (0, 1),
    "bomb_throw.png": (1, 1),
    "sprint_race.png": (0, 2),
    "virus_spread.png": (1, 2),
    "mini_soccer.png": (2, 2),
    "sumo_push.png": (1, 3),
    "reaction_tap.png": (2, 3),
}


def trim_to_content(img: Image.Image, pad: int = 8) -> Image.Image:
    bbox = img.getbbox()
    if bbox is None:
        return img
    left = max(0, bbox[0] - pad)
    top = max(0, bbox[1] - pad)
    right = min(img.width, bbox[2] + pad)
    bottom = min(img.height, bbox[3] + pad)
    return img.crop((left, top, right, bottom))


def fit_to_canvas(img: Image.Image, size: int = 256, pad: int = 12) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    scale = min((size - pad * 2) / img.width, (size - pad * 2) / img.height)
    resized = img.resize(
        (max(1, int(img.width * scale)), max(1, int(img.height * scale))),
        Image.LANCZOS,
    )
    x = (size - resized.width) // 2
    y = (size - resized.height) // 2
    canvas.alpha_composite(resized, (x, y))
    return canvas


def remove_face_details(img: Image.Image, filename: str) -> Image.Image:
    draw = ImageDraw.Draw(img)
    white = (255, 255, 255, 255)

    if filename == "virus_spread.png":
        draw.ellipse((82, 90, 176, 152), fill=white)
    elif filename == "lava_rising.png":
        draw.ellipse((92, 74, 164, 122), fill=white)
    elif filename == "reaction_tap.png":
        draw.ellipse((96, 52, 176, 124), fill=white)
        draw.ellipse((140, 120, 206, 182), fill=white)

    return img


def crop_cell(sheet: Image.Image, col: int, row: int) -> Image.Image:
    left = col * CELL_W + INNER_PAD
    top = row * CELL_H + INNER_PAD
    right = (col + 1) * CELL_W - INNER_PAD
    bottom = (row + 1) * CELL_H - INNER_PAD
    return sheet.crop((left, top, right, bottom))


def main() -> None:
    sheet = Image.open(SOURCE).convert("RGBA")
    DEST.mkdir(parents=True, exist_ok=True)

    for filename, (col, row) in SPRITES.items():
        img = crop_cell(sheet, col, row)
        img = trim_to_content(img, pad=8)
        img = fit_to_canvas(img, size=256, pad=12)
        img = remove_face_details(img, filename)
        img.save(DEST / filename, "PNG")

    print(f"Imported {len(SPRITES)} sprite bodies from Firefly sheet.")


if __name__ == "__main__":
    main()
