"""
tank_model.py
=============
Builds a proper 3D cartoon tank in Blender, inspired by the white-line tank
icon (chunky rounded hull, turret cupola + hatch, two continuous tracks with
road wheels inside them, and a stubby angled gun). Unlike a flat icon, this is
a real 3D model that reads correctly from ANY angle.

Orientation:
    X = length (the gun points +X / "forward")
    Y = width  (left / right)
    Z = up     (ground at Z = 0)

Run it either way:
  1. Inside Blender:  Scripting tab -> Open -> tank_model.py -> Run Script
  2. Headless:        blender --background --python tank_model.py
"""

import bpy
import bmesh
import math

# --------------------------------------------------------------------------- #
# CONFIG
# --------------------------------------------------------------------------- #
CONFIG = {
    "clear_scene": True,
    "shade_smooth": True,
    "save_blend": True,        # only when run headless
    "export_glb": True,        # only when run headless
}

# Palette (white-ish body like the icon, dark tracks for contrast)
COL_BODY  = (0.90, 0.90, 0.90)
COL_TURRET = (0.86, 0.86, 0.86)
COL_TRACK = (0.13, 0.13, 0.14)
COL_WHEEL = (0.32, 0.32, 0.34)
COL_GUN   = (0.80, 0.80, 0.80)


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #
def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.curves,
                  bpy.data.cameras, bpy.data.lights):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def make_material(name, color, roughness=0.5, metallic=0.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    mat.diffuse_color = (*color, 1.0)
    return mat


def assign(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def shade_smooth(obj, angle_deg=40):
    if not CONFIG["shade_smooth"]:
        return
    for poly in obj.data.polygons:
        poly.use_smooth = True
    mod = obj.modifiers.new("Smooth", "EDGE_SPLIT")
    mod.split_angle = math.radians(angle_deg)


def rounded_box(name, size, location, bevel=0.15, segments=4):
    """Bevelled cube -> chunky cartoon volume."""
    # base cube is 2x2x2 (verts +/-1), so scaling by size/2 yields exactly `size`
    bpy.ops.mesh.primitive_cube_add(size=2, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=bevel,
                    segments=segments, affect="EDGES", profile=0.7)
    bm.to_mesh(me)
    bm.free()
    return obj


def cylinder(name, radius, depth, location, rotation=(0, 0, 0), verts=40):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth,
                                        location=location, rotation=rotation,
                                        vertices=verts)
    obj = bpy.context.active_object
    obj.name = name
    return obj


def track_loop(name, length, height, width, location, verts=32):
    """A continuous caterpillar-track loop: a 'stadium' (rectangle with
    semicircular ends) profile in the X-Z plane, given thickness along Y."""
    # build the rounded outline in X-Z, then solidify along Y
    bpy.ops.mesh.primitive_cylinder_add(radius=height / 2, depth=width,
                                        location=location,
                                        rotation=(math.radians(90), 0, 0),
                                        vertices=verts)
    front = bpy.context.active_object
    front.name = name
    # second rounded end
    back = cylinder(name + "_b", height / 2, width,
                    (location[0], location[1], location[2]),
                    rotation=(math.radians(90), 0, 0), verts=verts)
    span = length - height
    front.location.x += span / 2
    back.location.x -= span / 2
    # connecting middle block
    mid = rounded_box(name + "_m", (span, width, height), location,
                      bevel=0.0, segments=1)
    # join into one track
    bpy.ops.object.select_all(action="DESELECT")
    for o in (front, back, mid):
        o.select_set(True)
    bpy.context.view_layer.objects.active = front
    bpy.ops.object.join()
    track = bpy.context.active_object
    track.name = name
    return track


# --------------------------------------------------------------------------- #
# Build the tank
# --------------------------------------------------------------------------- #
def build_tank():
    m_body = make_material("Body", COL_BODY, roughness=0.45)
    m_turret = make_material("Turret", COL_TURRET, roughness=0.45)
    m_track = make_material("Track", COL_TRACK, roughness=0.8)
    m_wheel = make_material("Wheel", COL_WHEEL, roughness=0.6)
    m_gun = make_material("Gun", COL_GUN, roughness=0.4, metallic=0.2)

    # ---- Key dimensions (overlaps are deliberate so nothing floats) -------
    HULL_W = 3.0          # wide body that overhangs / meets BOTH tracks
    TRACK_W = 0.55
    TRACK_H = 1.10
    TRACK_L = 4.7
    track_y = 1.25        # track centre, tucked under the hull edge
    track_cz = TRACK_H / 2
    outer_face = track_y + TRACK_W / 2

    # --- Tracks (left & right): the dark stadium loops dominate -------------
    for side in (-1, 1):
        t = track_loop(f"Track_{side}", TRACK_L, TRACK_H, TRACK_W,
                       (0, side * track_y, track_cz))
        assign(t, m_track)
        shade_smooth(t, angle_deg=50)

        # road wheels: small discs nearly FLUSH with the outer track face and
        # sitting LOW, so the dark band shows above them and they don't stick
        # out past the tracks (no fat tires)
        for i, x in enumerate((-1.7, -1.02, -0.34, 0.34, 1.02, 1.7)):
            r = 0.30 if abs(x) < 1.4 else 0.27        # smaller idlers at ends
            w = cylinder(f"Wheel_{side}_{i}", r, 0.12,
                         (x, side * (outer_face - 0.02), 0.42),
                         rotation=(math.radians(90), 0, 0))
            assign(w, m_wheel)
            shade_smooth(w, angle_deg=50)

    # --- Hull: WIDE chunky body overhanging both tracks (z 0.55 .. 1.45) ----
    hull = rounded_box("Hull", (4.0, HULL_W, 0.9),
                       (0, 0, 1.0), bevel=0.20, segments=4)
    assign(hull, m_body)
    shade_smooth(hull)

    # --- Turret: rounded cupola seated DEEP in the hull (z 1.15 .. 2.05) ----
    turret = rounded_box("TurretBox", (2.2, 1.7, 0.9),
                         (-0.3, 0, 1.60), bevel=0.24, segments=6)
    assign(turret, m_turret)
    shade_smooth(turret)

    # commander hatch on top of the turret
    hatch = cylinder("Hatch", 0.33, 0.18, (-0.65, 0.0, 2.0),
                     rotation=(0, 0, 0), verts=24)
    assign(hatch, m_turret)
    shade_smooth(hatch, angle_deg=50)

    # --- Gun: mantlet + barrel + muzzle brake -------------------------------
    # slim, heavily-rounded mantlet -> a soft collar at the turret front face
    mantlet = rounded_box("Mantlet", (0.45, 0.66, 0.62), (0.82, 0, 1.60),
                          bevel=0.28, segments=6)
    assign(mantlet, m_turret)
    shade_smooth(mantlet)

    up = math.radians(16)                # gun pointed clearly upward
    blen = 2.6
    bx0 = 0.95                           # barrel root inside the mantlet
    bz0 = 1.60
    cx = bx0 + math.cos(up) * blen / 2
    cz = bz0 + math.sin(up) * blen / 2
    barrel = cylinder("Barrel", 0.15, blen, (cx, 0, cz),
                      rotation=(0, math.radians(90) - up, 0))
    assign(barrel, m_gun)
    shade_smooth(barrel, angle_deg=50)

    tx = bx0 + math.cos(up) * (blen - 0.1)
    tz = bz0 + math.sin(up) * (blen - 0.1)
    muzzle = cylinder("Muzzle", 0.22, 0.32, (tx, 0, tz),
                      rotation=(0, math.radians(90) - up, 0), verts=20)
    assign(muzzle, m_gun)
    shade_smooth(muzzle, angle_deg=50)


# --------------------------------------------------------------------------- #
# Scene: 3/4 perspective camera + 3-point lighting
# --------------------------------------------------------------------------- #
def setup_scene():
    # aim target at the tank's visual center
    bpy.ops.object.empty_add(location=(0.2, 0, 1.0))
    target = bpy.context.active_object
    target.name = "CamTarget"

    bpy.ops.object.camera_add(location=(11, -11, 6.5))
    cam = bpy.context.active_object
    cam.data.lens = 55
    con = cam.constraints.new("TRACK_TO")
    con.target = target
    con.track_axis = "TRACK_NEGATIVE_Z"
    con.up_axis = "UP_Y"
    bpy.context.scene.camera = cam

    bpy.ops.object.light_add(type="AREA", location=(6, -6, 9))
    key = bpy.context.active_object
    key.data.energy = 1100
    key.data.size = 10

    bpy.ops.object.light_add(type="AREA", location=(-8, -2, 5))
    fill = bpy.context.active_object
    fill.data.energy = 350
    fill.data.size = 12

    bpy.ops.object.light_add(type="AREA", location=(-3, 8, 6))
    rim = bpy.context.active_object
    rim.data.energy = 500
    rim.data.size = 8

    world = bpy.context.scene.world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.12, 0.13, 0.15, 1.0)
        bg.inputs["Strength"].default_value = 0.6


# --------------------------------------------------------------------------- #
def main():
    if CONFIG["clear_scene"]:
        clear_scene()
    build_tank()
    setup_scene()

    if bpy.app.background:
        import os
        try:
            here = os.path.dirname(os.path.abspath(__file__))
        except NameError:
            here = os.getcwd()
        if CONFIG["save_blend"]:
            p = os.path.join(here, "tank.blend")
            bpy.ops.wm.save_as_mainfile(filepath=p)
            print(f"Saved {p}")
        if CONFIG["export_glb"]:
            g = os.path.join(here, "tank.glb")
            bpy.ops.export_scene.gltf(filepath=g, export_format="GLB")
            print(f"Exported {g}")


if __name__ == "__main__":
    main()
