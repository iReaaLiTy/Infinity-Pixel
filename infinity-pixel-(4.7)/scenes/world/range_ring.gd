extends MeshInstance3D

# Spec: docs/specs/013c-combate-coleta-hud.md — RF-CMB-007 (PROVISORIO)
# Anel fino e translucido no chao. `radius` e o raio EXATO em metros (o mesmo
# valor da logica de alvo da torre): a malha e gerada com esse raio na linha
# media do anel, sem escala aproximada.

const SEGMENTS := 72
const WIDTH := 0.12 # m de espessura da linha
const LIFT := 0.06 # m acima do chao (o mapa e plano; trilhas ficam a ~0,035)

var radius := 0.0
var _material: StandardMaterial3D

func _init() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = Color(0.75, 1.0, 0.88, 0.0)
	_material.no_depth_test = false
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position.y = LIFT

func set_radius(value: float) -> void:
	if is_equal_approx(value, radius):
		return
	radius = value
	var inner := radius - WIDTH * 0.5
	var outer := radius + WIDTH * 0.5
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in SEGMENTS:
		var a := TAU * i / SEGMENTS
		var dir := Vector3(sin(a), 0, cos(a))
		verts.append(dir * inner)
		verts.append(dir * outer)
	for i in SEGMENTS:
		var j := (i + 1) % SEGMENTS
		indices.append_array([i * 2, i * 2 + 1, j * 2, j * 2, i * 2 + 1, j * 2 + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = array_mesh

## 0 = invisivel. Suaviza a mudanca para nao piscar.
func set_strength(alpha: float, delta: float) -> void:
	var c := _material.albedo_color
	c.a = lerpf(c.a, alpha, 1.0 - exp(-10.0 * delta))
	_material.albedo_color = c
	visible = c.a > 0.03 # abaixo disso some de vez (fade nao fica "quase visivel")
