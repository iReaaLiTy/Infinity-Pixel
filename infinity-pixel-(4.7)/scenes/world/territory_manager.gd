extends Node3D

# Spec: docs/specs/015-territorios-controlados.md — RF-TER-001 a 012 (PROVISORIO)
#
# Fonte unica do progresso territorial. Vive na cena do mundo: cada partida nova
# (JOGAR/Reiniciar) instancia um mundo novo e volta ao estado inicial.
#
# Territorios (sobre o mapa da Spec 012, sem aumentar o mapa):
# - REFUGIO (centro, tudo ao sul da bifurcacao): CONTROLLED desde o inicio.
#   Construcao de base continua so na BuildZone original (013D intacta).
# - FLORESTA OESTE (bosque) e REGIAO ROCHOSA (leste): comecam WILD.
# - O corredor da ruina/arco ao norte da bifurcacao nao e territorio: area
#   selvagem futura, nunca conquistavel nesta Spec.
#
# Fluxo: WILD -> (guardiao derrotado OU domesticado) -> READY_TO_CLAIM ->
# (segurar E 2 s no marco, de dia) -> CONTROLLED. Nada volta atras.
#
# Guardioes: sao os proprios encontros diurnos da 013C (EncounterSpawner), um
# por regiao. Enquanto o territorio esta WILD, o encontro daquela regiao e
# marcado como guardiao. A neutralizacao acontece UMA vez; os encontros que o
# EncounterSpawner recria nos amanheceres seguintes sao selvagens comuns e nao
# mexem mais no territorio.

signal state_changed(id: StringName, state: int)
signal claimed(id: StringName, display_name: String)
signal region_entered(id: StringName, display_name: String, state: int)
signal claim_cancelled(reason: String)

enum { WILD, READY_TO_CLAIM, CONTROLLED }

const CLAIM_TIME := 2.0 # s segurando E no marco
const CLAIM_RANGE := 2.2 # m do marco (plano XZ)
const REGION_CHECK_INTERVAL := 0.25 # s entre checagens de "entrou em outra regiao"
const BORDER_ALPHA := 0.10 # limite discreto em repouso
const BORDER_FLASH := 0.42 # ao entrar na regiao / durante a conquista
const ROUTE_HALF_WIDTH := 2.0 # igual ao BuildPlacer

# Retangulos em XZ: Rect2(x, z, largura, profundidade). O vale vai de x -24 a 24
# e de z -24 a 28 (Spec 012). Nenhuma rota noturna entra no Oeste/Leste (as
# trilhas ficam em z <= 2 e a estrada da ruina em x = 0).
const TERRITORIES := [
	{"id": &"center", "name": "REFÚGIO", "rect": Rect2(-24, -24, 48, 29.5), "start": CONTROLLED, "conquerable": false, "build_area": false},
	{"id": &"west", "name": "FLORESTA OESTE", "rect": Rect2(-24, 5.5, 20, 22.5), "start": WILD, "conquerable": true, "build_area": true, "marker": Vector3(-14, 0, 13)},
	{"id": &"east", "name": "REGIÃO ROCHOSA", "rect": Rect2(4, 5.5, 20, 22.5), "start": WILD, "conquerable": true, "build_area": true, "marker": Vector3(13, 0, 16)},
]

const Marker := preload("res://scenes/world/territory_marker.gd")

@export var player_path: NodePath = ^"../Player"
@export var spawner_path: NodePath = ^"../EncounterSpawner"
@export var placer_path: NodePath = ^"../BuildPlacer"
@export var regions_path: NodePath = ^"../WorldRegions"

var states := {} # id -> WILD/READY_TO_CLAIM/CONTROLLED
var markers := {} # id -> TerritoryMarker
var guardians := {} # id -> WildDino enquanto for a ameaca do territorio
var neutralized := {} # id -> true (a neutralizacao acontece uma vez)
var claiming := &"" # territorio em conquista agora ("" = nenhum)
var claim_time := 0.0
var current_region := &""
var _claim_attacks := 0
var _announced := {} # id -> ultimo estado anunciado ao entrar
var _region_wait := 0.0
var _borders := {} # id -> StandardMaterial3D do contorno
var _border_flash := {} # id -> Tween

@onready var player: Node3D = get_node(player_path)
@onready var spawner: Node = get_node_or_null(spawner_path)
@onready var placer: Node = get_node_or_null(placer_path)

