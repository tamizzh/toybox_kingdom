from __future__ import annotations

from math import cos, pi, sin
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SPRITES_DIR = ROOT / "assets" / "sprites"
THUMBS_DIR = ROOT / "assets" / "thumbs"

SIZE = 256
OUTLINE = (0, 0, 0, 255)
WHITE = (255, 255, 255, 255)
SHADOW = (0, 0, 0, 55)
RED = (244, 65, 65, 255)
ORANGE = (244, 146, 41, 255)
YELLOW = (247, 211, 69, 255)
GREEN = (72, 194, 104, 255)
BLUE = (67, 145, 245, 255)
PURPLE = (143, 87, 232, 255)
PINK = (243, 99, 177, 255)
TEAL = (53, 191, 191, 255)
BROWN = (143, 92, 57, 255)
GRAY = (120, 129, 145, 255)
DARK = (40, 40, 46, 255)
LAVA = (255, 109, 32, 255)


def new_canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG")


def ellipse(draw: ImageDraw.ImageDraw, box, fill, outline=OUTLINE, width=10) -> None:
    shadow_box = (box[0] + 6, box[1] + 8, box[2] + 6, box[3] + 8)
    draw.ellipse(shadow_box, fill=SHADOW)
    draw.ellipse(box, fill=fill, outline=outline, width=width)


def rounded(draw: ImageDraw.ImageDraw, box, radius, fill, outline=OUTLINE, width=10) -> None:
    shadow_box = (box[0] + 6, box[1] + 8, box[2] + 6, box[3] + 8)
    draw.rounded_rectangle(shadow_box, radius=radius, fill=SHADOW)
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def polygon(draw: ImageDraw.ImageDraw, points, fill, outline=OUTLINE, width=10) -> None:
    shadow = [(x + 6, y + 8) for x, y in points]
    draw.polygon(shadow, fill=SHADOW)
    draw.polygon(points, fill=fill, outline=outline, width=width)


def line(draw: ImageDraw.ImageDraw, pts, fill, width=10) -> None:
    draw.line(pts, fill=fill, width=width, joint="curve")


def arc(draw: ImageDraw.ImageDraw, box, start, end, fill, width=10) -> None:
    draw.arc(box, start=start, end=end, fill=fill, width=width)


def outlined_line(draw: ImageDraw.ImageDraw, pts, fill, inner_width=10, outer_width=18) -> None:
    line(draw, pts, OUTLINE, outer_width)
    line(draw, pts, fill, inner_width)


def outlined_arc(draw: ImageDraw.ImageDraw, box, start, end, fill, inner_width=8, outer_width=14) -> None:
    arc(draw, box, start, end, OUTLINE, outer_width)
    arc(draw, box, start, end, fill, inner_width)


def make_blob_body() -> Image.Image:
    image, draw = new_canvas()
    points = [(64, 178), (58, 126), (82, 78), (138, 62), (188, 86), (198, 150), (176, 204), (112, 212)]
    polygon(draw, points, WHITE)
    return image


def make_runner_body() -> Image.Image:
    image, draw = new_canvas()
    ellipse(draw, (96, 28, 160, 92), WHITE, width=12)
    rounded(draw, (86, 86, 170, 162), 26, WHITE, width=12)
    outlined_line(draw, [(102, 112), (70, 150)], WHITE, 10, 18)
    outlined_line(draw, [(154, 110), (186, 142)], WHITE, 10, 18)
    outlined_line(draw, [(110, 158), (78, 224)], WHITE, 10, 18)
    outlined_line(draw, [(148, 156), (186, 202), (170, 224)], WHITE, 10, 18)
    ellipse(draw, (56, 218, 92, 238), WHITE, width=10)
    ellipse(draw, (152, 218, 190, 238), WHITE, width=10)
    return image


