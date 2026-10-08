extends Node3D

# Spec: docs/specs/005-onda-e-vitoria.md
# RF-AGE-012 — Base e condicao de derrota (PROVISORIO)
#
# Anexado ao no "Territory" ja existente na cena (mesmo no que os dinossauros
# selvagens usam como destino) — nao precisa de um no separado nem de
# renomear o que ja existe.

signal base_health_changed(current: float, max: float)
signal base_destroyed

# RF-AGE-012 hipotese de prototipo: valor inicial 100 HP, teto de exploracao
# ainda nao definido pelo grupo (ajustar apos playtest).
@export var max_health := 100.0

var health: float
var _destroyed := false

func _ready() -> void:
	add_to_group("base")
	add_to_group("damageable") # ADR 0001: qualquer no com take_damage() pode ser atingido
	health = max_health
	base_health_changed.emit(health, max_health)

func take_damage(amount: float) -> void:
	if _destroyed:
		return
	health = maxf(health - amount, 0.0)
	print("Base recebeu %.0f de dano. HP: %.0f/%.0f" % [amount, health, max_health])
	base_health_changed.emit(health, max_health)
	if health <= 0.0 and not _destroyed:
		_destroyed = true
		print("Base destruida — DERROTA.")
		base_destroyed.emit()
		DayNightManager.report_defeat()
