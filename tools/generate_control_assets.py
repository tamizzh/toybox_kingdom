from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
CONTROLS_DIR = ROOT / "assets" / "controls"

SIZE = 256
OUTLINE = (0, 0, 0, 255)
WHITE = (255, 255, 255, 255)
SOFT_WHITE = (255, 255, 255, 170)
SHADOW = (0, 0, 0, 58)
BLUE = (67, 145, 245, 255)
TEAL = (53, 191, 191, 255)
YELLOW = (247, 211, 69, 255)
GREEN = (72, 194, 104, 255)
RED = (244, 65, 65, 255)
GRAY = (120, 129, 145, 255)
DARK = (40, 40, 46, 255)


def new_canvas(size: tuple[int, int] = (SIZE, SIZE)) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG")


def shadow_box(box: tuple[int, int, int, int], dx: int = 6, dy: int = 8) -> tuple[int, int, int, int]:
    return (box[0] + dx, box[1] + dy, box[2] + dx, box[3] + dy)


def ellipse(draw: ImageDraw.ImageDraw, box, fill, outline=OUTLINE, width=10, shadow=True) -> None:
    if shadow:
        draw.ellipse(shadow_box(box), fill=SHADOW)
    draw.ellipse(box, fill=fill, outline=outline, width=width)


def rounded(draw: ImageDraw.ImageDraw, box, radius, fill, outline=OUTLINE, width=10, shadow=True) -> None:
    if shadow:
        draw.rounded_rectangle(shadow_box(box), radius=radius, fill=SHADOW)
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def polygon(draw: ImageDraw.ImageDraw, points, fill, outline=OUTLINE, width=10, shadow=True) -> None:
    if shadow:
        draw.polygon([(x + 6, y + 8) for x, y in points], fill=SHADOW)
    draw.polygon(points, fill=fill, outline=outline, width=width)


def line(draw: ImageDraw.ImageDraw, points, fill, width=10) -> None:
    draw.line(points, fill=fill, width=width, joint="curve")


def outlined_line(draw: ImageDraw.ImageDraw, points, fill, inner_width=10, outer_width=18) -> None:
    line(draw, points, OUTLINE, outer_width)
    line(draw, points, fill, inner_width)


def arrow(points: list[tuple[int, int]], direction: str) -> list[tuple[int, int]]:
    if direction == "right":
        return points
    if direction == "left":
        return [(256 - x, y) for x, y in points]
    if direction == "up":
        return [(y, 256 - x) for x, y in points]
    if direction == "down":
        return [(y, x) for x, y in points]
    raise ValueError(direction)


def draw_finger(draw: ImageDraw.ImageDraw, center_x: int, center_y: int, scale: float = 1.0) -> None:
    finger = [
        (0, -64),
        (22, -64),
        (22, -10),
        (36, -10),
        (36, 42),
        (14, 42),
        (14, 14),
        (-8, 14),
        (-8, 50),
        (-32, 50),
        (-32, -4),
        (-18, -22),
        (-2, -22),
        (-2, -64),
    ]
    pts = [(center_x + int(x * scale), center_y + int(y * scale)) for x, y in finger]
    polygon(draw, pts, WHITE, width=8)


def make_tap_anywhere() -> Image.Image:
    image, draw = new_canvas()
    rounded(draw, (38, 128, 214, 214), 28, BLUE, width=8)
    ellipse(draw, (88, 142, 144, 184), YELLOW, width=6)
    for box in ((74, 128, 158, 198), (58, 112, 174, 214)):
        draw.arc(box, 208, 344, fill=WHITE, width=8)
    draw_finger(draw, 170, 116, 0.95)
    return image


def make_tap_button() -> Image.Image:
    image, draw = new_canvas()
    ellipse(draw, (52, 52, 204, 204), SOFT_WHITE, width=10)
    ellipse(draw, (88, 88, 168, 168), YELLOW, width=8)
    draw.arc((70, 70, 186, 186), 16, 164, fill=WHITE, width=8)
    draw.arc((70, 70, 186, 186), 196, 344, fill=WHITE, width=8)
    return image


def make_joystick_base() -> Image.Image:
    image, draw = new_canvas()
    ellipse(draw, (24, 24, 232, 232), (255, 255, 255, 30), width=12)
    ellipse(draw, (54, 54, 202, 202), (255, 255, 255, 12), outline=WHITE, width=6, shadow=False)
    draw.arc((42, 42, 214, 214), 212, 332, fill=BLUE, width=10)
    draw.arc((42, 42, 214, 214), 32, 152, fill=TEAL, width=10)
    ellipse(draw, (102, 102, 154, 154), WHITE, width=8, shadow=False)
    return image


