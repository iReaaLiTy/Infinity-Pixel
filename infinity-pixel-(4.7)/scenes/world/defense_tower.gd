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
const Palette := preload("res://scenes/visuals/palette.gd")
const Facets := preload("res://scenes/visuals/facets.gd")
const CombatFX := preload("res://scenes/visuals/combat_fx.gd")
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
	_update_target_mark(delta)

# Spec 019: anel jade fino sob o inimigo que esta torre mira (so leitura; o alvo
# continua sendo escolhido por _find_target). Fica no mundo, nao no inimigo.
var _target_mark: MeshInstance3D
var _mark_time := 0.0
func _update_target_mark(delta: float) -> void:
	var foe: Node3D = target if is_valid_target(target) else null
	if foe == null:
		if _target_mark != null:
			_target_mark.visible = false
		return
	if _target_mark == null:
		_target_mark = MeshInstance3D.new()
		_target_mark.name = "TargetMark"
		_target_mark.mesh = CombatFX.ring_mesh()
		_target_mark.material_override = CombatFX.fx_material(CRYSTAL, 0.75)
		_target_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_target_mark.top_level = true
		add_child(_target_mark)
	_mark_time += delta
	_target_mark.visible = true
	_target_mark.global_position = Vector3(foe.global_position.x, 0.07, foe.global_position.z)
	_target_mark.scale = Vector3.ONE * (0.95 + 0.08 * sin(_mark_time * 8.0))

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

# Feedback: uma lasca de cristal voa ate o alvo; o dano entra na chegada, se o
# alvo ainda for valido (sem fisica balistica, sem colisao).
# Spec 019: lasca jade facetada apontada para o alvo, com 2 ecos de rastro e
# faisca no impacto. O tempo de voo (BOLT_TIME) e o instante do dano nao mudam.
func _fire(foe: Node3D) -> void:
	var damage: float = stats().damage
	var bolt := MeshInstance3D.new()
	bolt.mesh = CombatFX.shard_mesh()
	var bolt_mat := _material(Color("c9fbe6"), true)
	bolt_mat.emission_energy_multiplier = _glow_energy()
	bolt.material_override = bolt_mat
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.scale = Vector3(1.6, 3.2, 1.6)
	get_parent().add_child(bolt)
	var start := _crystal.global_position
	bolt.global_position = start
	var aim := foe.global_position + Vector3(0, 0.9, 0)
	if not start.is_equal_approx(aim):
		bolt.global_basis = Basis(Quaternion(Vector3.UP, (aim - start).normalized())).scaled(bolt.scale)
	var t := bolt.create_tween()
	t.tween_property(bolt, "global_position", aim, BOLT_TIME)
	t.tween_callback(func():
		if is_valid_target(foe):
			foe.take_damage(damage)
			CombatFX.hit_spark(bolt, aim, CRYSTAL, 5)
		bolt.queue_free())
	for k in 2: # ecos do rastro: seguem a lasca com atraso e somem
		var echo := MeshInstance3D.new()
		echo.mesh = bolt.mesh
		echo.material_override = CombatFX.fx_material(CRYSTAL, 0.45 - 0.15 * k)
		echo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_parent().add_child(echo)
		echo.global_transform = bolt.global_transform
		echo.scale *= 0.8 - 0.2 * k
		var te := echo.create_tween()
		te.tween_interval(0.03 * (k + 1))
		te.tween_property(echo, "global_position", aim, BOLT_TIME)
		te.tween_callback(echo.queue_free)
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

