extends Node

# Spec: docs/specs/005-onda-e-vitoria.md
# RF-AGE-010 — Spawn escalonado dos inimigos (CONFIRMADO)
# RF-AGE-011 — Condicao de vitoria (CONFIRMADO)
# Disparado por docs/specs/006-ciclo-dia-noite.md (RF-AGE-014, "Iniciar Noite").

@export var enemy_scene: PackedScene
@export var spawn_point_path: NodePath
@export var enemy_count := 3 # RF-AGE-010: 3 dinossauros selvagens na primeira onda.
@export var spawn_interval := 2.0 # RF-AGE-010: intervalo de 2s entre cada spawn.

var _spawn_point: Node3D
# Somente inimigos criados por ESTA onda. Inimigos de teste (tecla T) nunca entram
# aqui, entao nao afetam a vitoria. Cada inimigo sai do dicionario uma unica vez.
var _active_wave_enemies := {}
var _spawned_count := 0
var _spawn_timer := 0.0
var _wave_active := false

func _ready() -> void:
	_spawn_point = get_node_or_null(spawn_point_path) as Node3D
	if _spawn_point == null:
		push_error("WaveManager: ponto de spawn nao encontrado em '%s'." % spawn_point_path)
	if enemy_scene == null:
		push_error("WaveManager: enemy_scene nao configurada.")
	DayNightManager.night_started.connect(_start_wave)

func _start_wave() -> void:
	_wave_active = true
	_spawned_count = 0
	_spawn_timer = 0.0
	_active_wave_enemies.clear()
	print("[NOITE] Onda iniciada: %d inimigos, intervalo de %.1fs." % [enemy_count, spawn_interval])

func _process(delta: float) -> void:
	if not _wave_active or DayNightManager.is_game_over:
		return

	if _spawned_count < enemy_count:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_enemy()
			_spawned_count += 1
			_spawn_timer = spawn_interval
			_check_wave_complete()

func _spawn_enemy() -> void:
	if _spawn_point == null or enemy_scene == null:
		push_error("WaveManager: spawn cancelado, configuracao incompleta.")
		return
	var enemy := enemy_scene.instantiate() as Node3D
	get_parent().add_child(enemy)
	enemy.global_position = _spawn_point.global_position
	_active_wave_enemies[enemy] = true
	# RF-AGE-011: inimigo da onda deixa de ser ameaca ao morrer OU ao ser domesticado.
	enemy.died.connect(_neutralize_wave_enemy.bind("morreu"))
	enemy.domesticated.connect(_neutralize_wave_enemy.bind("domesticado"))
	# Seguranca: removido da cena por outro caminho (sem take_damage).
	enemy.tree_exiting.connect(_neutralize_wave_enemy.bind(enemy, "removido"))
	print("[NOITE] Inimigo spawnado (%d/%d) em %s." % [_spawned_count + 1, enemy_count, _spawn_point.global_position])
	print("[NOITE] Inimigo da wave registrado: %s" % enemy.name)

func _neutralize_wave_enemy(enemy: Node3D, reason: String) -> void:
	if not _active_wave_enemies.has(enemy):
		# nao pertence a onda atual ou ja foi neutralizado (evita contagem dupla)
		if reason == "morreu" and enemy.is_domesticated:
			print("[NOITE] Aliado já neutralizado anteriormente - contador da wave não alterado")
		return
	_active_wave_enemies.erase(enemy)
	if not _wave_active:
		return
	print("[NOITE] Inimigo da wave %s. Restantes: %d" % [reason, _active_wave_enemies.size()])
	_check_wave_complete()

# RF-AGE-011: onda vencida quando todos os inimigos ja foram spawnados e todos
# foram neutralizados (mortos ou domesticados).
func _check_wave_complete() -> void:
	if not _wave_active or _spawned_count < enemy_count or not _active_wave_enemies.is_empty():
		return
	_wave_active = false
	print("[NOITE] Wave concluida")
	# Resolve at end of frame: base destruction in this frame has priority.
	_finish_victory.call_deferred()

func _finish_victory() -> void:
	if not is_inside_tree() or not DayNightManager.gameplay_enabled:
		return
	var base := get_tree().get_first_node_in_group("base")
	if is_instance_valid(base) and base.health <= 0.0:
		DayNightManager.report_defeat()
	else:
		DayNightManager.report_wave_victory()

func snapshot() -> Dictionary:
	return {"spawned": _spawned_count, "total": enemy_count, "active": _active_wave_enemies.size(), "resolved": _spawned_count - _active_wave_enemies.size()}

func cancel_wave() -> void:
	_wave_active = false
	_active_wave_enemies.clear()