def make_joystick_knob() -> Image.Image:
    image, draw = new_canvas()
    ellipse(draw, (54, 54, 202, 202), WHITE, width=10)
    ellipse(draw, (84, 84, 130, 130), SOFT_WHITE, outline=SOFT_WHITE, width=0, shadow=False)
    ellipse(draw, (128, 122, 174, 168), BLUE, outline=WHITE, width=6, shadow=False)
    return image


def make_swipe_horizontal() -> Image.Image:
    image, draw = new_canvas()
    rounded(draw, (28, 94, 228, 162), 28, SOFT_WHITE, width=8)
    outlined_line(draw, [(70, 128), (186, 128)], BLUE, 12, 22)
    polygon(draw, arrow([(188, 128), (156, 106), (156, 150)], "right"), BLUE, width=8)
    polygon(draw, arrow([(68, 128), (100, 106), (100, 150)], "left"), BLUE, width=8)
    return image


def make_swipe_vertical() -> Image.Image:
    image, draw = new_canvas()
    rounded(draw, (94, 28, 162, 228), 28, SOFT_WHITE, width=8)
    outlined_line(draw, [(128, 70), (128, 186)], TEAL, 12, 22)
    polygon(draw, arrow([(128, 68), (106, 100), (150, 100)], "up"), TEAL, width=8)
    polygon(draw, arrow([(128, 188), (106, 156), (150, 156)], "down"), TEAL, width=8)
    return image


def make_drag_anywhere() -> Image.Image:
    image, draw = new_canvas()
    draw_finger(draw, 110, 148, 0.92)
    outlined_line(draw, [(136, 126), (172, 102), (208, 84)], BLUE, 8, 16)
    polygon(draw, [(196, 66), (224, 78), (204, 100)], BLUE, width=8)
    for box in ((82, 102, 154, 174), (64, 84, 172, 192)):
        draw.arc(box, 210, 342, fill=WHITE, width=8)
    return image


def make_hold_button() -> Image.Image:
    image, draw = new_canvas()
    ellipse(draw, (44, 44, 212, 212), SOFT_WHITE, width=10)
    ellipse(draw, (78, 78, 178, 178), GREEN, width=8)
    ellipse(draw, (102, 102, 154, 154), WHITE, width=6, shadow=False)
    draw.arc((58, 58, 198, 198), 240, 30, fill=WHITE, width=8)
    rounded(draw, (112, 22, 144, 62), 10, DARK, width=6)
    return image


def make_left_right_pad() -> Image.Image:
    image, draw = new_canvas()
    rounded(draw, (26, 86, 230, 170), 30, DARK, width=8)
    rounded(draw, (38, 98, 122, 158), 22, RED, width=6)
    rounded(draw, (134, 98, 218, 158), 22, BLUE, width=6)
    polygon(draw, [(72, 128), (98, 108), (98, 148)], WHITE, width=6)
    polygon(draw, [(184, 128), (158, 108), (158, 148)], WHITE, width=6)
    return image


def make_controls_preview() -> Image.Image:
    tiles = [
        make_tap_anywhere(),
        make_tap_button(),
        make_joystick_base(),
        make_joystick_knob(),
        make_swipe_horizontal(),
        make_swipe_vertical(),
        make_drag_anywhere(),
        make_hold_button(),
        make_left_right_pad(),
    ]
    image, draw = new_canvas((SIZE * 3, SIZE * 3))
    draw.rounded_rectangle((10, 10, image.width - 10, image.height - 10), radius=34, fill=(255, 255, 255, 16))
    for index, tile in enumerate(tiles):
        x = (index % 3) * SIZE
        y = (index // 3) * SIZE
        image.alpha_composite(tile, (x, y))
    return image


BUILDERS = {
    "tap_anywhere.png": make_tap_anywhere,
    "tap_button.png": make_tap_button,
    "joystick_base.png": make_joystick_base,
    "joystick_knob.png": make_joystick_knob,
    "swipe_horizontal.png": make_swipe_horizontal,
    "swipe_vertical.png": make_swipe_vertical,
    "drag_anywhere.png": make_drag_anywhere,
    "hold_button.png": make_hold_button,
    "left_right_pad.png": make_left_right_pad,
    "controls_preview.png": make_controls_preview,
}


def main() -> None:
    for name, builder in BUILDERS.items():
        save(builder(), CONTROLS_DIR / name)
    print(f"Generated {len(BUILDERS)} control assets in {CONTROLS_DIR}")


if __name__ == "__main__":
    main()