def make_tank_body() -> Image.Image:
    image, draw = new_canvas()
    rounded(draw, (52, 98, 204, 186), 34, WHITE, width=12)
    rounded(draw, (82, 62, 164, 122), 24, WHITE, width=12)
    rounded(draw, (146, 94, 210, 118), 12, WHITE, width=12)
    rounded(draw, (58, 174, 198, 214), 20, WHITE, width=12)
    for x in (82, 110, 138, 166):
        ellipse(draw, (x, 180, x + 16, 196), WHITE, width=8)
    return image


def make_bomb_body() -> Image.Image:
    image, draw = new_canvas()
    ellipse(draw, (62, 72, 194, 204), WHITE, width=12)
    rounded(draw, (112, 48, 144, 78), 10, WHITE, width=10)
    outlined_line(draw, [(144, 60), (162, 34)], WHITE, 6, 14)
    ellipse(draw, (76, 186, 108, 208), WHITE, width=8)
    ellipse(draw, (148, 186, 180, 208), WHITE, width=8)
    return image


def make_snake_body() -> Image.Image:
    image, draw = new_canvas()
    outlined_line(draw, [(88, 196), (76, 150), (98, 108), (146, 98), (180, 118), (182, 166), (152, 196)], WHITE, 22, 34)
    ellipse(draw, (142, 88, 202, 142), WHITE, width=12)
    outlined_line(draw, [(86, 196), (64, 216)], WHITE, 8, 16)
    return image


def make_virus_body() -> Image.Image:
    image, draw = new_canvas()
    center = (128, 136)
    radius = 56
    points = []
    for i in range(16):
        ang = pi * 2 * i / 16
        r = radius + (18 if i % 2 == 0 else 4)
        points.append((center[0] + cos(ang) * r, center[1] + sin(ang) * r))
    polygon(draw, points, WHITE)
    ellipse(draw, (94, 102, 162, 170), WHITE, width=10)
    return image


def make_soccer_body() -> Image.Image:
    image, draw = new_canvas()
    ellipse(draw, (98, 28, 158, 88), WHITE, width=12)
    rounded(draw, (82, 82, 174, 166), 28, WHITE, width=12)
    outlined_line(draw, [(94, 106), (64, 132)], WHITE, 8, 16)
    outlined_line(draw, [(162, 104), (190, 132)], WHITE, 8, 16)
    outlined_line(draw, [(108, 162), (90, 220)], WHITE, 10, 18)
    outlined_line(draw, [(144, 162), (164, 220)], WHITE, 10, 18)
    ellipse(draw, (78, 218, 108, 238), WHITE, width=8)
    ellipse(draw, (150, 218, 180, 238), WHITE, width=8)
    return image


def make_sumo_body() -> Image.Image:
    image, draw = new_canvas()
    ellipse(draw, (48, 74, 208, 214), WHITE, width=12)
    ellipse(draw, (86, 34, 170, 106), WHITE, width=12)
    outlined_line(draw, [(70, 132), (40, 154)], WHITE, 10, 18)
    outlined_line(draw, [(186, 132), (216, 154)], WHITE, 10, 18)
    outlined_line(draw, [(94, 198), (82, 228)], WHITE, 8, 16)
    outlined_line(draw, [(162, 198), (174, 228)], WHITE, 8, 16)
    return image


def make_frog_body() -> Image.Image:
    image, draw = new_canvas()
    ellipse(draw, (56, 92, 200, 196), WHITE, width=12)
    ellipse(draw, (74, 52, 118, 94), WHITE, width=10)
    ellipse(draw, (138, 52, 182, 94), WHITE, width=10)
    outlined_line(draw, [(92, 174), (62, 208)], WHITE, 10, 18)
    outlined_line(draw, [(164, 174), (194, 208)], WHITE, 10, 18)
    outlined_line(draw, [(92, 140), (56, 156)], WHITE, 8, 14)
    outlined_line(draw, [(164, 140), (200, 156)], WHITE, 8, 14)
    return image


