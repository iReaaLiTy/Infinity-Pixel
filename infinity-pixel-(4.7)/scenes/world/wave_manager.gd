extends Node

# Spec: docs/specs/005-onda-e-vitoria.md
# RF-AGE-010 — Spawn escalonado dos inimigos (CONFIRMADO)
# RF-AGE-011 — Condicao de vitoria (CONFIRMADO)
# Disparado pelo sinal night_started do DayNightManager — desde a Spec 013
# (docs/specs/013-relogio-ciclo-ataques-noturnos.md) automaticamente as 18:00.

@export var enemy_scene: PackedScene
@export var spawn_point_path: NodePath
# Spec 013 RF-CIC-006: quantidade por noite = base + extra x (noite - 1).
# Noite 1 = 3 (RF-AGE-010), Noite 2 = 4, Noite 3 = 5... Sem mudar HP/dano/velocidade.
@export var base_enemy_count := 3
@export var extra_enemies_per_night := 1
@export var spawn_interval := 2.0 # RF-AGE-010: intervalo de 2s entre cada spawn.
## Spec 012/013: `spawn_offsets` vem intercalado por rota (indice % route_count
## = rota). O n-esimo inimigo usa a rota n % route_count (round-robin).
@export var route_count := 3

var enemy_count := 3 # inimigos da onda atual (definido no inicio de cada noite)

# Spec 013B: inimigo da onda morto de verdade (uma vez) — fonte da recompensa.
signal wave_enemy_defeated(enemy: Node3D)
# Spec 010 RF-NAV-004: pontos fixos (sem sorteio) ao redor do ponto de spawn, em
# ordem de preferencia. Cabem entre os pilares do arco (borda interna em x = +-2,4).
@export var spawn_offsets: Array[Vector3] = [
	Vector3(0, 0, 0), Vector3(-1.6, 0, -1.4), Vector3(1.6, 0, -1.4),
	Vector3(0, 0, -2.8), Vector3(-1.6, 0, 1.4), Vector3(1.6, 0, 1.4),
	Vector3(-1.6, 0, -4.2), Vector3(1.6, 0, -4.2), Vector3(0, 0, -5.6),
]
const SPAWN_CLEARANCE := 1.3 # distancia minima de outra criatura (m)
const SPAWN_BODY_RADIUS := 0.55 # capsula do dino (0,5) + folga
const SPAWN_BLOCKERS := 1 | 2 | 4 | 8 # Spec 009: mundo, Player, criaturas, construcoes
const SPAWN_MAX_NAV_SNAP := 0.3 # ponto precisa estar na navmesh (ou quase)

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

func enemy_count_for_night(night: int) -> int:
	return base_enemy_count + extra_enemies_per_night * maxi(night - 1, 0)

func _start_wave() -> void:
	_wave_active = true
	_spawned_count = 0
	_spawn_timer = 0.0
	_active_wave_enemies.clear()
	enemy_count = enemy_count_for_night(DayNightManager.day_number)
	print("[NOITE] Noite %d: onda iniciada com %d inimigos, intervalo de %.1fs." % [DayNightManager.day_number, enemy_count, spawn_interval])

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
	var spawn_position := _find_spawn_position()
	var enemy := enemy_scene.instantiate() as Node3D
	get_parent().add_child(enemy)
	enemy.global_position = spawn_position
	_active_wave_enemies[enemy] = true
	enemy.add_to_group("wave_enemy") # Spec 013B: alvo valido das torres
	# Identidade visual do inimigo noturno (paleta azul-violeta): decidida aqui,
	# pela origem da criatura, nunca pelo horario. So visual.
	var look := enemy.get_node_or_null("Visual")
	if look != null and look.has_method("set_night_threat"):
		look.set_night_threat()
	# RF-AGE-011: inimigo da onda deixa de ser ameaca ao morrer OU ao ser domesticado.
	enemy.died.connect(_neutralize_wave_enemy.bind("morreu"))
	enemy.domesticated.connect(_neutralize_wave_enemy.bind("domesticado"))
	# Seguranca: removido da cena por outro caminho (sem take_damage).
	enemy.tree_exiting.connect(_neutralize_wave_enemy.bind(enemy, "removido"))
	print("[NOITE] Inimigo spawnado (%d/%d) em %s." % [_spawned_count + 1, enemy_count, spawn_position])
	print("[NOITE] Inimigo da wave registrado: %s" % enemy.name)