func _ready() -> void:
	add_to_group("territory_manager")
	for t in TERRITORIES:
		states[t.id] = t.start
		if t.conquerable:
			var m := Marker.new()
			m.name = "Marker_%s" % t.id
			add_child(m)
			m.global_position = t.marker
			markers[t.id] = m
			_build_border(t)
	_announced[&"center"] = CONTROLLED
	# Metodos (nao lambdas): desconectam sozinhos quando o mundo e liberado.
	DayNightManager.night_started.connect(_on_night_started)
	if spawner != null:
		spawner.encounter_spawned.connect(_on_encounter_spawned)
		for dino in spawner.encounters:
			if is_instance_valid(dino):
				_on_encounter_spawned(dino)
	_refresh()

# --- consultas ----------------------------------------------------------------

static func info(id: StringName) -> Dictionary:
	for t in TERRITORIES:
		if t.id == id:
			return t
	return {}

func state_of(id: StringName) -> int:
	return states.get(id, WILD)

func is_controlled(id: StringName) -> bool:
	return state_of(id) == CONTROLLED

func total_count() -> int:
	return TERRITORIES.size()

func controlled_count() -> int:
	var n := 0
	for id in states:
		if states[id] == CONTROLLED:
			n += 1
	return n

## Territorio que contem o ponto ("" = corredor da ruina, fora dos 3).
static func territory_at(pos: Vector3) -> StringName:
	var p := Vector2(pos.x, pos.z)
	for t in TERRITORIES:
		if t.rect.has_point(p):
			return t.id
	return &""

## RF-TER-010: a regiao PODE receber construcao de base? (as validacoes de
## solidos, estruturas, refugio, navmesh e rotas continuam no BuildPlacer).
func is_build_area(pos: Vector3) -> bool:
	var id := territory_at(pos)
	return id != &"" and info(id).build_area and is_controlled(id)

func claim_progress() -> float:
	return claim_time / CLAIM_TIME if claiming != &"" else 0.0

## Marco conquistavel (READY) ao alcance do Player, ou "".
func ready_marker_in_range() -> StringName:
	for id in markers:
		if states[id] == READY_TO_CLAIM and _flat(player.global_position, markers[id].global_position) <= CLAIM_RANGE:
			return id
	return &""

## Marco mais proximo a ate `dist` m (qualquer estado), para a dica da HUD.
func marker_near(dist: float) -> StringName:
	for id in markers:
		if _flat(player.global_position, markers[id].global_position) <= dist:
			return id
	return &""

# --- guardioes (RF-TER-003) -----------------------------------------------------

func _on_encounter_spawned(dino: Node3D) -> void:
	var id := territory_at(dino.global_position if dino.is_inside_tree() else dino.position)
	if id == &"" or not info(id).conquerable:
		return
	if states[id] != WILD or neutralized.has(id) or is_instance_valid(guardians.get(id)):
		return # territorio ja liberado: o encontro do amanhecer e um selvagem comum
	guardians[id] = dino
	dino.set_guardian(info(id).name)
	dino.died.connect(_on_guardian_neutralized.bind(id, "derrotado"), CONNECT_ONE_SHOT)
	dino.domesticated.connect(_on_guardian_neutralized.bind(id, "domesticado"), CONNECT_ONE_SHOT)
	print("[TERRITORIO] %s: guardiao %s" % [info(id).name, dino.name])

func _on_guardian_neutralized(dino: Node3D, id: StringName, how: String) -> void:
	if neutralized.has(id):
		return # uma vez so (ex.: aliado que morre depois)
	neutralized[id] = true
	# Desliga o outro sinal: a morte posterior do aliado nao faz nada.
	for sig in [dino.died, dino.domesticated]:
		for c in sig.get_connections():
			if c.callable.get_object() == self:
				sig.disconnect(c.callable)
	guardians.erase(id)
	if is_instance_valid(dino):
		dino.set_guardian("")
	print("[TERRITORIO] %s: guardiao %s -> PRONTO PARA SER RECUPERADO" % [info(id).name, how])
	_set_state(id, READY_TO_CLAIM)

# --- conquista: segurar E no marco (RF-TER-005 / 006) -------------------------

func _physics_process(delta: float) -> void:
	var dom = player.get_node("DomesticationChannel")
	if claiming != &"":
		var reason := _claim_block(dom)
		if reason != "":
			cancel_claim(reason)
			return
		claim_time += delta
		if claim_time >= CLAIM_TIME:
			_complete_claim()
		return
	if not dom.is_e_held() or dom.e_hold_owner != "":
		return # sem E, ou esta segurada ja pertence a outra interacao
	if not DayNightManager.can_play() or not DayNightManager.is_day() or player.is_dead:
		return
	var id := ready_marker_in_range()
	if id == &"":
		return
	# RF-TER-006: alvo domesticavel valido ao alcance tem prioridade sobre o marco.
	if dom.find_eligible_target() != null or (placer != null and placer.is_placing()) or _healing():
		return
	claiming = id
	claim_time = delta
	_claim_attacks = player.attack_count
	dom.e_hold_owner = "territory" # esta segurada de E e da conquista ate soltar
	_flash_border(id, true)
	print("[TERRITORIO] %s: recuperando..." % info(id).name)

