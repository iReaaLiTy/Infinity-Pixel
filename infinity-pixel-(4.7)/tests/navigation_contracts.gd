extends Node

# Spec 010 — regressao de navegacao/avoidance/slots com a cena real, fisica real
# e a IA real dos dinossauros (nada de movimento substituto).
#   Godot_console [--headless] --path . res://tests/navigation_contracts.tscn [-- --report=<arquivo>]
const ApproachSlots := preload("res://scenes/enemies/approach_slots.gd")
const DINO := preload("res://scenes/enemies/wild_dino.tscn")
const CARNO := preload("res://scenes/enemies/carnotauro.tscn")
const LONE_ROCK := Vector3(8.46, 0, 0.74) # Rock21 (r = 0,67 m), isolada no meio da arena (Spec 009)

var passed: Array[String] = []
var failed: Array[String] = []
var app: Node
var world: Node3D
var player: CharacterBody3D
var map: RID

func check(ok: bool, title: String) -> void:
	(passed if ok else failed).append(title)
	print(("PASS: " if ok else "FAIL: ") + title)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func seconds(s: float) -> void:
	await frames(int(s * Engine.physics_ticks_per_second))

func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func min_pair_distance(nodes: Array) -> float:
	var best := INF
	for i in nodes.size():
		for j in range(i + 1, nodes.size()):
			best = minf(best, flat(nodes[i].global_position, nodes[j].global_position))
	return best

func spawn(scene: PackedScene, pos: Vector3, territorial := false) -> CharacterBody3D:
	var dino := scene.instantiate() as CharacterBody3D
	dino.territorial = territorial
	dino.position = pos
	world.add_child(dino, true)
	return dino

