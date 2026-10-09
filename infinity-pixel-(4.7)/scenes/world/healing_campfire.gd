extends StaticBody3D

# Spec: docs/specs/013d-inventario-construcao-cura.md — RF-CON-004 / 005 (PROVISORIO)
#
# Fogueira de Cura. O Player SEGURA H (acao "heal_interact") a ate 2,5 m por 3 s
# para recuperar +25 HP (sem passar de max_hp). 2 cargas por ciclo (voltam a 2 no
# amanhecer, sem acumular) e 25 s de recarga apos cada cura. Cancela (sem cura
# parcial) se o Player sair do alcance, sofrer dano, morrer, atacar ou soltar H.
# Pode ser usada a noite (recuar para a base e o risco). Nao revive, nao cura
# refugio, dinos nem torres.
#
# Fisica/navegacao: solido pequeno (camada 4, construcoes) + NavigationObstacle3D
# so de avoidance — sem rebake. Fica na BuildZone, fora das rotas.

signal heal_completed(amount: float)
signal heal_cancelled(reason: String)

const Facetize := preload("res://scenes/visuals/facetize.gd")
const HEAL_AMOUNT := 25.0
const CHANNEL_TIME := 3.0
const RANGE := 2.5
const MAX_CHARGES := 2
const COOLDOWN := 25.0
const BUILDINGS := 1 << 3

@export var preview := false # fantasma do modo construcao: so visual

var charges := MAX_CHARGES
var cooldown_left := 0.0
var channel := 0.0 # s acumulados da canalizacao atual
var _charges_day := 0
var _player: Node3D
var _last_hp := 0.0
var _last_attacks := 0
var _flame: MeshInstance3D
var _light: OmniLight3D
var _time := 0.0
var _glow := 0.0 # Spec 014: 0 dia .. 1 noite (so a luz/chama; RANGE da cura nao muda)
var _flame_mat: StandardMaterial3D

func _ready() -> void:
	_build_visual()
	Facetize.apply(self) # polimento: primitivas lisas -> facetadas (mesmas medidas)
	if preview:
		set_physics_process(false)
		set_process(false)
		return
	add_to_group("built_structure")
	add_to_group("healing_campfire")
	add_to_group("night_glow") # Spec 014: DayNightVisual chama set_night_glow()
	collision_layer = BUILDINGS
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.7
	cylinder.height = 0.6
	shape.shape = cylinder
	shape.position.y = 0.3
	add_child(shape)
	var obstacle := NavigationObstacle3D.new()
	obstacle.radius = 0.9
	obstacle.height = 1.0
	obstacle.avoidance_enabled = true
	add_child(obstacle)
	_charges_day = DayNightManager.day_number

func _player_node() -> Node3D:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	return _player

func player_in_range() -> bool:
	var p := _player_node()
	if p == null:
		return false
	var d := p.global_position - global_position
	return Vector2(d.x, d.z).length() <= RANGE

## Motivo de recusa ("" = pode curar agora).
func block_reason() -> String:
	var p := _player_node()
	if p == null or p.get("is_dead") == true:
		return "Indisponível"
	if charges <= 0:
		return "Sem cargas até amanhecer"
	if cooldown_left > 0.0:
		return "Recarregando %d s" % ceili(cooldown_left)
	if p.current_hp >= p.max_hp:
		return "Vida cheia"
	return ""

func progress() -> float:
	return channel / CHANNEL_TIME

func _physics_process(delta: float) -> void:
	if not DayNightManager.can_play():
		_cancel("") # pausa/derrota zera sem aviso
		return
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	# RF-CON-005: cargas voltam a 2 no amanhecer (compara o dia; sem acumular).
	if DayNightManager.day_number != _charges_day:
		_charges_day = DayNightManager.day_number
		charges = MAX_CHARGES
	var p := _player_node()
	var held := Input.is_action_pressed("heal_interact")
	if channel > 0.0:
		if p == null or p.is_dead:
			_cancel("morreu")
		elif not player_in_range():
			_cancel("fora do alcance")
		elif p.current_hp < _last_hp:
			_cancel("sofreu dano")
		elif p.attack_count != _last_attacks:
			_cancel("atacou")
		elif _channel_busy(p):
			_cancel("ação incompatível")
		elif not held:
			_cancel("soltou H")
		else:
			channel += delta
			_last_hp = p.current_hp
			if channel >= CHANNEL_TIME:
				_complete(p)
		return
	if held and player_in_range() and block_reason() == "" and not _channel_busy(p):
		channel = delta # comeca a canalizar
		_last_hp = p.current_hp
		_last_attacks = p.attack_count

