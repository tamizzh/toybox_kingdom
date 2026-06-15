"""
gen_mascot.py — BLOB mascot for Party Pals Arena.

Design: pure round ball body (no limbs), very large googly eyes on the +X face,
matching the reference art (round Stumble-Guys-style blobs, NOT humanoid).

Body is a sphere squished slightly in Z so it looks like it's sitting on the
ground.  Bottom sits exactly at Blender Z=0 → Godot Y=0, so no y-offset is
needed when calling set_model() in avatar3d.gd.

Face direction: +X  (matches avatar3d.gd and tank.glb convention).

Run:
    blender --background --python tools/gen_mascot.py
"""
import bpy, math, os

OUTPUT = bpy.path.abspath("//players/mascot.glb")

# ── clear scene ─────────────────────────────────────────────────────────────
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
for col in [bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights]:
    for item in list(col):
        col.remove(item)

# ── helpers ──────────────────────────────────────────────────────────────────
def pbr(name, r, g, b, roughness=0.5, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_fake_user = True
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (r, g, b, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND"
    return m

def cyl(loc, radius, depth, rot_y=0):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=32, radius=radius, depth=depth, location=loc)
    obj = bpy.context.active_object
    if rot_y:
        obj.rotation_euler.y = rot_y
        bpy.ops.object.transform_apply(rotation=True)
    bpy.ops.object.shade_smooth()
    return obj

# ── BODY ─────────────────────────────────────────────────────────────────────
# Centre at Z=0.82, radius=1.0, Z-squish=0.82
#   → bottom exactly at Z=0 (floor), top at Z=1.64, equatorial radius=1.0
BC_Z  = 0.82   # center height
BC_SZ = 0.82   # vertical squish factor

bpy.ops.mesh.primitive_uv_sphere_add(
    radius=1.0, segments=48, ring_count=24, location=(0, 0, BC_Z))
body = bpy.context.active_object
body.name = "body"
body.scale.z = BC_SZ
bpy.ops.object.transform_apply(scale=True)
sub = body.modifiers.new("Sub", "SUBSURF")
sub.levels = 2
bpy.ops.object.modifier_apply(modifier="Sub")
bpy.ops.object.shade_smooth()
body.data.materials.append(pbr("body", 1.0, 1.0, 1.0, roughness=0.40))

# ── EYES ─────────────────────────────────────────────────────────────────────
# Flat disc cylinders embedded in the +X sphere surface, upper portion of face.
# Eye white radius 0.32 = 32% of body radius — deliberately VERY large.
#
# Sphere surface at (Y=±0.27, Z=1.08):
#   X² = 1 − 0.27² − ((1.08−0.82)/0.82)² ≈ 0.811  →  X ≈ 0.901
#
ROT_Y = math.pi / 2.0   # rotate cylinder so flat face points along +X

EX  = 0.90    # eye disc centre, forward on +X face
EY  = 0.27    # side offset (centre of each eye from body axis)
EZ  = 1.08    # height (≈ 65 % of the way up the blob face)
EWR = 0.32    # eye white radius
EWD = 0.22    # eye white disc depth (straddles the sphere surface)
PR  = 0.185   # pupil radius
PD  = 0.12    # pupil depth
SR  = 0.070   # shine spot radius
SD  = 0.07    # shine spot depth

# Z-fighting fix — all layers must have their FRONT FACE clearly ahead of the layer below:
#   eye white front  = EX + EWD/2  = 0.90 + 0.11  = 1.01
#   pupil front      = (EX+0.09) + PD/2 = 0.99 + 0.06 = 1.05  (+0.04 clearance)
#   shine front      = (EX+0.12) + SD/2 = 1.02 + 0.035 = 1.055 (+0.005 clearance)

for tag, sy in (("l", EY), ("r", -EY)):
    # Eye white — large white disc
    ew = cyl((EX, sy, EZ), EWR, EWD, ROT_Y)
    ew.name = f"eye_white_{tag}"
    ew.data.materials.append(pbr(f"eye_w_{tag}", 1.0, 1.0, 1.0, roughness=0.04))

    # Pupil — pushed ahead 0.09 so front face (1.05) clears eye white (1.01) by 0.04
    pu = cyl((EX + 0.09, sy - 0.02, EZ - 0.06), PR, PD, ROT_Y)
    pu.name = f"pupil_{tag}"
    pu.data.materials.append(pbr(f"pupil_{tag}", 0.04, 0.03, 0.08, roughness=0.08))

    # Large shine spot — pushed 0.12 ahead, clears pupil face comfortably
    sh1 = cyl((EX + 0.12, sy - 0.115, EZ + 0.058), SR, SD, ROT_Y)
    sh1.name = f"shine_{tag}"
    sh1.data.materials.append(pbr(f"shine_{tag}", 1.0, 1.0, 1.0, roughness=0.02))

    # Tiny secondary shine spot (lower-inner)
    sh2 = cyl((EX + 0.12, sy + 0.04, EZ - 0.10), SR * 0.44, SD * 0.55, ROT_Y)
    sh2.name = f"shine2_{tag}"
    sh2.data.materials.append(pbr(f"shine2_{tag}", 1.0, 1.0, 1.0, roughness=0.02))

    # Cheek blush — soft pink, below and outside the eye
    ch = cyl((EX * 0.84, sy * 1.72, EZ - 0.47), 0.145, 0.035, ROT_Y)
    ch.name = f"cheek_{tag}"
    ch.data.materials.append(
        pbr(f"cheek_{tag}", 1.0, 0.50, 0.65, roughness=0.90, alpha=0.50))

# ── EXPORT ───────────────────────────────────────────────────────────────────
os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(
    filepath=OUTPUT,
    export_format='GLB',
    use_selection=True,
    export_apply=True,
)
print(f"GEN_OK: {OUTPUT}")
