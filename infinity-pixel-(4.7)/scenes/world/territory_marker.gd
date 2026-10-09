extends StaticBody3D

# Spec: docs/specs/015-territorios-controlados.md — RF-TER-004 / 007 (PROVISORIO)
#
# Marco territorial: pedestal de pedra baixo com um cristal antigo. So visual e
# corpo pequeno; o estado e a interacao vivem no TerritoryManager.
# - WILD: cristal apagado (cinza-violeta, quase sem emissao).
# - READY_TO_CLAIM: cristal dourado pulsando ("pronto para ser recuperado").
# - CONTROLLED: cristal jade aceso, com luz local pequena (sem sombra).
# Participa do brilho noturno da Spec 014 (grupo "night_glow").

const Palette := preload("res://scenes/visuals/palette.gd")
const Facets := preload("res://scenes/visuals/facets.gd")
const BUILDINGS := 1 << 3
const WILD_COLOR := Color("6f6a80")
const READY_COLOR := Color("f2c86a")
const CONTROLLED_COLOR := Color("7fe0b8")
const VISUAL_SCALE := 1.45 # legivel da camera estrategica entre as arvores

var state := 0 # TerritoryManager.WILD / READY_TO_CLAIM / CONTROLLED
var _crystal: MeshInstance3D
var _crystal_mat: StandardMaterial3D
var _rune_mat: StandardMaterial3D # faixa de runas do obelisco (mesma cor do cristal)
var _light: OmniLight3D
var _glow := 0.0
var _time := 0.0
var _visual: Node3D

func _ready() -> void:
	add_to_group("territory_marker")
	add_to_group("night_glow") # Spec 014: DayNightVisual chama set_night_glow()
	collision_layer = BUILDINGS
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.75
	cyl.height = 2.0
	shape.shape = cyl
	shape.position.y = 1.0
	add_child(shape)
	var obstacle := NavigationObstacle3D.new() # so avoidance; navmesh intacta
	obstacle.radius = 0.95
	obstacle.height = 2.0
	obstacle.avoidance_enabled = true
	add_child(obstacle)
	_build_visual()
	set_state(state)

func set_state(s: int) -> void:
	state = s
	if _crystal_mat == null:
		return
	var color: Color = [WILD_COLOR, READY_COLOR, CONTROLLED_COLOR][s]
	_crystal_mat.albedo_color = color
	_crystal_mat.emission = color
	_rune_mat.albedo_color = color
	_rune_mat.emission = color
	_light.light_color = color
	_apply_glow()
	set_process(s == 1) # so o READY pulsa; os outros estados nao custam nada por quadro

func set_night_glow(f: float) -> void:
	_glow = f
	_apply_glow()

func _apply_glow() -> void:
	var base: float = [0.12, 1.1, 1.0][state]
	_crystal_mat.emission_energy_multiplier = base + (0.2 if state == 0 else 1.0) * _glow
	_rune_mat.emission_energy_multiplier = _crystal_mat.emission_energy_multiplier
	_light.visible = state != 0
	_light.light_energy = (0.5 if state == 1 else 0.7) + 0.9 * _glow

func _process(delta: float) -> void:
	_time += delta
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	_crystal_mat.emission_energy_multiplier = 0.7 + 0.9 * pulse + _glow
	_rune_mat.emission_energy_multiplier = _crystal_mat.emission_energy_multiplier
	_crystal.position.y = 1.05 + 0.05 * pulse

## Efeito curto da conquista: anel de energia que se expande no chao e cristal
## que salta. Nada de modal ou pausa (RF-TER-008).
func play_claim_effect() -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.05
	torus.rings = 32
	torus.ring_segments = 4
	ring.mesh = torus
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(CONTROLLED_COLOR, 0.8)
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.08
	ring.scale = Vector3(1, 0.3, 1)
	add_child(ring)
	var t := ring.create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector3(7, 0.3, 7), 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(m, "albedo_color:a", 0.0, 1.1)
	t.chain().tween_callback(ring.queue_free)
	_crystal.scale = Vector3.ONE * 1.35
	_crystal.create_tween().tween_property(_crystal, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK)

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m

