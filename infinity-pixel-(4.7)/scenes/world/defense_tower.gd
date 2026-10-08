extends StaticBody3D

# Spec: docs/specs/013b-economia-defesas-fixas.md
# RF-ECO-004 / 005 — Torre de Defesa, ataque automatico e niveis (PROVISORIO)
#
# Corpo solido pequeno (camada 4, Spec 009) com obstaculo de avoidance: o
# Player e as criaturas contornam a torre. Sem HP (inimigos nao a atacam).
# Alvo: so inimigos da onda vivos (grupos "wave_enemy" + "wild_dino"), nunca
# Player, aliados, domesticados ou o refugio. Dano pelo contrato take_damage.

## Valores por nivel: custo para chegar ao nivel, dano, intervalo (s), alcance (m).
const LEVELS := [
	{"cost": 30, "damage": 10.0, "interval": 1.0, "range": 8.0},
	{"cost": 30, "damage": 15.0, "interval": 0.85, "range": 9.0},
	{"cost": 45, "damage": 20.0, "interval": 0.70, "range": 10.0},
]
const RETARGET_INTERVAL := 0.15 # busca por grupos, como a IA (Spec 010)
const BOLT_TIME := 0.18 # s do "dardo" ate o alvo
const RangeRing := preload("res://scenes/world/range_ring.gd")
# Spec 013C (RF-CMB-007): opacidade do anel de alcance.
const RING_FOCUS := 0.8 # Player interagindo com esta torre
const RING_NEAR := 0.45 # Player perto do alcance
const RING_FAR := 0.12 # longe: bem discreto

const STONE := Color("7c8980")
const WOOD := Color("6a4f37")
const CRYSTAL := Color("7fd8b0")

var level := 1
var target: Node3D
var _cooldown := 0.0
var _retarget := 0.0
var _crystal: MeshInstance3D
var _crown: Node3D
var _ring: MeshInstance3D
var range_ring: MeshInstance3D # raio = stats().range, o mesmo valor da busca de alvo
var _glow := 0.0 # Spec 014: 0 dia .. 1 noite (so apresentacao)
var _glow_mats: Array[StandardMaterial3D] = []

func _ready() -> void:
	add_to_group("defense_tower")
	add_to_group("night_glow") # Spec 014: DayNightVisual chama set_night_glow()
	collision_layer = 1 << 3 # Spec 009: base/construcoes
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.8
	cylinder.height = 2.4
	shape.shape = cylinder
	shape.position.y = 1.2
	add_child(shape)
	var obstacle := NavigationObstacle3D.new()
	obstacle.radius = 0.8
	obstacle.height = 2.4
	obstacle.avoidance_enabled = true
	add_child(obstacle)
	_build_visual()
	range_ring = RangeRing.new()
	range_ring.name = "RangeRing"
	add_child(range_ring)
	_apply_level_visual()
	range_ring.set_radius(stats().range) # RF-CMB-007: mesmo valor da logica

func stats() -> Dictionary:
	return LEVELS[level - 1]

func is_max_level() -> bool:
	return level >= LEVELS.size()

func upgrade_cost() -> int:
	return -1 if is_max_level() else LEVELS[level].cost

func upgrade() -> void:
	if is_max_level():
		return
	level += 1
	_apply_level_visual()
	range_ring.set_radius(stats().range) # RF-CMB-007: mesmo valor da logica
	print("[DEFESA] Torre melhorada para o nivel %d" % level)

static func is_valid_target(body) -> bool:
	return is_instance_valid(body) and body.is_inside_tree() and body.is_in_group("wave_enemy") \
		and body.is_in_group("wild_dino") and not body.is_in_group("domesticated") \
		and body.get("hp") != null and body.hp > 0.0

func _in_range(body: Node3D) -> bool:
	var d := body.global_position - global_position
	return Vector2(d.x, d.z).length() <= stats().range

# RF-CMB-007: anel discreto de longe, visivel perto, forte ao interagir.
func ring_alpha_target() -> float:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return RING_FAR
	var slots := get_parent().get_parent() if get_parent() != null else null
	if slots != null and slots.has_method("nearest_slot") and slots.nearest_slot() == get_parent():
		return RING_FOCUS
	var d := player.global_position - global_position
	return RING_NEAR if Vector2(d.x, d.z).length() <= stats().range + 3.0 else RING_FAR

