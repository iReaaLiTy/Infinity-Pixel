extends StaticBody3D

# Spec: docs/specs/015-territorios-controlados.md — RF-TER-004 / 007 (PROVISORIO)
#
# Marco territorial: pedestal de pedra baixo com um cristal antigo. So visual e
# corpo pequeno; o estado e a interacao vivem no TerritoryManager.
# - WILD: cristal apagado (cinza-violeta, quase sem emissao).
# - READY_TO_CLAIM: cristal dourado pulsando ("pronto para ser recuperado").
# - CONTROLLED: cristal jade aceso, com luz local pequena (sem sombra).
# Participa do brilho noturno da Spec 014 (grupo "night_glow").

const BUILDINGS := 1 << 3
const WILD_COLOR := Color("6f6a80")
const READY_COLOR := Color("f2c86a")
const CONTROLLED_COLOR := Color("7fe0b8")
const VISUAL_SCALE := 1.45 # legivel da camera estrategica entre as arvores

var state := 0 # TerritoryManager.WILD / READY_TO_CLAIM / CONTROLLED
var _crystal: MeshInstance3D
var _crystal_mat: StandardMaterial3D
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
	_light.light_color = color
	_apply_glow()
	set_process(s == 1) # so o READY pulsa; os outros estados nao custam nada por quadro

func set_night_glow(f: float) -> void:
	_glow = f
	_apply_glow()

func _apply_glow() -> void:
	var base: float = [0.12, 1.1, 1.0][state]
	_crystal_mat.emission_energy_multiplier = base + (0.2 if state == 0 else 1.0) * _glow
	_light.visible = state != 0
	_light.light_energy = (0.5 if state == 1 else 0.7) + 0.9 * _glow

func _process(delta: float) -> void:
	_time += delta
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	_crystal_mat.emission_energy_multiplier = 0.7 + 0.9 * pulse + _glow
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

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.scale = Vector3.ONE * VISUAL_SCALE
	add_child(_visual)
	var base := MeshInstance3D.new()
	var plinth := CylinderMesh.new()
	plinth.top_radius = 0.55
	plinth.bottom_radius = 0.7
	plinth.height = 0.35
	plinth.radial_segments = 6
	base.mesh = plinth
	base.material_override = _mat(Color("8d9a8f"))
	base.position.y = 0.17
	_visual.add_child(base)
	var column := MeshInstance3D.new()
	var col_mesh := CylinderMesh.new()
	col_mesh.top_radius = 0.26
	col_mesh.bottom_radius = 0.36
	col_mesh.height = 0.6
	col_mesh.radial_segments = 5
	column.mesh = col_mesh
	column.material_override = _mat(Color("7c8980"))
	column.position.y = 0.62
	_visual.add_child(column)
	for i in 3: # pedrinhas de apoio ao redor
		var a := TAU * i / 3.0 + 0.4
		var r := MeshInstance3D.new()
		var rock := SphereMesh.new()
		rock.radius = 0.5
		rock.height = 1.0
		rock.radial_segments = 6
		rock.rings = 3
		r.mesh = rock
		r.material_override = _mat(Color("98a499"))
		r.scale = Vector3(0.28, 0.18, 0.24)
		r.position = Vector3(sin(a) * 0.85, 0.06, cos(a) * 0.85)
		_visual.add_child(r)
	var gem := PrismMesh.new()
	gem.size = Vector3(0.42, 0.62, 0.42)
	_crystal = MeshInstance3D.new()
	_crystal.mesh = gem
	_crystal_mat = _mat(WILD_COLOR)
	_crystal_mat.emission_enabled = true
	_crystal.material_override = _crystal_mat
	_crystal.position.y = 1.05
	_visual.add_child(_crystal)
	var tip := MeshInstance3D.new()
	tip.mesh = gem
	tip.material_override = _crystal_mat
	tip.rotation.z = PI
	tip.position.y = -0.62
	_crystal.add_child(tip)
	_light = OmniLight3D.new()
	_light.omni_range = 3.5
	_light.shadow_enabled = false
	_light.position.y = 1.4
	_visual.add_child(_light)
