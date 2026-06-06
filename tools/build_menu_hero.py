from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets" / "sprites"
OUT = ROOT / "assets" / "ui" / "menu_hero.png"

SIZE = (1400, 980)
OUTLINE = (18, 24, 34, 255)
WHITE = (255, 255, 255, 255)
GOLD = (246, 194, 52, 255)
GOLD_DARK = (220, 158, 18, 255)
GOLD_LIGHT = (255, 228, 122, 255)
CORAL = (245, 98, 92, 255)
BLUE = (65, 153, 247, 255)
GREEN = (94, 194, 103, 255)
YELLOW = (248, 208, 73, 255)
SHADOW = (0, 0, 0, 36)


def load_sprite(name: str, max_size: tuple[int, int]) -> Image.Image:
    img = Image.open(SPRITES / name).convert("RGBA")
    img.thumbnail(max_size, Image.LANCZOS)
    return img


def paste_centered(canvas: Image.Image, img: Image.Image, center: tuple[int, int], shadow_offset=(0, 16)) -> None:
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    mask = img.getchannel("A")
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.bitmap((0, 0), mask, fill=SHADOW)
    sx = int(center[0] - img.width / 2 + shadow_offset[0])
    sy = int(center[1] - img.height / 2 + shadow_offset[1])
    canvas.alpha_composite(shadow, (sx, sy))
    x = int(center[0] - img.width / 2)
    y = int(center[1] - img.height / 2)
    canvas.alpha_composite(img, (x, y))


def rounded(draw: ImageDraw.ImageDraw, box, radius, fill, outline=OUTLINE, width=12) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=outline)
    inner = (box[0] + width, box[1] + width, box[2] - width, box[3] - width)
    draw.rounded_rectangle(inner, radius=max(4, radius - width), fill=fill)


def ellipse(draw: ImageDraw.ImageDraw, box, fill, outline=OUTLINE, width=12) -> None:
    draw.ellipse(box, fill=outline)
    inner = (box[0] + width, box[1] + width, box[2] - width, box[3] - width)
    draw.ellipse(inner, fill=fill)


def polygon(draw: ImageDraw.ImageDraw, pts, fill, outline=OUTLINE, width=12) -> None:
    draw.polygon(pts, fill=outline)
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    inner = []
    for x, y in pts:
        inner.append((cx + (x - cx) * 0.82, cy + (y - cy) * 0.82))
    draw.polygon(inner, fill=fill)


def star_points(cx: float, cy: float, r1: float, r2: float, n: int = 5) -> list[tuple[float, float]]:
    pts = []
    from math import cos, pi, sin
    for i in range(n * 2):
        a = -pi / 2 + i * pi / n
        r = r1 if i % 2 == 0 else r2
        pts.append((cx + cos(a) * r, cy + sin(a) * r))
    return pts


def draw_trophy(canvas: Image.Image, center: tuple[int, int]) -> None:
    draw = ImageDraw.Draw(canvas)
    cx, cy = center

    # shadow
    draw.ellipse((cx - 138, cy + 194, cx + 138, cy + 236), fill=(0, 0, 0, 22))

    rounded(draw, (cx - 130, cy + 78, cx + 130, cy + 164), 16, GOLD, width=12)
    rounded(draw, (cx - 32, cy - 28, cx + 32, cy + 112), 18, GOLD, width=12)
    rounded(draw, (cx - 60, cy + 116, cx + 60, cy + 182), 18, GOLD_DARK, width=12)
    rounded(draw, (cx - 148, cy + 174, cx + 148, cy + 258), 20, GOLD_DARK, width=12)
    rounded(draw, (cx - 78, cy + 196, cx + 78, cy + 238), 12, GOLD_LIGHT, width=8)

    cup = [(cx - 178, cy - 118), (cx + 178, cy - 118), (cx + 134, cy + 36), (cx - 134, cy + 36)]
    polygon(draw, cup, GOLD_LIGHT, width=14)

    # handles
    draw.arc((cx - 250, cy - 96, cx - 62, cy + 54), start=248, end=86, fill=OUTLINE, width=16)
    draw.arc((cx + 62, cy - 96, cx + 250, cy + 54), start=94, end=292, fill=OUTLINE, width=16)
    draw.arc((cx - 230, cy - 78, cx - 84, cy + 38), start=248, end=86, fill=GOLD, width=12)
    draw.arc((cx + 84, cy - 78, cx + 230, cy + 38), start=94, end=292, fill=GOLD, width=12)

    # shine and star
    draw.rounded_rectangle((cx - 98, cy - 78, cx - 70, cy + 28), radius=14, fill=(255, 255, 255, 190))
    polygon(draw, star_points(cx, cy - 28, 54, 24), GOLD, outline=GOLD_DARK, width=8)


def add_confetti(draw: ImageDraw.ImageDraw) -> None:
    pieces = [
        ((180, 190, 232, 244), CORAL),
        ((324, 824, 380, 874), BLUE),
        ((1042, 838, 1100, 886), GREEN),
        ((1170, 790, 1228, 846), YELLOW),
        ((1090, 222, 1148, 274), BLUE),
        ((128, 590, 186, 646), CORAL),
        ((946, 126, 1004, 180), GREEN),
        ((764, 140, 822, 196), YELLOW),
    ]
    for box, color in pieces:
        draw.rounded_rectangle(box, radius=18, fill=color)

    for x, y, r, c in [
        (292, 922, 22, BLUE),
        (1122, 348, 22, BLUE),
        (844, 890, 16, CORAL),
        (698, 244, 20, YELLOW),
    ]:
        draw.ellipse((x - r, y - r, x + r, y + r), fill=c)


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    canvas = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    draw_trophy(canvas, (700, 520))
    add_confetti(draw)

    paste_centered(canvas, load_sprite("sprint_race.png", (300, 300)), (405, 296))
    paste_centered(canvas, load_sprite("blob_growth.png", (318, 318)), (1012, 292))
    paste_centered(canvas, load_sprite("sumo_push.png", (330, 330)), (330, 720))
    paste_centered(canvas, load_sprite("bomb_throw.png", (312, 312)), (1058, 702))

    canvas.save(OUT, "PNG")
    print(f"Saved {OUT}")


if __name__ == "__main__":
    main()
