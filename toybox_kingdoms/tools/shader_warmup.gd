extends Node

# ── Shader warm-up ────────────────────────────────────────────────────────────
# The match's first frame stalls while the GPU compiles each custom shader the
# first time it's drawn (the main load hitch — minor on desktop, seconds on a
# phone). We pre-compile them HERE, on the main menu, by drawing one quad / one
# MultiMesh per shader into a tiny off-screen viewport for a few frames. The
# compiled shaders land in the session cache, so by the time the board loads they
# are already warm. Fire-and-forget: it frees itself once everything has rendered.
#
# The instanced shaders are warmed on a 1-instance MultiMesh (not a plain mesh) so
# the INSTANCED pipeline variant — the one the board actually uses — is what compiles.

const GroundScript := preload("res://toybox_kingdoms/grid/territory_ground.gd")
const RendererScript := preload("res://toybox_kingdoms/grid/grid_renderer.gd")
const CastleScript := preload("res://toybox_kingdoms/kingdom/castle.gd")
const FlagsScript := preload("res://toybox_kingdoms/kingdom/flags.gd")
const PopScript := preload("res://toybox_kingdoms/kingdom/populace.gd")

var _vp: SubViewport
var _frames := 0

func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(8, 8)                       # we never look at it; size is irrelevant
	_vp.own_world_3d = true                         # isolated world — never touches the menu
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 3)
	_vp.add_child(cam)
	_vp.add_child(DirectionalLight3D.new())        # a light so the lit shaders take their lit path

	# Ground shader → on a plane, mirroring the board's single-mesh ground.
	_add_mesh(GroundScript.SHADER_CODE, PlaneMesh.new())
	# Instanced shaders → on a 1-instance MultiMesh (the board's real draw path).
	_add_multimesh(RendererScript.TRAIL_SHADER)
	_add_multimesh(CastleScript.ROOF_SHADER)
	_add_multimesh(FlagsScript.BANNER_SHADER)
	_add_multimesh(PopScript.CIT_SHADER)

func _shader_mat(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

func _add_mesh(code: String, mesh: Mesh) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _shader_mat(code)
	_vp.add_child(mi)

func _add_multimesh(code: String) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D.IDENTITY)
	mm.set_instance_color(0, Color.WHITE)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _shader_mat(code)
	_vp.add_child(mmi)

func _process(_delta: float) -> void:
	# Give it a few frames so every pipeline finishes compiling, then dispose.
	_frames += 1
	if _frames >= 4:
		queue_free()
