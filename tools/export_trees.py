# Export all user-supplied tree .blend files to assets/models/ as GLBs.
# Each blend has separate trunk + leaves objects — we join them into ONE mesh
# with trunk as active so material slots are: 0=bark_dark, 1=tree_green.
# scatter.gd then paints slot0=brown, slot1=green correctly.
# Run: blender --background --python tools/export_trees.py
import bpy, os

ROOT   = r"C:\Users\rpandian\Documents\toybox kingdom"
ASSETS = os.path.join(ROOT, "assets")
OUT    = os.path.join(ROOT, "assets", "models")

TREES = [
    "tree-conical",
    "tree-pyramidal",
    "tree-round",
    "tree-oval",
    "tree-spreading",
    "tree-open",
    "tree-branched",
    "tree-vase",
]

def join_and_export(name, out_path):
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    if not meshes:
        print("SKIP (no meshes):", name)
        return

    # Pick trunk as active so its material (bark) becomes slot 0
    trunk = next((o for o in meshes if 'trunk' in o.name.lower()), meshes[0])
    leaves = [o for o in meshes if o is not trunk]

    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = trunk
    if len(meshes) > 1:
        bpy.ops.object.join()   # trunk active → slot 0=bark, then leaves slots follow

    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format='GLB',
        use_selection=False,
        export_apply=True,
    )
    print("WROTE", name + ".glb")

for name in TREES:
    blend = os.path.join(ASSETS, name + ".blend")
    if not os.path.exists(blend):
        print("SKIP (no .blend):", name)
        continue

    bpy.ops.wm.open_mainfile(filepath=blend)
    join_and_export(name, os.path.join(OUT, name + ".glb"))

print("TREES_DONE")
