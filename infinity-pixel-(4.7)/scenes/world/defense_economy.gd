extends Node

# Spec: docs/specs/013b-economia-defesas-fixas.md
# RF-ECO-001 / 002 — Pontos de Defesa (PROVISORIO)
#
# Fonte de verdade da moeda. Vive na cena do mundo: cada partida nova
# (JOGAR/Reiniciar) instancia um mundo novo e comeca com `starting_points`.
# A HUD so exibe (escuta `points_changed`).

signal points_changed(total: int, delta: int)

@export var starting_points := 40 # RF-ECO-001: uma torre antes da Noite 1 (013C: era 30)
@export var reward_per_wave_enemy := 15 # RF-ECO-002
@export var wave_manager_path: NodePath = ^"../WaveManager"

var points := 0

func _ready() -> void:
	add_to_group("defense_economy")
	points = starting_points
	var wave := get_node_or_null(wave_manager_path)
	if wave != null:
		# So inimigo da ONDA morto de verdade, uma vez (WaveManager ja garante).
		wave.wave_enemy_defeated.connect(func(_enemy): add_points(reward_per_wave_enemy))

func can_afford(cost: int) -> bool:
	return cost >= 0 and points >= cost

func spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	points -= cost
	print("[DEFESA] -%d pontos (restam %d)" % [cost, points])
	points_changed.emit(points, -cost)
	return true

func add_points(amount: int) -> void:
	if amount <= 0:
		return
	points += amount
	print("[DEFESA] +%d pontos (total %d)" % [amount, points])
	points_changed.emit(points, amount)