def make_chick_body() -> Image.Image:
    image, draw = new_canvas()
    ellipse(draw, (54, 56, 202, 204), WHITE, width=12)
    polygon(draw, [(92, 62), (108, 30), (128, 58), (148, 30), (164, 62)], WHITE, width=12)
    outlined_line(draw, [(94, 138), (62, 154)], WHITE, 8, 14)
    outlined_line(draw, [(162, 138), (194, 154)], WHITE, 8, 14)
    outlined_line(draw, [(106, 192), (96, 226)], WHITE, 8, 14)
    outlined_line(draw, [(150, 192), (160, 226)], WHITE, 8, 14)
    return image


def build_sprites() -> None:
    sprite_builders = {
        "sprint_race.png": make_runner_body,
        "tank_battle.png": make_tank_body,
        "bomb_throw.png": make_bomb_body,
        "snake_battle.png": make_snake_body,
        "blob_growth.png": make_blob_body,
        "virus_spread.png": make_virus_body,
        "mini_soccer.png": make_soccer_body,
        "sumo_push.png": make_sumo_body,
        "lava_rising.png": make_frog_body,
        "reaction_tap.png": make_chick_body,
    }
    for name, builder in sprite_builders.items():
        save(builder(), SPRITES_DIR / name)


def draw_speed_lines(draw, x1, y1, x2, y2, count=3):
    for i in range(count):
        line(draw, [(x1, y1 + i * 18), (x2, y2 + i * 18)], OUTLINE, 8)


def draw_runner_thumb(draw):
    ellipse(draw, (100, 46, 158, 104), YELLOW, width=8)
    rounded(draw, (90, 100, 168, 166), 24, ORANGE, width=8)
    outlined_line(draw, [(102, 120), (70, 144)], ORANGE, 6, 12)
    outlined_line(draw, [(156, 118), (188, 142)], ORANGE, 6, 12)
    outlined_line(draw, [(108, 164), (76, 214)], ORANGE, 6, 12)
    outlined_line(draw, [(150, 164), (188, 194), (174, 220)], ORANGE, 6, 12)
    draw_speed_lines(draw, 28, 114, 82, 114)


def draw_lane_switch(draw):
    rounded(draw, (54, 108, 202, 186), 28, BLUE, width=8)
    polygon(draw, [(118, 96), (174, 96), (198, 132), (184, 176), (106, 176), (84, 132)], RED, width=8)
    line(draw, [(40, 76), (74, 76)], OUTLINE, 8)
    line(draw, [(52, 128), (80, 128)], OUTLINE, 8)
    line(draw, [(40, 182), (74, 182)], OUTLINE, 8)


def draw_obstacle_dash(draw):
    rounded(draw, (92, 70, 160, 136), 22, GREEN, width=8)
    line(draw, [(104, 134), (70, 196)], OUTLINE, 10)
    line(draw, [(150, 134), (188, 172)], OUTLINE, 10)
    rounded(draw, (74, 176, 184, 212), 12, YELLOW, width=8)
    for x in range(82, 176, 24):
        line(draw, [(x, 178), (x + 18, 210)], OUTLINE, 6)


def draw_ice_slide(draw):
    ellipse(draw, (92, 48, 164, 118), DARK, width=8)
    rounded(draw, (88, 114, 168, 186), 24, WHITE, width=8)
    outlined_arc(draw, (48, 144, 196, 240), 200, 340, BLUE, 8, 14)


def draw_hill_climb(draw):
    polygon(draw, [(46, 194), (106, 136), (206, 136), (206, 214), (46, 214)], GREEN, width=8)
    rounded(draw, (96, 104, 178, 156), 18, RED, width=8)
    ellipse(draw, (104, 146, 134, 176), DARK, width=8)
    ellipse(draw, (152, 146, 182, 176), DARK, width=8)


def draw_tank_thumb(draw):
    rounded(draw, (58, 108, 198, 188), 30, GREEN, width=8)
    rounded(draw, (90, 78, 160, 126), 20, TEAL, width=8)
    rounded(draw, (148, 98, 214, 120), 10, GRAY, width=8)
    rounded(draw, (68, 180, 186, 212), 18, DARK, width=8)


