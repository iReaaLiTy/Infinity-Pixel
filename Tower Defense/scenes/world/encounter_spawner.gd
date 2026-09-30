extends Node3D

# AC1 (GDD secoes 3 e 6): encontro domesticavel disponivel durante o DIA, sem
# depender da tecla de depuracao T. Posicao proposta na planta: (-10, +5).
#
# - Cria um WildDino territorial (nao avanca ate a base) ao iniciar a partida.
# - A cada novo DIA, cria outro SOMENTE se o anterior deixou de ser selvagem
#   (foi domesticado ou derrotado). Aliados nunca sao removidos.
# - Nao pertence a onda: o WaveManager nao conta este dinossauro.

signal encounter_spawned(dino: Node3D)

@export var encounter_scene: PackedScene

var current_encounter: Node3D

func _ready() -> void:
	if encounter_scene == null:
		push_error("EncounterSpawner: encounter_scene nao configurada.")
		return
	DayNightManager.day_started.connect(_on_day_started)
	# O pai ainda esta montando os filhos; adicionar irmao so no proximo quadro.
	_spawn_if_needed.call_deferred()

func _on_day_started() -> void:
	_spawn_if_needed()

func is_encounter_wild() -> bool:
	return is_instance_valid(current_encounter) and current_encounter.is_inside_tree() \
		and current_encounter.is_in_group("wild_dino")

func _spawn_if_needed() -> void:
	if is_encounter_wild() or DayNightManager.is_game_over:
		return
	var dino := encounter_scene.instantiate() as Node3D
	dino.territorial = true
	dino.name = "WildDinoEncontro"
	dino.position = global_position
	get_parent().add_child(dino, true)
	current_encounter = dino
	print("[ENCONTRO] Selvagem domesticavel disponivel em %s" % global_position)
	encounter_spawned.emit(dino)
