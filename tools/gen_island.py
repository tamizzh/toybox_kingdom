# Headless Blender generator for the island base -> assets/models/island.glb
# A rounded-rectangle slab (bevelled box) the play board sits on, rising out of
# the water. Grassy green; scaled uniformly in Godot so the corners stay round.
# Run:  blender --background --python tools/gen_island.py
import sys, os

sys.path.append(os.path.dirname(__file__))
import tbk_lib as T

T.reset()
grass = T.mat("island", (0.40, 0.55, 0.26))
o = T.box(8.0, 6.0, 0.5, 0, 0, 0)        # 16 x 12 x 1.0  (ratio ~1.33, matches grid)
o.data.materials.append(grass)
T.bevel(o, width=0.7, segments=6)        # round the rectangle corners + edges
T.export("island")
print("ISLAND_DONE")
