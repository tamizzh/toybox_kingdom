# Headless Blender generator for a low-poly crenellated WALL block (one per border
# cell). Single bevelled mesh + single grey material so Godot tints it per-instance
# to the kingdom colour in a MultiMesh. Footprint = one grid cell (0.6); adjacent
# blocks butt together into a continuous battlemented wall.
#
# Run:  blender --background --python tools/gen_wall.py
import sys, os

sys.path.append(os.path.dirname(__file__))
import tbk_lib as T

T.reset()
stone = T.mat("wall", (0.72, 0.72, 0.75), rough=0.9, spec=0.1)

parts = []
# base wall slab: 0.6 x 0.6 x 0.55
parts.append(T.box(0.3, 0.3, 0.275, 0, 0, 0.275))
# 4 corner merlons -> reads crenellated from any side
for sx in (-1, 1):
	for sy in (-1, 1):
		parts.append(T.box(0.1, 0.1, 0.1, sx * 0.2, sy * 0.2, 0.62))

o = T.join(parts, "wall")
o.data.materials.append(stone)
T.bevel(o, width=0.025)        # soften every edge -> painted-wood battlement
T.export("wall")
print("WALL_DONE")
