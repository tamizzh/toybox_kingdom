"""
_render_sprite.py
=================
Renders the SHADED 3D tank (the Blender look: white hull, dark tracks, grey
wheels, real lighting) into the game's tank sprite on a TRANSPARENT background.

The tank avatar uses "color-as-line" mode (theme/flat_figure.gd) so the body is
drawn untinted -> the shaded 3D look is preserved and the player colour shows as
a bar beneath the tank.

Output: assets/sprites/tank_battle.png   (square, transparent)
"""
import bpy, os, importlib.util, math

HERE = r"c:\Users\rpandian\Documents\party-games"
OUT = os.path.join(HERE, "assets", "sprites", "tank_battle.png")
RES = 512

# --- build the tank with its real materials (skip the model's own camera) ---
spec = importlib.util.spec_from_file_location("tm", os.path.join(HERE, "tank_model.py"))
tm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tm)
tm.clear_scene()
tm.build_tank()

scene = bpy.context.scene

# --- 3-point lighting (so it reads as the shaded Blender render) ------------
def area(loc, energy, size):
    bpy.ops.object.light_add(type="AREA", location=loc)
    L = bpy.context.active_object
    L.data.energy = energy
    L.data.size = size
    return L
area((6, -6, 9), 1100, 10)
area((-8, -2, 5), 350, 12)
area((-3, 8, 6), 500, 8)

# --- camera: HIGH top-down (gun points +X = right) so the sprite can be
#     rotated to face the joystick, while keeping some 3D shading -----------
bpy.ops.object.empty_add(location=(0.5, 0, 0.7))
target = bpy.context.active_object
bpy.ops.object.camera_add(location=(0.5, -4.5, 11.0))
cam = bpy.context.active_object
cam.data.type = "ORTHO"
cam.data.ortho_scale = 6.6   # a little padding so the gun has room when rotated
con = cam.constraints.new("TRACK_TO")
con.target = target
con.track_axis = "TRACK_NEGATIVE_Z"
con.up_axis = "UP_Y"
scene.camera = cam

for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
    try:
        scene.render.engine = eng
        break
    except TypeError:
        continue
scene.render.use_freestyle = False
scene.render.film_transparent = True            # transparent background for the sprite
scene.view_settings.view_transform = "Standard"
scene.render.resolution_x = RES
scene.render.resolution_y = RES
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("SPRITE:", OUT)