func _claim_block(dom) -> String:
	if not DayNightManager.can_play():
		return "pausa"
	if player.is_dead:
		return "morreu"
	if not DayNightManager.is_day():
		return "anoiteceu"
	if not dom.is_e_held():
		return "soltou E"
	if _flat(player.global_position, markers[claiming].global_position) > CLAIM_RANGE:
		return "fora do alcance"
	if player.attack_count != _claim_attacks:
		return "atacou"
	if (placer != null and placer.is_placing()) or dom.get_progress() > 0.0 or _healing():
		return "ação incompatível"
	return ""

func _healing() -> bool:
	for fire in get_tree().get_nodes_in_group("healing_campfire"):
		if fire.progress() > 0.0:
			return true
	return false

func cancel_claim(reason: String) -> void:
	if claiming == &"":
		return
	var id := claiming
	claiming = &""
	claim_time = 0.0 # sem progresso parcial salvo
	_flash_border(id, false)
	print("[TERRITORIO] recuperacao cancelada: %s" % reason)
	claim_cancelled.emit(reason)

func _complete_claim() -> void:
	var id := claiming
	claiming = &""
	claim_time = 0.0
	_set_state(id, CONTROLLED)
	markers[id].play_claim_effect()
	_flash_border(id, false, 1.0)
	_announced[id] = CONTROLLED
	print("[TERRITORIO] %s RECUPERADA (%d/%d)" % [info(id).name, controlled_count(), total_count()])
	claimed.emit(id, info(id).name)

# Pausado, o _physics_process nao roda: cancela aqui (RF-TER-006).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		cancel_claim("pausa")

func _on_night_started() -> void:
	cancel_claim("anoiteceu")

func _set_state(id: StringName, s: int) -> void:
	if states[id] == s:
		return
	states[id] = s
	_refresh()
	state_changed.emit(id, s)

func _refresh() -> void:
	for id in markers:
		markers[id].set_state(states[id])
		var m: StandardMaterial3D = _borders[id]
		m.albedo_color = Color(Marker.CONTROLLED_COLOR if states[id] == CONTROLLED else Color("c4848f"), m.albedo_color.a)

# --- entrada em regiao (RF-TER-011), checada 4x por segundo --------------------

func _process(delta: float) -> void:
	_region_wait -= delta
	if _region_wait > 0.0 or not DayNightManager.can_play():
		return
	_region_wait = REGION_CHECK_INTERVAL
	var id := territory_at(player.global_position)
	if id == current_region:
		return
	current_region = id
	if id == &"" or not info(id).conquerable:
		return
	_flash_border(id, false, 1.0)
	if _announced.get(id, -1) != states[id]:
		_announced[id] = states[id]
		region_entered.emit(id, info(id).name, states[id])

# --- limite visual discreto (RF-TER-009) ----------------------------------------
# Contorno fino no chao (4 faixas, 1 material por territorio, sem luz/sombra).
# Em repouso fica quase invisivel; acende ao entrar, perto do marco e durante a
# conquista, e volta a ficar sutil.
func _build_border(t: Dictionary) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(Color("c4848f"), BORDER_ALPHA)
	_borders[t.id] = m
	var r: Rect2 = t.rect
	var edges := [
		[Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y)],
		[Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y)],
		[Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y)],
		[Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y)],
	]
	for e in edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var strip := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(maxf(absf(b.x - a.x), 0.14), 0.02, maxf(absf(b.y - a.y), 0.14))
		strip.mesh = box
		strip.material_override = m
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(strip)
		strip.global_position = Vector3((a.x + b.x) * 0.5, 0.04, (a.y + b.y) * 0.5)

func _flash_border(id: StringName, hold: bool, seconds := 0.0) -> void:
	var m: StandardMaterial3D = _borders.get(id)
	if m == null:
		return
	var old: Tween = _border_flash.get(id)
	if old != null and old.is_valid():
		old.kill()
	if hold:
		m.albedo_color.a = BORDER_FLASH
		return
	var t := create_tween()
	if seconds > 0.0:
		t.tween_property(m, "albedo_color:a", BORDER_FLASH, 0.25)
		t.tween_interval(seconds)
	t.tween_property(m, "albedo_color:a", BORDER_ALPHA, 1.5)
	_border_flash[id] = t

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
