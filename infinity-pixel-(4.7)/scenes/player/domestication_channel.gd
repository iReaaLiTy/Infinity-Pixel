extends Node

# Spec: docs/specs/003-domesticacao.md
# RF-AGE-005 — Enfraquecimento como pre-condicao (PROVISORIO)
# RF-AGE-006 — Canalizacao da domesticacao (PROVISORIO)

const CHANNEL_TIME := 2.0 # RF-AGE-006 valor inicial. Teto de teste: ate 4 s.
# NAO esta na Spec 003: distancia de "aproximar" e de "afastar-se". Provisorio.
const INTERACTION_RANGE := 3.0

# DIAGNOSTICO TEMPORARIO (remover apos a Unidade 3 ser validada).
# true = logs [DEBUG DOMESTICACAO]; false = so os logs [Domesticacao] de estado.
const DEBUG := false
const SCRIPT_VERSION := "v5-alvo-elegivel"

@onready var _player: Node3D = get_parent() as Node3D

var _target: Node3D
var _progress := 0.0
var _e_event_down := false # E rastreado por evento de teclado (alem do polling)
var _last_e_state := false
var _last_progress_checkpoint := 0.0
var _last_block_reason := ""
## Spec 015 (RF-TER-006): uma segurada de E = uma interacao. Quem comeca a usar a
## segurada ("domesticate" ou "territory") e dono dela ate o E ser solto; a outra
## interacao nao comeca nessa mesma segurada.
var e_hold_owner := ""

func _ready() -> void:
	if DEBUG:
		print("[DEBUG DOMESTICACAO] script carregado (%s). player_encontrado=%s acao_domesticate_existe=%s" % [
			SCRIPT_VERSION, _player != null, InputMap.has_action("domesticate")])

# Captura o E por evento, independente do polling do Input.
func _input(event: InputEvent) -> void:
	if DayNightManager.can_play() and event is InputEventKey and not event.echo:
		if event.physical_keycode == KEY_E or event.keycode == KEY_E:
			_e_event_down = event.pressed

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		reset_channel() # evita E "preso" se a janela perder o foco com E pressionado
		if DEBUG:
			print("[DEBUG DOMESTICACAO] janela do jogo perdeu o foco — teclas nao chegam ao jogo ate reganhar o foco.")

func _physics_process(delta: float) -> void:
	# RF-AGE-016: fim de sessao bloqueia a domesticacao ate reiniciar.
	# Spec 011 RF-VID-003: Player morto tambem nao canaliza.
	if not DayNightManager.can_play() or _player.get("is_dead") == true:
		reset_channel()
		return

	var e_held := _is_domesticate_held()
	if not e_held:
		e_hold_owner = "" # soltou E: a proxima segurada esta livre
	if DEBUG and e_held != _last_e_state:
		_last_e_state = e_held
		_last_block_reason = ""
		if e_held:
			print("[DEBUG DOMESTICACAO] acao detectada: domesticate (E chegou ao script)")
			_debug_snapshot()
		else:
			print("[DEBUG DOMESTICACAO] E liberado")

	# Durante a canalizacao o alvo fica travado enquanto continuar valido; fora
	# dela, o alvo e o selvagem ELEGIVEL mais proximo. Assim um selvagem com HP
	# cheio (ou nao domesticavel) mais perto nao esconde o que esta enfraquecido,
	# e dois elegiveis proximos nao ficam trocando de alvo e zerando o progresso.
	var keep_target := _progress > 0.0 and _is_valid_target(_target)
	var next: Node3D = null
	if not keep_target:
		next = _find_nearest_eligible()
	if not keep_target and (next != _target or not is_instance_valid(_target)):
		if _progress > 0.0:
			_cancel("fora_do_alcance" if _is_alive(_target) and _target.can_be_domesticated() else "alvo_invalido")
		if _is_alive(_target):
			_target.set_prompt("")
		_target = next

	if _target == null:
		if e_held:
			_debug_block("nenhum selvagem elegivel a ate %.1f m" % INTERACTION_RANGE)
		return

	if not e_held:
		if _progress > 0.0:
			_cancel("tecla_liberada")
		_target.set_prompt("Segure E para domesticar")
		return

	if _progress == 0.0:
		if e_hold_owner != "" and e_hold_owner != "domesticate":
			return # esta segurada ja e do marco territorial
		e_hold_owner = "domesticate"
		print("[Domesticacao] canalizacao iniciada: alvo=%s hp=%.0f/%.0f" % [_target.name, _target.hp, _target.MAX_HP])
		_target.is_being_domesticated = true
		_last_progress_checkpoint = 0.0
	_progress += delta
	_target.set_prompt("Domesticando... %.1f / %.1f s" % [minf(_progress, CHANNEL_TIME), CHANNEL_TIME])
	if DEBUG:
		while _last_progress_checkpoint + 0.5 <= minf(_progress, CHANNEL_TIME):
			_last_progress_checkpoint += 0.5
			print("[DEBUG DOMESTICACAO] progresso=%.1f/%.1f" % [_last_progress_checkpoint, CHANNEL_TIME])
	if _progress >= CHANNEL_TIME:
		# As condicoes (alcance, elegibilidade, E) foram checadas neste mesmo frame.
		var dino := _target
		_progress = 0.0
		_target = null
		dino.domesticate()
		print("[Domesticacao] concluida: aliado=%s hp=%.0f/%.0f" % [dino.is_in_group("domesticated"), dino.hp, dino.MAX_HP])

