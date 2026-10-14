extends MultiMeshInstance3D

# World 6.0 — pegadas do Player (so visual).
#
# Uma MultiMesh com um numero FIXO de instancias (MAX_PRINTS) usada como anel:
# cada passo reaproveita a pegada mais antiga (nenhum no criado por passo, uma
# chamada de desenho para todas). Um passo nasce a cada STRIDE metros REALMENTE
# percorridos (empurrar uma parede nao deixa rastro), alternando pe esquerdo e
# direito, atras dos pes, virado para a direcao do movimento. Parado, nada
# nasce. Cada pegada some aos poucos (LIFE s). A cor depende da superficie
# (WorldBiomes.surface_at): terra/floresta escura, pedra = poeira clara,
# margem da agua = umida e escura, vulcao = cinza revolvida.

const WorldBiomes := preload("res://scenes/world/world_biomes.gd")
const MAX_PRINTS := 48
const STRIDE := 0.85 # m entre pegadas (passada de corrida a 6 m/s)
const SIDE := 0.13 # m do centro ate cada pe
const LIFE := 6.0 # s ate sumir
const FADE := 2.5 # s finais em que esmaece
const Y := 0.09 # acima do relevo do chao (no maximo 0,075 m)
const TONES := {
	&"forest": Color(0.15, 0.1, 0.06, 0.6),
	&"stone": Color(0.88, 0.85, 0.76, 0.34),
	&"water": Color(0.04, 0.07, 0.07, 0.66),
	&"volcano": Color(0.52, 0.49, 0.47, 0.6),
}

@export var player_path: NodePath = ^"../Player"

var player: Node3D
var _born: PackedFloat64Array = []
var _next := 0 # proxima instancia do anel
var _left := true
var _travel := 0.0
var _last := Vector3.INF
var _time := 0.0
var active := 0 # pegadas visiveis agora (testes e medicao)
var surfaces: Array[StringName] = [] # superficie de cada instancia (testes)
var xforms: Array[Transform3D] = [] # transform de cada instancia (testes; o servidor sem janela nao devolve)

func _ready() -> void:
	name = "PlayerFootprints"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player = get_node_or_null(player_path)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _print_mesh()
	mm.instance_count = MAX_PRINTS
	mm.custom_aabb = AABB(Vector3(-80, -60, -80), Vector3(160, 70, 160)) # sem recalcular a caixa a cada passo
	multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED # o pe esquerdo e o direito espelhado
	material_override = mat
	_born.resize(MAX_PRINTS)
	surfaces.resize(MAX_PRINTS)
	xforms.resize(MAX_PRINTS)
	for i in MAX_PRINTS:
		_born[i] = -INF
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -50, 0)))
		mm.set_instance_color(i, Color(0, 0, 0, 0))
	# A pegada fica fixa no mundo, mesmo se este no estiver dentro de algo movel.
	top_level = true
	global_transform = Transform3D.IDENTITY

## Sola de bota low-poly (planta + calcanhar), deitada no chao, bico em +Z.
static func _print_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blob := func(c: Vector2, r: Vector2, sides: int) -> void:
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			for v in [c, c + Vector2(cos(a1) * r.x, sin(a1) * r.y), c + Vector2(cos(a0) * r.x, sin(a0) * r.y)]:
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(v.x, 0, v.y))
	blob.call(Vector2(0, 0.08), Vector2(0.1, 0.13), 8) # planta (World 6.0: legivel da camera estrategica)
	blob.call(Vector2(0, -0.13), Vector2(0.08, 0.072), 7) # calcanhar
	return st.commit()

func _physics_process(delta: float) -> void:
	_time += delta
	_fade()
	if player == null or not is_instance_valid(player):
		return
	var pos := player.global_position
	if _last == Vector3.INF or player.get("is_dead") == true:
		_last = pos
		return
	var step := Vector2(pos.x - _last.x, pos.z - _last.z)
	_last = pos
	if step.length() > 2.0: # teleporte (respawn, teste): sem rastro
		_travel = 0.0
		return
	_travel += step.length()
	if _travel >= STRIDE and step.length() > 0.0005:
		_travel = fmod(_travel, STRIDE)
		_place(Vector2(pos.x, pos.z), step.normalized())

func _place(at: Vector2, dir: Vector2) -> void:
	var side := Vector2(dir.y, -dir.x) * (SIDE if _left else -SIDE)
	var p := at - dir * 0.12 + side # atras dos pes, do lado do pe da vez
	var yaw := atan2(dir.x, dir.y)
	var surface := WorldBiomes.surface_at(p)
	var i := _next
	_next = (_next + 1) % MAX_PRINTS
	_born[i] = _time
	surfaces[i] = surface
	var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(1.0 if _left else -1.0, 1.0, 1.0)) # pe direito = esquerdo espelhado
	xforms[i] = Transform3D(basis, Vector3(p.x, Y, p.y))
	multimesh.set_instance_transform(i, xforms[i])
	multimesh.set_instance_color(i, TONES[surface])
	_left = not _left

func _fade() -> void:
	active = 0
	for i in MAX_PRINTS:
		var age := _time - _born[i]
		if age > LIFE + 0.5:
			continue
		if age > LIFE:
			multimesh.set_instance_color(i, Color(0, 0, 0, 0))
			multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -50, 0)))
			_born[i] = -INF
			continue
		active += 1
		if age > LIFE - FADE:
			var c: Color = TONES[surfaces[i]]
			c.a *= clampf((LIFE - age) / FADE, 0.0, 1.0)
			multimesh.set_instance_color(i, c)

## Para testes: quantas pegadas existem (nos) — sempre uma so MultiMesh.
func node_count() -> int:
	return get_child_count() + 1