# Spec 017A: torre facetada (mesma silhueta, alturas e partes de antes): base de
# pedra em 2 niveis, 3 postes de madeira, coroa, anel ambar (L2+) e cristal jade.
# _crystal, _ring, _crown e _glow_mats continuam com o mesmo papel.
func _build_visual() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4013
	var tones := [Palette.STONE_LIGHT, Palette.STONE, Palette.STONE_DARK]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint_stone := func(c: Vector3, n: Vector3) -> Color:
		if c.y > 0.5 and c.y < 0.62 and n.y < 0.7:
			return Facets.facet_shade(Palette.JADE_DARK, n) # friso jade
		return Facets.by_height(tones, n, c.y, 0.0, 1.05, c.x + c.z)
	Facets.loft(st, [
		Facets.ring(8, 0.95, -0.02, rng, 0.03, PI / 8.0),
		Facets.ring(8, 0.88, 0.5, rng, 0.03, PI / 8.0),
		Facets.ring(8, 0.8, 0.6, rng, 0.02, PI / 8.0),
		Facets.ring(8, 0.72, 0.62, rng, 0.02, 0.1),
		Facets.ring(8, 0.64, 1.0, rng, 0.02, 0.1),
		Facets.ring(8, 0.7, 1.06, rng, 0.02, 0.1),
	], true, null, paint_stone)
	var paint_wood := func(c: Vector3, n: Vector3) -> Color:
		return Facets.by_height([Palette.WOOD, Palette.WOOD, Palette.WOOD_DARK], n, c.y, 0.9, 2.5, c.x)
	for i in 3:
		var a := TAU * i / 3.0
		var foot := Vector3(sin(a) * 0.5, 1.0, cos(a) * 0.5)
		var head := Vector3(sin(a) * 0.36, 2.45, cos(a) * 0.36)
		var basis := Basis(Quaternion(Vector3.UP, (head - foot).normalized()))
		Facets.loft(st, [Facets.ring(5, 0.12, 0.0, rng, 0.05, a, 0.0, Transform3D(basis, foot)),
			Facets.ring(5, 0.1, (head - foot).length(), rng, 0.05, a, 0.0, Transform3D(basis, foot))], true, null, paint_wood)
	var body := MeshInstance3D.new()
	body.mesh = st.commit()
	body.material_override = Palette.toon(0.3, 0.12)
	add_child(body)
	_crown = Node3D.new()
	_crown.position.y = 2.5
	add_child(_crown)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	Facets.loft(st, [Facets.ring(7, 0.44, -0.1, rng, 0.03), Facets.ring(7, 0.6, 0.08, rng, 0.03), Facets.ring(7, 0.56, 0.12, rng, 0.02)], true, true, paint_wood)
	_part(st.commit(), Vector3.ZERO, Palette.toon(0.3, 0.1), _crown)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint_gold := func(_c: Vector3, n: Vector3) -> Color:
		return Facets.facet_shade(Palette.AMBER, n)
	Facets.loft(st, [Facets.ring(8, 0.68, -0.05, rng, 0.0), Facets.ring(8, 0.66, 0.05, rng, 0.0)], true, true, paint_gold)
	_ring = _part(st.commit(), Vector3(0, 0.14, 0), Palette.toon(0.3, 0.2), _crown)
	# Cristal jade facetado (bipiramide), centrado na origem para o pulso.
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint_gem := func(c: Vector3, n: Vector3) -> Color:
		var col := Palette.JADE_DARK.lerp(Palette.JADE_LIGHT, clampf((c.y + 0.45) / 0.95, 0.0, 1.0))
		return col.lightened(0.1) if fposmod(atan2(n.z, n.x) / TAU * 6.0, 2.0) < 1.0 else col.darkened(0.08)
	Facets.loft(st, [Facets.ring(6, 0.27, -0.05, rng, 0.04), Facets.ring(6, 0.25, 0.12, rng, 0.04, 0.1)],
		Vector3(0.02, 0.55, 0), Vector3(0, -0.45, 0), paint_gem)
	var glow := Palette.toon_glow(CRYSTAL, 0.18, 0.4)
	_crystal = _part(st.commit(), Vector3(0, 0.62, 0), glow, _crown)
	_glow_mats.assign([glow])

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
