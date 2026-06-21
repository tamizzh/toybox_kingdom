# Headless Blender generator for a low-poly toy castle -> assets/models/castle.glb
# Kept as TWO joined objects so castle.gd can find + tint the "roof" per kingdom:
#   "stone" (cream keep / towers / walls)  +  "roof" (cones / flag)
# Every edge bevelled for the painted-wood toy look.
# Run:  blender --background --python tools/gen_castle.py
import bpy, sys, os, math

sys.path.append(os.path.dirname(__file__))
import tbk_lib as T

T.reset()
stone_mat = T.mat("stone", (0.48, 0.49, 0.55))   # grey toy stone (target look)
roof_mat = T.mat("roof", (0.72, 0.22, 0.18), rough=0.6)


def cone4(r, d, x, y, z, v=4):
	o = T.cone(r, d, x, y, z, verts=v)
	if v == 4:
		o.rotation_euler[2] = math.radians(45)
		bpy.ops.object.transform_apply(rotation=True)
	return o


stone, roof = [], []
corners = [(-1.25, -1.25), (1.25, -1.25), (-1.25, 1.25), (1.25, 1.25)]

stone.append(T.box(0.7, 0.7, 1.1, 0, 0, 1.1))           # central keep
for cx, cy in corners:
	stone.append(T.cyl(0.38, 1.8, cx, cy, 0.9))         # corner tower
	roof.append(cone4(0.54, 0.8, cx, cy, 1.8 + 0.4, 8)) # tower roof
	# banner: thin pole + a kingdom-coloured pennant flying off each tower
	stone.append(T.cyl(0.025, 0.7, cx, cy, 2.95, verts=6))
	roof.append(T.box(0.16, 0.02, 0.1, cx + 0.17, cy, 3.12))
# connecting walls
stone.append(T.box(1.25, 0.16, 0.45, 0, -1.25, 0.45))
stone.append(T.box(1.25, 0.16, 0.45, 0, 1.25, 0.45))
stone.append(T.box(0.16, 1.25, 0.45, -1.25, 0, 0.45))
stone.append(T.box(0.16, 1.25, 0.45, 1.25, 0, 0.45))
# keep battlements
for mx, my in [(-0.55, -0.55), (0.55, -0.55), (-0.55, 0.55), (0.55, 0.55)]:
	stone.append(T.box(0.16, 0.16, 0.2, mx, my, 2.2 + 0.2))
# keep roof + flag pole + flag
roof.append(cone4(1.0, 1.25, 0, 0, 2.2 + 0.62, 4))
stone.append(T.box(0.04, 0.04, 0.5, 0, 0, 2.85 + 0.5))
roof.append(T.box(0.32, 0.04, 0.22, 0.2, 0, 3.55))

for o in stone:
	o.data.materials.append(stone_mat)
for o in roof:
	o.data.materials.append(roof_mat)

stone_obj = T.join(stone, "stone")
T.bevel(stone_obj, width=0.03)
roof_obj = T.join(roof, "roof")
T.bevel(roof_obj, width=0.03)

T.export("castle")
print("CASTLE_DONE")