def draw_sword_duel(draw):
    polygon(draw, [(88, 48), (110, 70), (76, 160), (56, 142)], BLUE, width=8)
    rounded(draw, (44, 140, 90, 160), 8, YELLOW, width=8)
    polygon(draw, [(168, 48), (146, 70), (180, 160), (200, 142)], RED, width=8)
    rounded(draw, (166, 140, 212, 160), 8, YELLOW, width=8)


def draw_bomb_thumb(draw):
    ellipse(draw, (72, 76, 184, 188), DARK, width=8)
    outlined_line(draw, [(152, 76), (174, 50)], DARK, 4, 10)
    polygon(draw, [(182, 42), (194, 58), (174, 58)], ORANGE, width=6)
    ellipse(draw, (104, 114, 122, 132), WHITE, width=6)
    ellipse(draw, (136, 114, 154, 132), WHITE, width=6)
    arc(draw, (102, 128, 154, 156), 15, 165, WHITE, 6)


def draw_laser_survival(draw):
    rounded(draw, (104, 88, 156, 140), 18, BLUE, width=8)
    outlined_line(draw, [(84, 140), (62, 204)], BLUE, 6, 12)
    outlined_line(draw, [(148, 140), (188, 184)], BLUE, 6, 12)
    line(draw, [(40, 62), (210, 202)], RED, 10)
    line(draw, [(214, 58), (44, 206)], RED, 10)


def draw_mini_shooter(draw):
    rounded(draw, (70, 112, 166, 166), 18, PURPLE, width=8)
    rounded(draw, (150, 124, 210, 146), 8, GRAY, width=8)
    ellipse(draw, (200, 126, 226, 152), ORANGE, width=6)
    draw_speed_lines(draw, 34, 128, 64, 128, 2)


def draw_snake_thumb(draw):
    outlined_line(draw, [(82, 186), (80, 132), (110, 102), (158, 102), (176, 138), (164, 182)], GREEN, 20, 34)
    ellipse(draw, (142, 90, 194, 142), GREEN, width=8)


def draw_blob_thumb(draw):
    polygon(draw, [(74, 188), (66, 130), (92, 86), (156, 82), (194, 122), (182, 190)], GREEN, width=8)
    ellipse(draw, (104, 120, 122, 138), DARK, width=6)
    ellipse(draw, (138, 120, 156, 138), DARK, width=6)
    arc(draw, (104, 136, 156, 164), 15, 165, DARK, 6)


def draw_zone_shrink(draw):
    ellipse(draw, (70, 70, 186, 186), BLUE, width=8)
    ellipse(draw, (98, 98, 158, 158), GREEN, width=8)
    rounded(draw, (112, 112, 144, 150), 12, YELLOW, width=6)


def draw_king_of_arena(draw):
    rounded(draw, (88, 160, 168, 206), 12, GRAY, width=8)
    polygon(draw, [(82, 144), (100, 88), (128, 122), (156, 88), (174, 144)], YELLOW, width=8)


def draw_virus_thumb(draw):
    center = (128, 132)
    points = []
    for i in range(14):
        ang = pi * 2 * i / 14
        r = 50 + (14 if i % 2 == 0 else 0)
        points.append((center[0] + cos(ang) * r, center[1] + sin(ang) * r))
    polygon(draw, points, PINK, width=8)
    ellipse(draw, (108, 118, 122, 132), DARK, width=6)
    ellipse(draw, (134, 118, 148, 132), DARK, width=6)
    arc(draw, (106, 132, 150, 156), 15, 165, DARK, 6)


