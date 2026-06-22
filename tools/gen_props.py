# Headless Blender generator for low-poly environment props (tree / rock / bush).
# Each is ONE joined mesh (so scatter.gd draws it as a single MultiMesh).
# Run:  blender --background --python tools/gen_props.py
import bpy, bmesh, sys, os
from collections import defaultdict

sys.path.append(os.path.dirname(__file__))
import tbk_lib as T

# ── TREE: organic bark trunk + 3 beveled high-res conical tiers ──────────────
# 24-vert cones look perfectly circular when smooth-shaded → soft curvy feel.
# r2=0.02 gives a tiny flat top so bevel can round the tip (no spike).
# Trunk bark: subdivide lateral edges → scale alternate rings outward 13%.
T.reset()
brown = T.mat("trunk", (0.35, 0.22, 0.10), rough=0.60, spec=0.30)
green = T.mat("leaf",  (0.12, 0.44, 0.14), rough=0.38, spec=0.50)

TRUNK_R = 0.10
TRUNK_H = 0.48

bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=TRUNK_R,
                                    depth=TRUNK_H, location=(0, 0, TRUNK_H / 2))
trunk = bpy.context.active_object

# Bark ridges: subdivide height edges then swell alternate rings
bpy.ops.object.mode_set(mode='EDIT')
bm = bmesh.from_edit_mesh(trunk.data)
lat_edges = [e for e in bm.edges
             if abs(e.verts[0].co.z - e.verts[1].co.z) > TRUNK_H * 0.08]
bmesh.ops.subdivide_edges(bm, edges=lat_edges, cuts=5)

rings_z = defaultdict(list)
for v in bm.verts:
    rings_z[round(v.co.z, 3)].append(v)
sorted_zkeys = sorted(rings_z.keys())
for i, zk in enumerate(sorted_zkeys[1:-1]):   # skip absolute top/bottom caps
    if i % 2 == 0:
        for v in rings_z[zk]:
            v.co.x *= 1.13
            v.co.y *= 1.13

bmesh.update_edit_mesh(trunk.data)
bpy.ops.object.mode_set(mode='OBJECT')
trunk.data.materials.append(brown)
T.bevel(trunk, width=0.025, segments=3)

# Tiers lifted so tier1 base (z≈0.40) is above the trunk top (z=0.48) by intent —
# a small gap lets the trunk read clearly from the isometric camera.
# 24 verts each, tiny r2 so the bevel can round the tip (no spike).
tier1 = T.cone(0.52, 0.52, 0, 0, 0.66, verts=24, r2=0.02)
tier2 = T.cone(0.35, 0.44, 0, 0, 0.90, verts=24, r2=0.015)
tier3 = T.cone(0.21, 0.37, 0, 0, 1.09, verts=24, r2=0.01)
for t in [tier1, tier2, tier3]:
    t.data.materials.append(green)
    T.bevel(t, width=0.048, segments=4, angle=1.3)

T.join([trunk, tier1, tier2, tier3], "tree")
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
