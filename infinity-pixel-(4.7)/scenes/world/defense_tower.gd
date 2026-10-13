extends StaticBody3D

# Spec: docs/specs/013b-economia-defesas-fixas.md
# RF-ECO-004 / 005 — Torre de Defesa, ataque automatico e niveis (PROVISORIO)
#
# Corpo solido pequeno (camada 4, Spec 009) com obstaculo de avoidance: o
# Player e as criaturas contornam a torre. Sem HP (inimigos nao a atacam).
# Alvo: so inimigos da onda vivos (grupos "wave_enemy" + "wild_dino"), nunca
# Player, aliados, domesticados ou o refugio. Dano pelo contrato take_damage.
#
# Design Overhaul 5.0: o visual vem do TowerForge (tres niveis da mesma familia
# arquitetonica) e anima so a apresentacao — mecanismo girando para o alvo,
# cristal pulsando e carregando antes do disparo, recuo no tiro e subida de
# nivel. Nada disso le ou muda dano, alcance, cadencia, alvo ou colisao.

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
const CombatFX := preload("res://scenes/visuals/combat_fx.gd")
const TowerForge := preload("res://scenes/visuals/tower_forge.gd")
# Spec 013C (RF-CMB-007): opacidade do anel de alcance.
const RING_FOCUS := 0.7 # Player interagindo com esta torre (3.0: era 0,8)
const RING_NEAR := 0.24 # Player perto do alcance (3.0: era 0,45; linhas dominavam a tela)
const RING_FAR := 0.0 # longe: escondido (3.0: era 0,12)

const CRYSTAL := Color("7fd8b0")
# 5.0: energia da emissao (dia -> noite). O cristal usa jade profundo: a noite
# brilha sem estourar em branco; as runas quase apagam de dia.
const CRYSTAL_ENERGY := Vector2(0.45, 1.65)
const RUNE_ENERGY := Vector2(0.12, 0.85)
const CHARGE_TIME := 0.22 # s antes do disparo em que o cristal "carrega" (so visual)
const AIM_SPEED := 9.0 # resposta do giro do mecanismo para o alvo (1/s)

var level := 1
var target: Node3D
var _cooldown := 0.0
var _retarget := 0.0
var _visual: Node3D # raiz do modelo do nivel atual (refeita a cada melhoria)
var _head: Node3D # mecanismo que gira (yaw) para o alvo
var _rig: Node3D # recua no disparo
var _crystal: MeshInstance3D # origem visual da lasca
var _orbit: Node3D # L3: lascas orbitando o cristal
var range_ring: MeshInstance3D # raio = stats().range, o mesmo valor da busca de alvo
var _glow := 0.0 # Spec 014: 0 dia .. 1 noite (so apresentacao)
var _glow_mats: Array[StandardMaterial3D] = [] # [cristal, runas]
var _time := 0.0
var _flash := 0.0 # 1 no disparo, decai (escala/brilho do cristal)
var _recoil := 0.0
var _idle_yaw := 0.0

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
	var crystal_mat := TowerForge.glow_material()
	var rune_mat := TowerForge.glow_material()
	rune_mat.emission = TowerForge.RUNE_EMISSION
	_glow_mats.assign([crystal_mat, rune_mat])
	# O mecanismo comeca apontando para longe do Refugio (para fora do vale).
	_idle_yaw = atan2(global_position.x, global_position.z + 14.0) if is_inside_tree() else 0.0
	range_ring = RangeRing.new()
	range_ring.name = "RangeRing"
	add_child(range_ring)
	_apply_level_visual()
	set_night_glow(_glow)
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
	# 5.0: o novo modelo "cresce" do plinto, lascas jade sobem e um anel ambar
	# marca a melhoria (so apresentacao, ~0,5 s).
	if is_inside_tree():
		CombatFX.ring(self, global_position, Color("e9a23b"), 2.4, 0.6) # melhoria: anel ambar
		CombatFX.burst(self, _crystal.global_position, CRYSTAL, 12)
		CombatFX.pillar(self, global_position, CRYSTAL, 4.5, 0.7)
	_visual.scale = Vector3(1.0, 0.82, 1.0)
	_visual.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(_visual, "scale", Vector3.ONE, 0.45)

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
	_animate(delta)

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
# 5.0: sai do cristal do mecanismo (que ja aponta para o alvo), com faisca na
# boca, recuo e clarao do cristal no MESMO quadro do disparo real.
func _fire(foe: Node3D) -> void:
	get_tree().call_group("audio_director", "play", "tower_shot") # 4.0 (com intervalo minimo)
	var damage: float = stats().damage
	var bolt := MeshInstance3D.new()
	bolt.mesh = CombatFX.shard_mesh()
	var bolt_mat := _material(Color("8fe8c4"), true)
	bolt_mat.emission_energy_multiplier = 0.5 + 0.8 * _glow
	bolt.material_override = bolt_mat
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.scale = Vector3(1.6, 3.2, 1.6)
	get_parent().add_child(bolt)
	_aim_now(foe) # o disparo sai na direcao certa mesmo se o alvo acabou de entrar
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
	CombatFX.hit_spark(self, start, CRYSTAL, 3) # faisca na boca do mecanismo
	_flash = 1.0
	_recoil = 1.0