# Spec 010 RF-NAV-004: primeiro ponto livre da lista. Livre = na navmesh, sem
# corpo solido/criatura/Player sobreposto e longe de outras criaturas. A busca
# roda so no momento do spawn (3 vezes por noite), nunca por quadro.
func _find_spawn_position() -> Vector3:
	var origin := _spawn_point.global_position
	var world := get_parent() as Node3D
	var space := world.get_world_3d().direct_space_state
	var map := world.get_world_3d().navigation_map
	var nav_ready := NavigationServer3D.map_get_iteration_id(map) > 0
	var shape := CylinderShape3D.new()
	shape.radius = SPAWN_BODY_RADIUS
	shape.height = 1.4
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = SPAWN_BLOCKERS
	var creatures := get_tree().get_nodes_in_group("wild_dino") + get_tree().get_nodes_in_group("domesticated")
	# O n-esimo inimigo da onda comeca pelo n-esimo ponto: cada um sai de um lugar
	# diferente (rotas diferentes), mesmo quando o anterior ja liberou o ponto 0.
	# Spec 013: se o ponto estiver ocupado, tenta antes os outros pontos da MESMA
	# rota (indice % route_count) e so depois as outras rotas.
	var order: Array[int] = []
	var others: Array[int] = []
	var route := _spawned_count % maxi(route_count, 1)
	for k in spawn_offsets.size():
		var index := (_spawned_count + k) % spawn_offsets.size()
		(order if index % maxi(route_count, 1) == route else others).append(index)
	order.append_array(others)
	for index in order:
		var offset: Vector3 = spawn_offsets[index]
		var candidate := origin + offset
		if nav_ready:
			var on_mesh := NavigationServer3D.map_get_closest_point(map, candidate)
			if Vector2(on_mesh.x - candidate.x, on_mesh.z - candidate.z).length() > SPAWN_MAX_NAV_SNAP:
				continue # dentro de obstaculo ou fora da area navegavel
		var crowded := false
		for other in creatures:
			if is_instance_valid(other) and Vector2(other.global_position.x - candidate.x, other.global_position.z - candidate.z).length() < SPAWN_CLEARANCE:
				crowded = true
				break
		if crowded:
			continue
		# Cilindro de 0,15 a 1,55 m acima do chao: nao toca o chao (topo em y = 0).
		query.transform = Transform3D(Basis.IDENTITY, Vector3(candidate.x, 0.85, candidate.z))
		if not space.intersect_shape(query, 1).is_empty():
			continue
		return candidate
	push_warning("WaveManager: nenhum ponto de spawn livre; usando o ponto base.")
	return origin

func _neutralize_wave_enemy(enemy: Node3D, reason: String) -> void:
	if not _active_wave_enemies.has(enemy):
		# nao pertence a onda atual ou ja foi neutralizado (evita contagem dupla)
		if reason == "morreu" and enemy.is_domesticated:
			print("[NOITE] Aliado já neutralizado anteriormente - contador da wave não alterado")
		return
	_active_wave_enemies.erase(enemy)
	if is_instance_valid(enemy):
		enemy.remove_from_group("wave_enemy") # torres param de mira-lo
	# Spec 013B RF-ECO-002: recompensa so por morte real, e uma unica vez — esta
	# linha so roda na primeira neutralizacao (domesticado/removido nao pagam).
	if reason == "morreu":
		wave_enemy_defeated.emit(enemy)
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