def draw_mini_soccer(draw):
    rounded(draw, (148, 92, 214, 176), 8, WHITE, width=8)
    line(draw, [(156, 104), (206, 104), (206, 170)], OUTLINE, 6)
    line(draw, [(156, 126), (206, 126)], OUTLINE, 4)
    line(draw, [(180, 104), (180, 170)], OUTLINE, 4)
    ellipse(draw, (52, 126, 116, 190), WHITE, width=8)
    line(draw, [(84, 126), (84, 190)], OUTLINE, 4)
    line(draw, [(52, 158), (116, 158)], OUTLINE, 4)
    line(draw, [(116, 154), (146, 140)], OUTLINE, 8)


def draw_sumo_push(draw):
    ellipse(draw, (46, 92, 128, 174), ORANGE, width=8)
    ellipse(draw, (128, 92, 210, 174), BLUE, width=8)
    line(draw, [(96, 132), (160, 132)], OUTLINE, 10)


def draw_basketball_rush(draw):
    ellipse(draw, (74, 72, 146, 144), ORANGE, width=8)
    arc(draw, (82, 80, 138, 136), 90, 270, OUTLINE, 4)
    arc(draw, (82, 80, 138, 136), -90, 90, OUTLINE, 4)
    outlined_arc(draw, (120, 126, 210, 188), 180, 360, RED, 6, 12)
    line(draw, [(126, 126), (204, 126)], OUTLINE, 6)


def draw_tug_of_war(draw):
    outlined_line(draw, [(56, 128), (198, 128)], BROWN, 8, 16)
    outlined_line(draw, [(56, 100), (78, 128), (56, 156)], ORANGE, 6, 12)
    outlined_line(draw, [(198, 100), (176, 128), (198, 156)], BLUE, 6, 12)


def draw_hockey_slide(draw):
    outlined_line(draw, [(84, 86), (132, 152)], BROWN, 8, 14)
    rounded(draw, (126, 146, 186, 174), 8, GRAY, width=8)
    ellipse(draw, (156, 176, 194, 214), DARK, width=8)


def draw_reaction_tap(draw):
    rounded(draw, (66, 132, 186, 198), 22, BLUE, width=8)
    ellipse(draw, (104, 146, 150, 178), YELLOW, width=6)
    rounded(draw, (148, 82, 182, 154), 16, WHITE, width=8)
    rounded(draw, (126, 136, 168, 168), 12, WHITE, width=8)
    polygon(draw, [(172, 58), (184, 86), (214, 92), (190, 110), (196, 140), (170, 128), (150, 146), (152, 118), (126, 104), (154, 96)], WHITE, width=8)


def draw_stop_timer(draw):
    ellipse(draw, (72, 74, 184, 186), RED, width=8)
    rounded(draw, (112, 42, 146, 74), 8, GRAY, width=8)
    line(draw, [(128, 130), (128, 92)], WHITE, 8)
    line(draw, [(128, 130), (154, 142)], WHITE, 8)


def draw_color_match(draw):
    rounded(draw, (62, 62, 118, 118), 12, RED, width=8)
    rounded(draw, (138, 62, 194, 118), 12, BLUE, width=8)
    rounded(draw, (62, 138, 118, 194), 12, GREEN, width=8)
    rounded(draw, (138, 138, 194, 194), 12, YELLOW, width=8)


def draw_light_signal(draw):
    rounded(draw, (96, 48, 160, 208), 22, DARK, width=8)
    ellipse(draw, (108, 64, 148, 104), RED, width=6)
    ellipse(draw, (108, 108, 148, 148), YELLOW, width=6)
    ellipse(draw, (108, 152, 148, 192), GREEN, width=6)


def draw_memory_sequence(draw):
    for color, box in [
        (RED, (96, 42, 144, 90)),
        (BLUE, (166, 112, 214, 160)),
        (GREEN, (96, 182, 144, 230)),
        (YELLOW, (26, 112, 74, 160)),
    ]:
        rounded(draw, box, 16, color, width=8)
    ellipse(draw, (104, 108, 152, 156), WHITE, width=6)