# Spec 018: marco facetado. Pedestal de pedra em 2 niveis, obelisco com uma faixa
# de runas que acende na cor do estado e o cristal no topo (mesmas alturas e o
# mesmo papel de antes; _crystal e _crystal_mat continuam sendo o cristal).
func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.scale = Vector3.ONE * VISUAL_SCALE
	add_child(_visual)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1515
	var tones := [Palette.STONE_LIGHT, Palette.STONE, Palette.STONE_DARK]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint := func(c: Vector3, n: Vector3) -> Color:
		return Facets.by_height(tones, n, c.y, 0.0, 0.95, c.x + c.z)
	Facets.loft(st, [
		Facets.ring(6, 0.72, -0.02, rng, 0.04, 0.3),
		Facets.ring(6, 0.66, 0.2, rng, 0.04, 0.3),
		Facets.ring(6, 0.5, 0.24, rng, 0.03, 0.3),
		Facets.ring(6, 0.46, 0.36, rng, 0.03, 0.3),
	], true, null, paint)
	Facets.loft(st, [
		Facets.ring(5, 0.34, 0.34, rng, 0.04, 0.1),
		Facets.ring(5, 0.27, 0.86, rng, 0.04, 0.15),
		Facets.ring(5, 0.3, 0.92, rng, 0.02, 0.15),
	], true, null, paint)
	for i in 3: # pedras de apoio rentes
		var a := TAU * i / 3.0 + 0.4
		var at := Transform3D(Basis(), Vector3(sin(a) * 0.85, 0, cos(a) * 0.85))
		Facets.loft(st, [Facets.ring(5, 0.15, -0.02, rng, 0.2, a, 0.0, at), Facets.ring(5, 0.11, 0.08, rng, 0.2, a, 0.0, at)],
			at * Vector3(0, 0.14, 0), null, paint)
	var body := MeshInstance3D.new()
	body.mesh = st.commit()
	body.material_override = Palette.toon(0.3, 0.12)
	_visual.add_child(body)
	# Faixa de runas do obelisco: mesma cor e brilho do cristal.
	_crystal_mat = Palette.toon(0.25, 0.3)
	_crystal_mat.vertex_color_use_as_albedo = false
	_crystal_mat.albedo_color = WILD_COLOR
	_crystal_mat.emission_enabled = true
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var white := func(_c: Vector3, _n: Vector3) -> Color:
		return Color.WHITE
	Facets.loft(st, [Facets.ring(5, 0.33, 0.55, rng, 0.0, 0.12), Facets.ring(5, 0.31, 0.63, rng, 0.0, 0.12)], null, null, white)
	var runes := MeshInstance3D.new()
	runes.mesh = st.commit()
	runes.material_override = _crystal_mat
	_visual.add_child(runes)
	# Cristal facetado (bipiramide) no topo.
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var facet := func(_c: Vector3, n: Vector3) -> Color:
		return Color.WHITE.darkened(0.12) if fposmod(atan2(n.z, n.x) / TAU * 5.0, 2.0) < 1.0 else Color.WHITE
	Facets.loft(st, [Facets.ring(5, 0.2, -0.08, rng, 0.05), Facets.ring(5, 0.19, 0.08, rng, 0.05, 0.2)],
		Vector3(0, 0.36, 0), Vector3(0, -0.3, 0), facet)
	_crystal = MeshInstance3D.new()
	_crystal.mesh = st.commit()
	var gem_mat := _crystal_mat.duplicate() as StandardMaterial3D
	gem_mat.vertex_color_use_as_albedo = true # facetas claro/escuro sobre a cor do estado
	_crystal_mat = gem_mat
	_rune_mat = runes.material_override
	_crystal.material_override = _crystal_mat
	_crystal.position.y = 1.05
	_visual.add_child(_crystal)
	_light = OmniLight3D.new()
	_light.omni_range = 3.5
	_light.shadow_enabled = false
	_light.position.y = 1.4
	_visual.add_child(_light)