func _process(delta: float) -> void:
	range_ring.position.y = RangeRing.LIFT - position.y # rente ao chao, nao a base
	range_ring.set_strength(ring_alpha_target(), delta)

func _physics_process(delta: float) -> void:
	if not DayNightManager.can_play():
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_retarget -= delta
	if not is_valid_target(target) or not _in_range(target):
		target = null
	if target == null and _retarget <= 0.0:
		_retarget = RETARGET_INTERVAL
		target = _find_target()
	if target != null and _cooldown <= 0.0:
		_cooldown = stats().interval
		_fire(target)

func _find_target() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for body in get_tree().get_nodes_in_group("wave_enemy"):
		if is_valid_target(body) and _in_range(body):
			var d: float = body.global_position.distance_squared_to(global_position)
			if d < best_d:
				best_d = d
				best = body
	return best

# Feedback: um dardo de cristal voa ate o alvo; o dano entra na chegada, se o
# alvo ainda for valido (sem fisica balistica, sem colisao).
func _fire(foe: Node3D) -> void:
	var damage: float = stats().damage
	var bolt := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	bolt.mesh = mesh
	var bolt_mat := _material(Color("c9fbe6"), true)
	bolt_mat.emission_energy_multiplier = _glow_energy()
	bolt.material_override = bolt_mat
	get_parent().add_child(bolt)
	bolt.global_position = _crystal.global_position
	var aim := foe.global_position + Vector3(0, 0.9, 0)
	var t := bolt.create_tween()
	t.tween_property(bolt, "global_position", aim, BOLT_TIME)
	t.tween_callback(func():
		if is_valid_target(foe):
			foe.take_damage(damage)
		bolt.queue_free())
	var pulse := _crystal.create_tween()
	_crystal.scale *= 1.25
	pulse.tween_property(_crystal, "scale", _crystal_scale(), 0.2)

# ---------------------------------------------------------------------------
# Visual low-poly: base de pedra, postes de madeira, cristal no topo.
# ---------------------------------------------------------------------------

func _material(color: Color, glow := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.8
	return m

func _part(mesh: Mesh, pos: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _cylinder(top: float, bottom: float, height: float, sides := 7) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = sides
	c.rings = 1
	return c

func _build_visual() -> void:
	var stone := _material(STONE)
	var wood := _material(WOOD)
	_part(_cylinder(0.82, 0.95, 0.55), Vector3(0, 0.27, 0), stone)
	_part(_cylinder(0.64, 0.74, 0.5), Vector3(0, 0.79, 0), stone)
	for i in 3:
		var a := TAU * i / 3.0
		var post := _part(_cylinder(0.1, 0.13, 1.45, 5), Vector3(sin(a) * 0.46, 1.72, cos(a) * 0.46), wood)
		post.rotation.z = sin(a) * 0.12
		post.rotation.x = -cos(a) * 0.12
	_crown = Node3D.new()
	_crown.position.y = 2.5
	add_child(_crown)
	_part(_cylinder(0.58, 0.42, 0.2), Vector3.ZERO, wood, _crown)
	_ring = _part(_cylinder(0.66, 0.66, 0.1, 8), Vector3(0, 0.14, 0), _material(Color("e7ae58")), _crown)
	var gem := PrismMesh.new() # cristal facetado (duas piramides)
	gem.size = Vector3(0.55, 0.8, 0.55)
	_crystal = _part(gem, Vector3(0, 0.62, 0), _material(CRYSTAL, true), _crown)
	var tip := _part(gem, Vector3(0, -0.8, 0), _material(CRYSTAL.darkened(0.2), true), _crystal)
	tip.rotation.z = PI
	_glow_mats.assign([_crystal.material_override, tip.material_override])

# Spec 014 RF-CEU-009: a noite o cristal e o disparo brilham mais. So visual:
# dano, alcance, cadencia e alvo nao leem isto.
func set_night_glow(f: float) -> void:
	_glow = f
	for m in _glow_mats:
		m.emission_energy_multiplier = _glow_energy()

func _glow_energy() -> float:
	return 0.8 + 1.4 * _glow

func _crystal_scale() -> Vector3:
	return Vector3.ONE * (1.0 + 0.3 * (level - 1))

# Nivel visivel: cristal maior, anel dourado (L2+) e torre mais alta (L3).
func _apply_level_visual() -> void:
	_crystal.scale = _crystal_scale()
	_ring.visible = level >= 2
	_crown.position.y = 2.5 + (0.4 if level >= 3 else 0.0)