func _material(color: Color, glow := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.8
	return m

# ---------------------------------------------------------------------------
# Visual (Design Overhaul 5.0): modelo do nivel + animacao de apresentacao.
# ---------------------------------------------------------------------------

## Monta o modelo do nivel atual (malhas compartilhadas do TowerForge; so os
## dois materiais de brilho sao desta torre). Chamado no _ready e a cada melhoria.
func _apply_level_visual() -> void:
	var keep_yaw := _head.rotation.y if is_instance_valid(_head) else _idle_yaw
	if is_instance_valid(_visual):
		remove_child(_visual)
		_visual.queue_free()
	var p := TowerForge.parts(level)
	var toon := TowerForge.material()
	_visual = Node3D.new()
	_visual.name = "TowerVisual"
	add_child(_visual)
	_visual.add_child(_mesh("Body", p.body, toon, true))
	_visual.add_child(_mesh("Runes", p.glow, _glow_mats[1], false))
	_head = Node3D.new()
	_head.name = "Head"
	_head.position.y = p.head_y
	_head.rotation.y = keep_yaw
	_visual.add_child(_head)
	_rig = Node3D.new()
	_rig.name = "Rig"
	_head.add_child(_rig)
	_rig.add_child(_mesh("Mechanism", p.head, toon, true))
	if p.head_glow != null:
		_rig.add_child(_mesh("MechanismRunes", p.head_glow, _glow_mats[1], false))
	_crystal = _mesh("Crystal", p.crystal, _glow_mats[0], false)
	_crystal.position = p.crystal_pos
	_rig.add_child(_crystal)
	_orbit = null
	if p.orbit:
		_orbit = Node3D.new()
		_orbit.name = "Orbit"
		_crystal.add_child(_orbit)
		for i in 3:
			var a := TAU * i / 3.0
			var shard := _mesh("Shard%d" % i, p.orbit_mesh, _glow_mats[0], false)
			shard.position = Vector3(sin(a) * 0.36, 0.12 * sin(a * 2.0), cos(a) * 0.36)
			_orbit.add_child(shard)
	_crystal.scale = _crystal_scale()

func _mesh(label: String, mesh: Mesh, mat: Material, shadow: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = label
	mi.mesh = mesh
	mi.material_override = mat
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Gira o mecanismo direto para o alvo (no instante do disparo real).
func _aim_now(foe: Node3D) -> void:
	var local := _visual.to_local(foe.global_position)
	_head.rotation.y = atan2(local.x, local.z)

## So apresentacao: giro para o alvo (ou varredura lenta sem alvo), pulso do
## cristal, carga antes do disparo (le o _cooldown, nao o altera), clarao e recuo.
func _animate(delta: float) -> void:
	_time += delta
	var foe: Node3D = target if is_valid_target(target) else null
	var desired := _idle_yaw + 0.55 * sin(_time * 0.35 + get_instance_id() % 7)
	var speed := 1.6
	if foe != null:
		var local := _visual.to_local(foe.global_position)
		desired = atan2(local.x, local.z)
		speed = AIM_SPEED
	_head.rotation.y = lerp_angle(_head.rotation.y, desired, 1.0 - exp(-speed * delta))
	var charge := 0.0
	if foe != null and _cooldown < CHARGE_TIME and DayNightManager.can_play():
		charge = 1.0 - _cooldown / CHARGE_TIME
	_flash = move_toward(_flash, 0.0, delta / 0.2)
	_recoil = move_toward(_recoil, 0.0, delta / 0.18)
	var kick := _recoil * _recoil
	_rig.position.z = -0.09 * kick
	_rig.rotation.x = -0.07 * kick
	_crystal.scale = _crystal_scale() * (1.0 + 0.25 * _flash + 0.08 * charge + 0.025 * sin(_time * 2.4))
	_crystal.rotation.y += delta * (0.5 + 2.5 * charge)
	if _orbit != null:
		_orbit.rotation.y += delta * (1.1 + 2.0 * charge)
	var base := lerpf(CRYSTAL_ENERGY.x, CRYSTAL_ENERGY.y, _glow)
	_glow_mats[0].emission_energy_multiplier = base * (1.0 + 0.05 * sin(_time * 2.4)) + 0.45 * charge + 0.5 * _flash

# Spec 014 RF-CEU-009: a noite o cristal, as runas e o disparo brilham mais.
# So visual: dano, alcance, cadencia e alvo nao leem isto.
func set_night_glow(f: float) -> void:
	_glow = f
	if _glow_mats.size() < 2:
		return
	_glow_mats[0].emission_energy_multiplier = lerpf(CRYSTAL_ENERGY.x, CRYSTAL_ENERGY.y, f)
	_glow_mats[1].emission_energy_multiplier = lerpf(RUNE_ENERGY.x, RUNE_ENERGY.y, f)

## Cada nivel ja tem o proprio cristal (maior a cada nivel); a escala base e 1.
func _crystal_scale() -> Vector3:
	return Vector3.ONE
