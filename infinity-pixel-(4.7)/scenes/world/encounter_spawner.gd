extends Node3D

# AC1 (GDD secoes 3 e 6): encontros domesticaveis disponiveis durante o DIA, sem
# depender da tecla de depuracao T.
# Spec 013C (RF-CMB-004): DOIS encontros diurnos — a posicao deste no (clareira
# das criaturas, bosque) e `extra_spawn_points` (regiao rochosa).
#
# - Cria um WildDino territorial (nao avanca ate a base) por ponto ao iniciar.
# - A cada novo DIA, recria SOMENTE o ponto cujo encontro deixou de ser selvagem
#   (domesticado ou derrotado): no maximo um selvagem por ponto, nunca acumula.
#   Aliados nunca sao removidos.
# - Nao pertencem a onda: o WaveManager nao os conta e eles nao dao Pontos.

signal encounter_spawned(dino: Node3D)

@export var encounter_scene: PackedScene
## Pontos extras (posicao global). Padrao: CreatureZones/DistantTerritory (Spec 012).
@export var extra_spawn_points: Array[Vector3] = [Vector3(13, 0.5, 22)]

var encounters: Array = [] # um por ponto (o selvagem atual daquele ponto, ou liberado)
var current_encounter: Node3D # encontro do bosque (ponto 0) — usado por HUD/testes

func _ready() -> void:
	if encounter_scene == null:
		push_error("EncounterSpawner: encounter_scene nao configurada.")
		return
	DayNightManager.day_started.connect(_on_day_started)
	# O pai ainda esta montando os filhos; adicionar irmao so no proximo quadro.
	_spawn_if_needed.call_deferred()

func _on_day_started() -> void:
	_spawn_if_needed()

func spawn_points() -> Array[Vector3]:
	var points: Array[Vector3] = [global_position]
	points.append_array(extra_spawn_points)
	return points

static func _is_wild(dino) -> bool:
	return is_instance_valid(dino) and dino.is_inside_tree() and dino.is_in_group("wild_dino")

func is_encounter_wild() -> bool:
	for dino in encounters:
		if _is_wild(dino):
			return true
	return false

func wild_encounters() -> Array:
	return encounters.filter(func(d): return _is_wild(d))

func _spawn_if_needed() -> void:
	if DayNightManager.is_game_over:
		return
	var points := spawn_points()
	encounters.resize(points.size())
	for i in points.size():
		if _is_wild(encounters[i]):
			continue
		var dino := encounter_scene.instantiate() as Node3D
		dino.territorial = true
		dino.name = "WildDinoEncontro" if i == 0 else "WildDinoEncontro%d" % (i + 1)
		dino.position = points[i]
		get_parent().add_child(dino, true)
		encounters[i] = dino
		print("[ENCONTRO] Selvagem domesticavel disponivel em %s" % points[i])
		encounter_spawned.emit(dino)
	current_encounter = encounters[0]