func _cancel(reason: String) -> void:
	print("[Domesticacao] cancelada: %s (progresso %.1f s descartado)" % [reason, _progress])
	if _is_alive(_target):
		_target.is_being_domesticated = false
	_progress = 0.0
	_last_progress_checkpoint = 0.0

# Acao "domesticate" do Input Map, OU tecla E fisica (mesma checagem do WASD), OU evento de E.
func _is_domesticate_held() -> bool:
	if InputMap.has_action("domesticate") and Input.is_action_pressed("domesticate"):
		return true
	return Input.is_physical_key_pressed(KEY_E) or _e_event_down

# Parametro sem tipo de proposito: o alvo pode ter sido liberado (queue_free pela
# morte ou pela tecla T), e um parametro tipado rejeita objeto liberado com erro.
func _is_alive(dino) -> bool:
	return is_instance_valid(dino) and dino.is_inside_tree()

func _is_valid_target(dino) -> bool:
	return _is_alive(dino) and dino.is_in_group("wild_dino") and dino.can_be_domesticated() \
		and _flat_distance(dino) <= INTERACTION_RANGE

func _find_nearest_eligible() -> Node3D:
	var nearest: Node3D = null
	var nearest_dist := INTERACTION_RANGE
	for candidate in get_tree().get_nodes_in_group("wild_dino"):
		var dino := candidate as Node3D
		if not _is_alive(dino) or not dino.can_be_domesticated():
			continue
		var dist := _flat_distance(dino)
		if dist <= nearest_dist:
			nearest = dino
			nearest_dist = dist
	return nearest

func _flat_distance(dino: Node3D) -> float:
	var offset := dino.global_position - _player.global_position
	offset.y = 0.0
	return offset.length()

# Diagnostico: imprime o motivo do bloqueio so quando ele muda (nunca a cada frame).
func _debug_block(reason: String) -> void:
	if not DEBUG or reason == _last_block_reason:
		return
	_last_block_reason = reason
	print("[DEBUG DOMESTICACAO] E pressionado, mas bloqueado: %s" % reason)
	_debug_snapshot()

# Uma linha com o selvagem mais proximo (elegivel ou nao) — chamado so em mudancas de estado.
func _debug_snapshot() -> void:
	var closest: Node3D = null
	var closest_dist := INF
	for candidate in get_tree().get_nodes_in_group("wild_dino"):
		var dino := candidate as Node3D
		if not _is_alive(dino):
			continue
		var dist := _flat_distance(dino)
		if dist < closest_dist:
			closest = dino
			closest_dist = dist
	if closest == null:
		print("[DEBUG DOMESTICACAO] player_encontrado=%s nenhum selvagem na cena" % (_player != null))
		return
	print("[DEBUG DOMESTICACAO] player_encontrado=%s alvo_mais_proximo=%s is_domesticable=%s hp=%.0f/%.0f elegivel=%s distancia=%.2f alcance=%.1f" % [
		_player != null, closest.name, closest.is_domesticable, closest.hp, closest.MAX_HP,
		closest.can_be_domesticated(), closest_dist, INTERACTION_RANGE])

func reset_channel() -> void:
	_e_event_down = false
	e_hold_owner = ""
	if _progress > 0.0:
		_cancel("estado_ou_foco")
	if _is_alive(_target):
		_target.set_prompt("")
	_target = null

func get_progress() -> float:
	return _progress / CHANNEL_TIME

# Spec 015: o marco territorial usa a MESMA leitura de E e a mesma busca de alvo,
# para decidir a prioridade (alvo domesticavel valido vence o marco).
func is_e_held() -> bool:
	return _is_domesticate_held()

func find_eligible_target() -> Node3D:
	return _find_nearest_eligible()
