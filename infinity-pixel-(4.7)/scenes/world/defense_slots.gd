extends Node3D

# Spec: docs/specs/013b-economia-defesas-fixas.md
# RF-ECO-003 / 006 — Interacao com os pontos de defesa (PROVISORIO)
#
# Pai dos 6 DefenseSlot. Interacao contextual por proximidade (como o E da
# domesticacao): perto de um ponto, a HUD mostra o painel e a tecla C (acao
# "build_interact") ou o botao do painel constroem/melhoram. Regras:
# so de DIA (RF-ECO-006) e so com pontos suficientes (DefenseEconomy).

signal notice(text: String) # feedback curto para a HUD (noite, sem pontos)

const INTERACT_RANGE := 2.6 # m do centro do ponto (plataforma tem ~1,2 m)
const DefenseTower := preload("res://scenes/world/defense_tower.gd")

@export var economy_path: NodePath = ^"../DefenseEconomy"
@export var player_path: NodePath = ^"../Player"

@onready var economy: Node = get_node(economy_path)
@onready var player: Node3D = get_node(player_path)

func slots() -> Array:
	return get_children().filter(func(c): return c.is_in_group("defense_slot"))

# Ponto mais proximo do Player dentro do alcance (ou null).
func nearest_slot() -> Node3D:
	if not is_instance_valid(player) or player.get("is_dead") == true:
		return null
	var best: Node3D = null
	var best_d := INTERACT_RANGE
	for slot in slots():
		var d: Vector3 = slot.global_position - player.global_position
		var flat := Vector2(d.x, d.z).length()
		if flat <= best_d:
			best_d = flat
			best = slot
	return best

# Custo da proxima acao no ponto (-1 = nivel maximo).
func action_cost(slot: Node3D) -> int:
	if slot.is_empty():
		return DefenseTower.LEVELS[0].cost
	return slot.tower.upgrade_cost()

# Motivo de bloqueio ("" = pode agir).
func block_reason(slot: Node3D) -> String:
	if not slot.is_empty() and slot.tower.is_max_level():
		return "NÍVEL MÁXIMO"
	if not DayNightManager.is_day():
		return "Construa durante o dia"
	if not economy.can_afford(action_cost(slot)):
		return "Pontos insuficientes"
	return ""

func interact(slot: Node3D) -> bool:
	if slot == null or not DayNightManager.can_play():
		return false
	var reason := block_reason(slot)
	if reason != "":
		notice.emit(reason)
		return false
	if not economy.spend(action_cost(slot)):
		return false
	if slot.is_empty():
		slot.build()
	else:
		slot.tower.upgrade()
	get_tree().call_group("audio_director", "effect", true)
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_interact") and not event.is_echo() and DayNightManager.can_play():
		var slot := nearest_slot()
		if slot != null:
			interact(slot)
			get_viewport().set_input_as_handled()