def draw_falling_platforms(draw):
    rounded(draw, (48, 144, 102, 194), 10, GRAY, width=8)
    rounded(draw, (104, 154, 158, 204), 10, GRAY, width=8)
    rounded(draw, (160, 144, 214, 194), 10, GRAY, width=8)
    line(draw, [(116, 164), (146, 194)], OUTLINE, 6)
    rounded(draw, (104, 62, 152, 112), 14, ORANGE, width=8)


def draw_lava_rising(draw):
    rounded(draw, (102, 74, 154, 126), 16, GREEN, width=8)
    polygon(draw, [(36, 186), (220, 186), (198, 214), (58, 214)], LAVA, width=8)
    line(draw, [(72, 176), (72, 150)], OUTLINE, 8)
    line(draw, [(184, 176), (184, 148)], OUTLINE, 8)


def draw_jump_gap(draw):
    rounded(draw, (38, 164, 98, 206), 10, GRAY, width=8)
    rounded(draw, (158, 164, 218, 206), 10, GRAY, width=8)
    rounded(draw, (102, 88, 154, 138), 14, YELLOW, width=8)
    outlined_arc(draw, (64, 74, 196, 180), 210, 320, BLUE, 6, 12)


def draw_moving_block(draw):
    rounded(draw, (62, 120, 124, 182), 10, GRAY, width=8)
    rounded(draw, (152, 86, 202, 136), 12, GREEN, width=8)
    outlined_line(draw, [(40, 152), (22, 152)], RED, 4, 10)
    outlined_line(draw, [(214, 152), (232, 152)], RED, 4, 10)


def draw_rotating_platform(draw):
    ellipse(draw, (66, 82, 190, 206), PURPLE, width=8)
    rounded(draw, (110, 110, 146, 152), 12, YELLOW, width=8)
    arc(draw, (42, 58, 214, 230), 220, 320, BLUE, 8)
    polygon(draw, [(54, 140), (68, 128), (70, 148)], BLUE, width=6)
    polygon(draw, [(196, 126), (184, 140), (204, 144)], BLUE, width=6)


THUMB_BUILDERS = {
    "sprint_race.png": draw_runner_thumb,
    "lane_switch.png": draw_lane_switch,
    "obstacle_dash.png": draw_obstacle_dash,
    "ice_slide.png": draw_ice_slide,
    "hill_climb.png": draw_hill_climb,
    "tank_battle.png": draw_tank_thumb,
    "sword_duel.png": draw_sword_duel,
    "bomb_throw.png": draw_bomb_thumb,
    "laser_survival.png": draw_laser_survival,
    "mini_shooter.png": draw_mini_shooter,
    "snake_battle.png": draw_snake_thumb,
    "blob_growth.png": draw_blob_thumb,
    "zone_shrink.png": draw_zone_shrink,
    "king_of_arena.png": draw_king_of_arena,
    "virus_spread.png": draw_virus_thumb,
    "mini_soccer.png": draw_mini_soccer,
    "sumo_push.png": draw_sumo_push,
    "basketball_rush.png": draw_basketball_rush,
    "tug_of_war.png": draw_tug_of_war,
    "hockey_slide.png": draw_hockey_slide,
    "reaction_tap.png": draw_reaction_tap,
    "stop_timer.png": draw_stop_timer,
    "color_match.png": draw_color_match,
    "light_signal.png": draw_light_signal,
    "memory_sequence.png": draw_memory_sequence,
    "falling_platforms.png": draw_falling_platforms,
    "lava_rising.png": draw_lava_rising,
    "jump_gap.png": draw_jump_gap,
    "moving_block.png": draw_moving_block,
    "rotating_platform.png": draw_rotating_platform,
}


def build_thumbs() -> None:
    for name, painter in THUMB_BUILDERS.items():
        image, draw = new_canvas()
        painter(draw)
        save(image, THUMBS_DIR / name)


def main() -> None:
    build_sprites()
    build_thumbs()
    print(f"Generated {len(list(SPRITES_DIR.glob('*.png')))} sprites and {len(list(THUMBS_DIR.glob('*.png')))} thumbs.")


if __name__ == "__main__":
    main()
