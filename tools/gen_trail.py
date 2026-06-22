# Headless Blender generator for the trail block -> assets/models/trail.glb
# A small rounded (bevelled) cube; tinted per-kingdom + glowing via the trail
# shader in grid_renderer. Unit cube, scaled per-instance in Godot.
# Run:  blender --background --python tools/gen_trail.py
import sys, os

sys.path.append(os.path.dirname(__file__))
import tbk_lib as T

T.reset()
m = T.mat("trail", (1.0, 1.0, 1.0))
o = T.box(0.5, 0.5, 0.5, 0, 0, 0)        # unit 1x1x1 cube
o.data.materials.append(m)
T.bevel(o, width=0.16, segments=3)       # rounded toy-block edges
T.export("trail")
print("TRAIL_DONE")
