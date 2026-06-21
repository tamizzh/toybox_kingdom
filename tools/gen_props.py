# Headless Blender generator for low-poly environment props (tree / rock / bush).
# Each is ONE joined mesh (so scatter.gd draws it as a single MultiMesh). The
# trunk's bevelled hard edges read as painted wood; the foliage/rock/bush are
# spheres, so they're just smooth-shaded (bevelling a sphere only bloats it).
# Material SLOTS are kept + named (trunk/leaf) so scatter can paint each surface
# in code without depending on GLB material colours importing.
#
# Run:  blender --background --python tools/gen_props.py
import bpy, sys, os

sys.path.append(os.path.dirname(__file__))
import tbk_lib as T

# ── TREE: hex trunk + rounded foliage blob (joined -> slot0 trunk, slot1 leaf) ─
T.reset()
brown = T.mat("trunk", (0.42, 0.27, 0.13), rough=0.95)
green = T.mat("leaf", (0.27, 0.60, 0.24))
trunk = T.cyl(0.12, 0.55, 0, 0, 0.27, verts=6)
trunk.data.materials.append(brown)
T.bevel(trunk, width=0.03)
foliage = T.ico(0.5, 0, 0, 0.95)
foliage.scale = (1.0, 1.0, 1.18)
bpy.ops.object.transform_apply(scale=True)
foliage.data.materials.append(green)
T.smooth(foliage)                                # already round — just smooth, don't bevel
T.join([trunk, foliage], "tree")                 # one mesh, two material surfaces
T.export("tree")

# ── ROCK: squashed low-poly boulder ──────────────────────────────────────────
T.reset()
grey = T.mat("rock", (0.55, 0.55, 0.60))
r = T.ico(0.4, 0, 0, 0.16)
r.scale = (1.25, 1.0, 0.62)
bpy.ops.object.transform_apply(scale=True)
r.data.materials.append(grey)
T.smooth(r)
T.export("rock")

# ── BUSH: a few merged green blobs ───────────────────────────────────────────
T.reset()
bgreen = T.mat("bush", (0.30, 0.56, 0.24))
blobs = []
for dx, dy, rad in [(0.0, 0.0, 0.26), (0.22, 0.05, 0.22), (-0.18, 0.12, 0.2)]:
	b = T.ico(rad, dx, dy, 0.16)
	b.data.materials.append(bgreen)
	blobs.append(b)
merged = T.join(blobs, "bush")
T.smooth(merged)
T.export("bush")

print("PROPS_DONE")
