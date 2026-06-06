"""Render driver: build the 3D tank and render it from several angles."""
import bpy, os, importlib.util, math

here = r"c:\Users\rpandian\Documents\party-games"
spec = importlib.util.spec_from_file_location("tm", os.path.join(here, "tank_model.py"))
tm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tm)
tm.main()

scene = bpy.context.scene
for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
    try:
        scene.render.engine = eng
        break
    except TypeError:
        continue
scene.render.use_freestyle = False
scene.view_settings.view_transform = "Standard"
scene.render.resolution_x = 480
scene.render.resolution_y = 380

cam = scene.camera
R = 13  # camera distance

# (name, azimuth_deg, elevation_deg)  azimuth 0 = front (+X), 90 = left side
views = [
    ("34",    35, 28),   # hero 3/4
    ("side",  90, 8),    # straight side
    ("front", 2,  12),   # front
    ("top",   45, 75),   # top-down-ish
]

for name, az, el in views:
    a, e = math.radians(az), math.radians(el)
    cam.location = (R * math.cos(e) * math.cos(a),
                    -R * math.cos(e) * math.sin(a) if False else R * math.cos(e) * math.sin(-a),
                    R * math.sin(e) + 1.0)
    # simpler explicit placement around the target at (0.2,0,1.0)
    cx = 0.2 + R * math.cos(e) * math.cos(a)
    cy = 0.0 - R * math.cos(e) * math.sin(a)
    cz = 1.0 + R * math.sin(e)
    cam.location = (cx, cy, cz)
    scene.render.filepath = os.path.join(here, f"tank_{name}.png")
    bpy.ops.render.render(write_still=True)
    print("RENDERED:", scene.render.filepath)