func clear_creatures() -> void:
	for group in ["wild_dino", "domesticated"]:
		for c in get_tree().get_nodes_in_group(group):
			c.queue_free()
	await frames(2)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _ready() -> void:
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	app.start_game()
	await frames(10)
	world = app.world
	player = world.get_node("Player")
	# Spec 011: o Player agora morre e renasce no PlayerSpawn. Esta suite mede
	# navegacao ao redor de um Player parado/correndo; a vida dele e coberta por
	# tests/player_health. Sem isto, 3 perseguidores o matam no meio da medicao.
	player._invulnerable_left = INF
	map = world.get_world_3d().navigation_map
	var encounter = world.get_node("EncounterSpawner").current_encounter

	# --- RF-NAV-001: navmesh ------------------------------------------------
	var region := world.get_node("NavigationRegion") as NavigationRegion3D
	check(region != null and region.navigation_mesh != null and region.navigation_mesh.get_polygon_count() > 50, "NavigationRegion3D com navmesh assada (%d poligonos)" % (region.navigation_mesh.get_polygon_count() if region and region.navigation_mesh else 0))
	check(NavigationServer3D.map_get_iteration_id(map) > 0, "Mapa de navegacao sincronizado")
	var tree_snap := NavigationServer3D.map_get_closest_point(map, LONE_ROCK)
	check(flat(tree_snap, LONE_ROCK) > 1.0, "Pedra e buraco na navmesh (ponto mais proximo a %.2f m do centro)" % flat(tree_snap, LONE_ROCK))
	var base_pos: Vector3 = world.get_node("Territory").global_position
	var core_snap := NavigationServer3D.map_get_closest_point(map, base_pos)
	check(flat(core_snap, base_pos) > 0.9 and flat(core_snap, base_pos) < 1.5, "Nucleo do refugio recortado, borda dentro do alcance de chegada (%.2f m)" % flat(core_snap, base_pos))
	var path := NavigationServer3D.map_get_path(map, Vector3(0, 0.5, 15), Vector3(0, 0.5, -13.5), true)
	check(path.size() >= 2 and flat(path[path.size() - 1], Vector3(0, 0, -13.5)) < 0.5, "Caminho spawn -> refugio existe (%d pontos)" % path.size())

	# --- Contorno de obstaculo (perseguicao real) -----------------------------
	encounter.set_physics_process(false)
	encounter.global_position = Vector3(-17, 0.5, 17)
	player.global_position = LONE_ROCK + Vector3(0, 1, -2.2)
	var chaser := spawn(DINO, LONE_ROCK + Vector3(0, 0.5, 3.2))
	await frames(3)
	var agent: NavigationAgent3D = chaser.get_node("NavigationAgent3D")
	await seconds(0.5)
	var detour := agent.get_current_navigation_path().size()
	var reached := false
	for i in 50:
		await seconds(0.1)
		if flat(chaser.global_position, player.global_position) <= 2.0:
			reached = true
			break
	check(detour >= 3, "Perseguidor recebe caminho com desvio da pedra (%d pontos)" % detour)
	check(reached, "Perseguidor contorna a pedra e chega ao alcance do Player (%.2f m)" % flat(chaser.global_position, player.global_position))
	await clear_creatures()

	# --- RF-NAV-003: slots de ataque ao redor do Player ------------------------
	player.global_position = Vector3(4, 1, 6)
	await frames(5)
	var hunters: Array = []
	for offset in [Vector3(-5, 0, 0), Vector3(5, 0, 0.5), Vector3(0.5, 0, 5)]:
		hunters.append(spawn(DINO, player.global_position + offset + Vector3(0, -0.5, 0)))
	await seconds(4.0)
	var slots := ApproachSlots.holders(player, &"attack")
	var unique := {}
	for s in slots: unique[s] = true
	check(slots.size() == 3 and unique.size() == 3, "3 perseguidores com 3 slots diferentes (%s)" % [slots.keys()])
	var all_in_reach := true
	for h in hunters:
		all_in_reach = all_in_reach and flat(h.global_position, player.global_position) <= 2.0
	check(all_in_reach, "Os 3 ficam dentro do alcance de ataque (2 m)")
	check(min_pair_distance(hunters) >= 0.9, "Perseguidores nao se sobrepoem (menor distancia %.2f m)" % min_pair_distance(hunters))
	var snapshot := {}
	for h in hunters: snapshot[h] = ApproachSlots.slot_of(player, &"attack", h)
	await seconds(1.5)
	var stable := true
	for h in hunters: stable = stable and ApproachSlots.slot_of(player, &"attack", h) == snapshot[h]
	check(stable, "Slots estaveis com o Player parado (nao sorteiam de novo)")
	# Distribuicao: angulos ao redor do Player, nao uma fila do mesmo lado.
	var angles: Array[float] = []
	for h in hunters:
		var d: Vector3 = h.global_position - player.global_position
		angles.append(atan2(d.x, d.z))
	angles.sort()
	var max_gap := TAU - (angles[2] - angles[0])
	for i in 2: max_gap = maxf(max_gap, angles[i + 1] - angles[i])
	check(max_gap <= deg_to_rad(200.0), "Perseguidores cercam o Player (maior vao %.0f graus, limite 200)" % rad_to_deg(max_gap))
	# Correr: os perseguidores se reposicionam em volta da nova posicao.
	key(KEY_D, true)
	await seconds(1.2)
	key(KEY_D, false)
	await seconds(3.0)
	var regrouped := true
	for h in hunters:
		regrouped = regrouped and flat(h.global_position, player.global_position) <= 2.3
	check(regrouped, "Apos o Player correr, os 3 voltam a cercar o Player")
	check(min_pair_distance(hunters) >= 0.9, "Apos o reposicionamento continuam separados (%.2f m)" % min_pair_distance(hunters))
	# Liberacao: morte libera o slot.
	var victim = hunters[0]
	var victim_slot: Variant = ApproachSlots.slot_of(player, &"attack", victim)
	victim.take_damage(80)
	await frames(3)
	check(victim_slot != null and ApproachSlots.holder_of(player, &"attack", victim_slot) == null, "Morte libera o slot")
	var tamed = hunters[1]
	tamed.take_damage(60)
	tamed.domesticate()
	await frames(2)
	check(ApproachSlots.slot_of(player, &"attack", tamed) == null, "Domesticacao libera o slot de ataque")
	await clear_creatures()

	# --- RF-NAV-005: aliados em slots diferentes --------------------------------
	player.global_position = Vector3(2, 1, 4)
	await frames(5)
	var allies: Array = []
	for offset in [Vector3(-2, 0, -2), Vector3(2, 0, -2), Vector3(0, 0, 3)]:
		var a := spawn(DINO, player.global_position + offset + Vector3(0, -0.5, 0))
		await frames(1)
		a.take_damage(60)
		a.domesticate()
		allies.append(a)
	await seconds(3.0)
	var ally_slots := ApproachSlots.holders(player, &"follow")
	check(ally_slots.size() == 3, "3 aliados com 3 slots de seguir diferentes (%s)" % [ally_slots.keys()])
	check(min_pair_distance(allies) >= 1.0, "Aliados nao ocupam a mesma posicao (%.2f m)" % min_pair_distance(allies))
	key(KEY_W, true)
	await seconds(1.5)
	key(KEY_W, false)
	await seconds(3.5)
	var near := true
	for a in allies: near = near and flat(a.global_position, player.global_position) <= 4.5
	check(near, "Aliados seguem o Player apos ele andar")
	check(min_pair_distance(allies) >= 1.0, "Aliados continuam separados apos seguir (%.2f m)" % min_pair_distance(allies))
	# Ficar/defender/voltar ao posto continua funcionando com navegacao.
	var guard = allies[0]
	player.global_position = guard.global_position + Vector3(0, 0.5, 1)
	await frames(3)
	Input.action_press("command_stay")
	await frames(2)
	Input.action_release("command_stay")
	await frames(2)
	check(guard.ally_state == 1, "F ainda coloca o aliado em FICAR")
	var post: Vector3 = guard._stay_position
	var intruder := spawn(DINO, post + Vector3(3, 0, 0), true)
	intruder.set_physics_process(false)
	await seconds(3.0)
	check(not is_instance_valid(intruder) or intruder.hp < 80, "Aliado em FICAR vai ate o hostil e ataca")
	if is_instance_valid(intruder): intruder.take_damage(80)
	await seconds(3.0)
	check(flat(guard.global_position, post) <= 0.6, "Aliado volta ao posto depois do combate (%.2f m)" % flat(guard.global_position, post))
	# Os outros dois continuam seguindo e chegam aos proprios slots (sem travar).
	var settled := true
	for follower in [allies[1], allies[2]]:
		var fslot: Variant = ApproachSlots.slot_of(player, &"follow", follower)
		settled = settled and fslot != null and flat(follower.global_position, ApproachSlots.slot_position(player, &"follow", fslot)) <= 1.0
	check(settled, "Seguidores chegam aos slots com um aliado parado ao lado do Player")
	await clear_creatures()

	# --- WildDino territorial e Carnotauro --------------------------------------
	var home := Vector3(-10, 0.5, 5)
	var wild := spawn(DINO, home, true)
	await frames(5)
	player.global_position = home + Vector3(5, 0.5, 0)
	await seconds(1.5)
	check(flat(wild.global_position, home) > 1.0, "Territorial persegue o Player dentro da area")
	player.global_position = Vector3(10, 1, 15)
	await seconds(5.0)
	check(flat(wild.global_position, wild.home_position) <= 0.8, "Territorial volta a origem pela navegacao (%.2f m)" % flat(wild.global_position, wild.home_position))
	for i in 3: wild.take_damage(20)
	check(wild.hp == 20 and wild.can_be_domesticated(), "3 golpes de 20 -> 20/80 e elegivel (30%)")
	var carno := spawn(CARNO, Vector3(-6, 0.5, -6))
	await frames(2)
	carno.take_damage(60)
	check(not carno.can_be_domesticated() and carno.get_node_or_null("NavigationAgent3D") != null, "Carnotauro navega e continua nao domesticavel")
	await clear_creatures()

	# --- RF-NAV-004: onda — spawns separados e slots no refugio -----------------
	player.global_position = Vector3(11, 1, 17) # longe da rota (> 8 m), fora das arvores
	var base = world.get_node("Territory")
	var wave = world.get_node("WaveManager")
	# So para medir a distribuicao: com 3 atacantes noturnos a base cai em segundos.
	base.health = 1000.0
	DayNightManager.start_night()
	# Posicao real de cada inimigo no quadro em que nasce.
	var spawn_points: Array = []
	var seen_enemies := {}
	for i in int(4.6 * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		for e in wave._active_wave_enemies.keys():
			if not seen_enemies.has(e):
				seen_enemies[e] = true
				spawn_points.append(e.global_position)
	var wave_enemies: Array = wave._active_wave_enemies.keys()
	check(wave_enemies.size() == 3, "3 inimigos da onda criados")
	print("INFO spawns: %s" % [spawn_points])
	var spawn_gap := INF
	for i in spawn_points.size():
		for j in range(i + 1, spawn_points.size()):
			spawn_gap = minf(spawn_gap, flat(spawn_points[i], spawn_points[j]))
	check(spawn_gap >= 1.3, "Spawns da onda separados (menor distancia %.2f m)" % spawn_gap)
	var spawn_free := true
	for p in spawn_points:
		spawn_free = spawn_free and flat(NavigationServer3D.map_get_closest_point(map, p), p) <= 0.3
	check(spawn_free, "Spawns sobre a navmesh (fora de arvore/pedra/estrutura)")
	var min_gap_travel := INF
	var arrived := false
	for i in 200:
		await seconds(0.1)
		var alive: Array = wave._active_wave_enemies.keys().filter(func(e): return is_instance_valid(e))
		if alive.size() == 3:
			min_gap_travel = minf(min_gap_travel, min_pair_distance(alive))
		if alive.size() == 3 and alive.all(func(e): return flat(e.global_position, base.global_position) <= 1.5):
			arrived = true
			break
	await seconds(1.0) # assentam nos slots
	var base_slots := ApproachSlots.holders(base, &"base")
	check(base_slots.size() == 3, "3 inimigos com 3 slots diferentes no refugio (%s)" % [base_slots.keys()])
	check(arrived, "Os 3 chegam ao refugio (<= 1,5 m do centro)")
	check(min_gap_travel >= 0.8, "Inimigos nao se sobrepoem no trajeto (menor distancia %.2f m)" % min_gap_travel)
	var alive_end: Array = wave._active_wave_enemies.keys()
	print("INFO posicoes no refugio: %s" % [alive_end.map(func(e): return e.global_position)])
	check(min_pair_distance(alive_end) >= 0.9, "Inimigos separados no refugio (%.2f m)" % min_pair_distance(alive_end))
	var base_angles: Array[float] = []
	for e in alive_end:
		var d: Vector3 = e.global_position - base.global_position
		base_angles.append(atan2(d.x, d.z))
	base_angles.sort()
	var base_gap := TAU - (base_angles[2] - base_angles[0])
	for i in 2: base_gap = maxf(base_gap, base_angles[i + 1] - base_angles[i])
	check(base_gap <= deg_to_rad(200.0), "Inimigos distribuidos ao redor do refugio (maior vao %.0f graus, limite 200)" % rad_to_deg(base_gap))
	var hp_before: float = base.health
	await seconds(1.2)
	check(base.health < hp_before and base.health < 1000.0, "Os 3 causam dano ao refugio (%.0f -> %.0f)" % [hp_before, base.health])
	# Derrota do refugio preservada (Spec 006/008): base a 0 -> fim de sessao.
	base.take_damage(base.health)
	await frames(5)
	check(DayNightManager.is_game_over and app.screen == "defeat", "Refugio a 0 HP continua causando derrota")

	app.show_menu()
	await frames(3)
	var report := {"passed": passed, "failed": failed, "engine": Engine.get_version_info(), "display": DisplayServer.get_name()}
	var destination := "user://spec010-navigation.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			destination = argument.trim_prefix("--report=")
	var file := FileAccess.open(destination, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("SPEC010 RESULTS: %d passed; %d failed" % [passed.size(), failed.size()])
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)
