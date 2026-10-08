extends Node

# Spec: docs/specs/013c-combate-coleta-hud.md — RF-COL-001 (PROVISORIO)
#
# Fonte de verdade de MADEIRA e PEDRA (coleta). Separada dos Pontos de Defesa
# (combate/ondas, DefenseEconomy). Vive na cena do mundo: persiste entre dias e
# so zera ao Reiniciar (mundo novo). A HUD so exibe (`resources_changed`).

signal resources_changed(kind: StringName, total: int, delta: int)

const WOOD := &"wood"
const STONE := &"stone"

var amounts := {WOOD: 0, STONE: 0}

func _ready() -> void:
	add_to_group("resource_stock")

func get_amount(kind: StringName) -> int:
	return amounts.get(kind, 0)

# Spec 013D (RF-INV-002): gasto ATOMICO de uma receita — ou paga tudo, ou nada.
func can_afford_resources(wood: int, stone: int) -> bool:
	return wood >= 0 and stone >= 0 and amounts[WOOD] >= wood and amounts[STONE] >= stone

func spend_resources(wood: int, stone: int) -> bool:
	if not can_afford_resources(wood, stone):
		return false # nada e retirado: nunca fica negativo nem "meio pago"
	amounts[WOOD] -= wood
	amounts[STONE] -= stone
	print("[COLETA] -%d madeira, -%d pedra (restam %d / %d)" % [wood, stone, amounts[WOOD], amounts[STONE]])
	if wood > 0:
		resources_changed.emit(WOOD, amounts[WOOD], -wood)
	if stone > 0:
		resources_changed.emit(STONE, amounts[STONE], -stone)
	return true

func add(kind: StringName, amount: int) -> void:
	if amount <= 0 or not amounts.has(kind):
		return
	amounts[kind] += amount
	print("[COLETA] +%d %s (total %d)" % [amount, kind, amounts[kind]])
	resources_changed.emit(kind, amounts[kind], amount)