# Pausado, o _physics_process nem roda: sem isto a canalizacao continuaria de
# onde parou ao voltar com H ainda segurado (RF-CON-005: pausar cancela).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_cancel("")

# Check both at start and while channeling: these actions can begin after H.
func _channel_busy(p: Node3D) -> bool:
	var dom = p.get_node_or_null("DomesticationChannel")
	if dom != null and dom.get_progress() > 0.0:
		return true
	var placer := get_parent().get_parent().get_node_or_null("BuildPlacer")
	return placer != null and placer.is_placing()

func _complete(p: Node3D) -> void:
	channel = 0.0
	charges -= 1
	cooldown_left = COOLDOWN
	p.heal(HEAL_AMOUNT)
	print("[FOGUEIRA] cura +%.0f (cargas %d/%d, recarga %.0f s)" % [HEAL_AMOUNT, charges, MAX_CHARGES, COOLDOWN])
	heal_completed.emit(HEAL_AMOUNT)

func _cancel(reason: String) -> void:
	if channel <= 0.0:
		return
	channel = 0.0 # nunca cura parcialmente
	if reason != "":
		print("[FOGUEIRA] cura cancelada: %s" % reason)
		heal_cancelled.emit(reason)

func _process(delta: float) -> void:
	_time += delta
	_flame.scale = Vector3(1.0, 1.0 + 0.12 * sin(_time * 9.0) + 0.06 * sin(_time * 23.0), 1.0)
	_light.light_energy = lerpf(0.6, 2.2, _glow) + (0.12 + 0.2 * _glow) * sin(_time * 11.0)

# Spec 014 RF-CEU-008: discreta de dia, aconchegante a noite. So visual: o
# alcance da cura (RANGE) e independente do alcance da luz.
func set_night_glow(f: float) -> void:
	_glow = f
	_light.omni_range = lerpf(4.0, 6.5, f)
	_flame_mat.emission_energy_multiplier = lerpf(1.2, 2.6, f)

# --- visual low-poly: anel de pedras, lenha cruzada, chama e luz quente -------
func _mat(color: Color, glow := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.6
	return m

func _build_visual() -> void:
	var rock := SphereMesh.new()
	rock.radius = 0.5
	rock.height = 1.0
	rock.radial_segments = 6
	rock.rings = 3
	for i in 8:
		var a := TAU * i / 8.0
		var r := MeshInstance3D.new()
		r.mesh = rock
		r.material_override = _mat(Color("8d9a8f"))
		r.scale = Vector3(0.36, 0.26, 0.3)
		r.position = Vector3(sin(a) * 0.62, 0.1, cos(a) * 0.62)
		add_child(r)
	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius = 0.08
	log_mesh.bottom_radius = 0.09
	log_mesh.height = 0.9
	log_mesh.radial_segments = 6
	for i in 3:
		var l := MeshInstance3D.new()
		l.mesh = log_mesh
		l.material_override = _mat(Color("6a4f37"))
		l.rotation = Vector3(PI / 2.0 - 0.35, TAU * i / 3.0, 0)
		l.position.y = 0.2
		add_child(l)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.28
	cone.height = 0.7
	cone.radial_segments = 6
	_flame = MeshInstance3D.new()
	_flame.mesh = cone
	_flame_mat = _mat(Color("f2a33c"), true)
	_flame.material_override = _flame_mat
	_flame.position.y = 0.55
	add_child(_flame)
	var inner := MeshInstance3D.new()
	var small := cone.duplicate() as CylinderMesh
	small.bottom_radius = 0.15
	small.height = 0.45
	inner.mesh = small
	inner.material_override = _mat(Color("ffe08a"), true)
	inner.position.y = 0.12
	_flame.add_child(inner)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.68, 0.35)
	_light.omni_range = 4.0 # dia; set_night_glow() abre ate 6,5 m a noite
	_light.position.y = 1.0
	add_child(_light)
	if preview:
		_light.visible = false
