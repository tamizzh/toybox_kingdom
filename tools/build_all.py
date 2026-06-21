#!/usr/bin/env python3
# Regenerate every Toybox Kingdoms 3D asset by running each gen_*.py headless in
# Blender. Run from the project root with plain Python (it shells out to Blender):
#
#   python tools/build_all.py
#
# Override the Blender path with the BLENDER env var if it's not the default.
import os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER = os.environ.get("BLENDER", r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe")

# Generators that build assets/models/*.glb via tbk_lib (order: deps first).
GENERATORS = [
	"gen_floor_tile.py",
	"gen_wall.py",
	"gen_props.py",
	"gen_castle.py",
]


def main():
	if not os.path.exists(BLENDER):
		sys.exit("Blender not found at %s — set the BLENDER env var." % BLENDER)
	failed = []
	for g in GENERATORS:
		script = os.path.join(ROOT, "tools", g)
		print("=== %s ===" % g, flush=True)
		r = subprocess.run([BLENDER, "--background", "--python", script],
			capture_output=True, text=True)
		out = r.stdout + r.stderr
		ok = r.returncode == 0 and "Error:" not in out and "Traceback" not in out
		# echo the generator's own DONE / WROTE markers
		for line in out.splitlines():
			if any(t in line for t in ("WROTE", "_DONE", "GEN_OK", "Error", "Traceback")):
				print("   " + line)
		if not ok:
			failed.append(g)
			print("   !! FAILED (exit %d)" % r.returncode)
	print("\nBuilt %d/%d generators." % (len(GENERATORS) - len(failed), len(GENERATORS)))
	if failed:
		sys.exit("Failed: " + ", ".join(failed))


if __name__ == "__main__":
	main()
