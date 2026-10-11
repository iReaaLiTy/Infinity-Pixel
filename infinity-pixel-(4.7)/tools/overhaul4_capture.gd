extends Node

# Visual Overhaul 4.0: capturas comparativas (nao e teste). Roda igual na copia
# "antes" e no codigo atual, com os mesmos enquadramentos: menu, telas, inventario
# (sem e com aliados), Player e dinossauros de perto, HUD com aliados e torre,
# cenario de dia e de noite. Jogo real, congelado em cada foto. Exige janela.
# Uso: res://tools/overhaul4_capture.tscn -- --output=<pasta> [--only=menu,inv,char,biome,combat]
# Mesmos enquadramentos na copia "antes" e no codigo atual (o combate e jogo
# real rodando: a posicao exata das criaturas varia entre as duas fotos).
var out := "user://overhaul4-capture/"
var only := ""
var app
var world: Node3D
var player: CharacterBody3D
var extra: Camera3D

func wait(count: int) -> void:
	for i in count:
		await get_tree().process_frame

var want_pause := false # a janela perder o foco pausa o jogo; so a foto da pausa quer isso

func shot(label: String, frames := 20) -> void:
	if not want_pause and app.screen == "paused":
		app.resume_game()
	await wait(frames)
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png("%s%s_%d.png" % [out, label, get_window().size.x])
	print("[O4] %s %dx%d" % [label, get_window().size.x, get_window().size.y])

func set_hour(h: float) -> void:
	if h >= 8.0 and h < 18.0:
		DayNightManager.state = DayNightManager.State.DAY
		DayNightManager.phase_elapsed = (h - 8.0) / 10.0 * DayNightManager.day_duration_seconds
	else:
		var hn := h + 24.0 if h < 12.0 else h
		DayNightManager.state = DayNightManager.State.NIGHT
		DayNightManager.phase_elapsed = (hn - 18.0) / 12.0 * DayNightManager.night_duration_seconds
	world.get_node("DayNightVisual").snap()

func wants(part: String) -> bool:
	return only == "" or part in only.split(",")

func pose(dino: Node3D, at: Vector3, yaw: float) -> void:
	dino.set_physics_process(false)
	dino.velocity = Vector3.ZERO
	dino.global_position = at
	dino.rotation.y = yaw

func look(from: Vector3, at: Vector3, fov := 50.0) -> void:
	extra.global_position = from
	extra.look_at(at, Vector3.UP)
	extra.fov = fov
	extra.make_current()

func start() -> void:
	app.start_game()
	await wait(30)
	world = app.world
	player = world.get_node("Player")
	player.set_process_unhandled_input(false)
	player.set_physics_process(false)
	player._invulnerable_left = INF
	player.get_node("StrategicCamera").follow_smoothing = 0.0
	for dino in world.get_node("EncounterSpawner").encounters:
		dino.set_physics_process(false)
	DayNightManager.gameplay_enabled = false
	extra = Camera3D.new()
	world.add_child(extra)
	set_hour(10.5)

func put_player(p: Vector3, yaw := 0.0) -> void:
	player.global_position = p
	player.velocity = Vector3.ZERO
	player.rotation.y = yaw
	await wait(3)

func menus() -> void:
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = size
		app._free_menu_backdrop() # show_menu() com o menu aberto nao liberava o fundo (corrigido no 3.0)
		app.show_menu()
		await shot("m01_menu", 100)
	get_window().size = Vector2i(1280, 720)
	app.show_settings(app._close_overlay)
	await shot("m02_configuracoes")
	app._close_overlay()
	app.show_info(true)
	await shot("m03_creditos")
	app._close_overlay()
	app.show_controls(app._close_overlay)
	await shot("m04_controles")
	app._close_overlay()
	await start()
	app.pause_game()
	want_pause = true
	await shot("m05_pausa")
	want_pause = false
	app.resume_game()
	DayNightManager.report_defeat()
	await shot("m06_derrota")

func allies(count: int) -> Array:
	var list := []
	var wild: Array = world.get_node("EncounterSpawner").encounters
	for i in count:
		var d: Node3D
		if i < wild.size() and is_instance_valid(wild[i]):
			d = wild[i]
		else:
			d = load("res://scenes/enemies/wild_dino.tscn").instantiate()
			world.add_child(d)
		d.domesticate()
		d.set_physics_process(false)
		list.append(d)
	return list

func inventory() -> void:
	for size in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		get_window().size = size
		await start()
		var stock = world.get_node("ResourceStock")
		stock.add(&"wood", 12)
		stock.add(&"stone", 4)
		await put_player(Vector3(0.0, 0.1, -10.0))
		app.toggle_inventory()
		await shot("i01_inventario_sem_aliados")
		if app.hud.has_method("show_inventory_tab"):
			for tab in ["build", "companions"]:
				app.hud.show_inventory_tab(tab)
				await shot("i01_inventario_sem_aliados_" + tab)
			app.hud.show_inventory_tab("resources")
		app.toggle_inventory()
		var team := allies(2)
		team[1].ally_state = 1
		team[1].hp = 47.0
		team[1]._update_label()
		for i in team.size():
			pose(team[i], Vector3(-2.0 + i * 3.0, 0.5, -12.0), 0.0)
		app.toggle_inventory()
		if app.hud.has_method("show_inventory_tab"):
			app.hud.show_inventory_tab("companions")
		await shot("i02_inventario_com_aliados")
		app.toggle_inventory()

func characters() -> void:
	get_window().size = Vector2i(1280, 720)
	await start()
	# Player de perto (3/4 de frente), patio do Refugio, 12:00.
	set_hour(12.0)
	await put_player(Vector3(3.0, 0.1, -14.0), 2.4)
	look(Vector3(5.2, 1.9, -11.6), Vector3(3.0, 1.0, -14.0), 40.0)
	await shot("c01_player_perto")
	# Dinossauro selvagem de perto, de lado.
	var wild: Array = world.get_node("EncounterSpawner").encounters
	var dino: Node3D = wild[1]
	pose(dino, Vector3(-3.0, 0.5, -14.0), PI / 2.0)
	look(Vector3(-3.0, 1.6, -9.6), Vector3(-3.3, 1.0, -14.0), 45.0)
	await shot("c02_dino_perto")
	look(Vector3(-0.2, 1.8, -11.0), Vector3(-3.0, 1.0, -14.0), 40.0)
	await shot("c03_dino_tres_quartos")
	# Fila: guardiao, selvagem, invasor, aliado (FICAR) e o Player.
	DayNightManager.gameplay_enabled = true
	DayNightManager.start_night()
	for i in 60 * 6:
		await get_tree().physics_frame
	var foes: Array = world.get_node("WaveManager")._active_wave_enemies.keys()
	DayNightManager.gameplay_enabled = false
	var tame: CharacterBody3D = load("res://scenes/enemies/wild_dino.tscn").instantiate()
	world.add_child(tame)
	tame.take_damage(60.0)
	var guardian: Node3D = wild[0]
	for d in world.get_tree().get_nodes_in_group("wild_dino"):
		if d.get("guardian_of") != "" and d.get("guardian_of") != null:
			guardian = d
	pose(guardian, Vector3(-4.5, 0.5, -6.5), PI / 2.0)
	pose(tame, Vector3(-1.5, 0.5, -6.5), PI / 2.0)
	pose(foes[0], Vector3(1.5, 0.5, -6.5), PI / 2.0)
	var ally: Node3D = wild[1]
	ally.domesticate()
	pose(ally, Vector3(4.5, 0.5, -6.5), PI / 2.0)
	ally.ally_state = 1
	ally._update_label()
	for i in range(1, foes.size()):
		pose(foes[i], Vector3(-30.0 - i * 3.0, 0.5, 40.0), 0.0)
	await put_player(Vector3(7.2, 0.1, -6.5), PI / 2.0)
	look(Vector3(1.2, 4.0, 1.2), Vector3(1.2, 0.9, -6.5), 62.0)
	set_hour(12.0)
	await shot("c04_tipos_1200")
	set_hour(21.0)
	await shot("c05_tipos_2100")


# --- 4.0: biomas, meio-dia/noite, combate e HUD em onda --------------------------
func biomes() -> void:
	get_window().size = Vector2i(1280, 720)
	await start()
	set_hour(12.0)
	var cam: Camera3D = player.get_node("StrategicCamera")
	# [rotulo, posicao do Player (camera do jogo), camera ampla de, para]
	var views := [
		["b01_floresta_oeste", Vector3(-15.0, 0.1, 14.0), Vector3(-7.5, 6.5, 4.5), Vector3(-16.0, 0.0, 16.5)],
		["b02_regiao_rochosa", Vector3(15.0, 0.1, 16.0), Vector3(8.0, 6.5, 7.5), Vector3(16.0, 0.0, 19.0)],
		["b03_ruinas", Vector3(0.0, 0.1, 12.5), Vector3(4.5, 4.2, 9.0), Vector3(0.0, 1.2, 16.0)],
		["b04_refugio", Vector3(0.0, 0.1, -10.0), Vector3(6.5, 6.0, -4.0), Vector3(0.0, 1.0, -15.0)],
	]
	for v in views:
		await put_player(v[1])
		cam.make_current()
		await shot(v[0] + "_jogo", 20)
		look(v[2], v[3], 55.0)
		await shot(v[0] + "_amplo", 20)
	cam.make_current()
	await put_player(Vector3(0.0, 0.1, -2.0))
	set_hour(12.0)
	await shot("s01_meio_dia", 20)
	look(Vector3(0.0, 26.0, -34.0), Vector3(0.0, 0.0, 2.0), 55.0)
	await shot("s03_vale_meio_dia", 20)
	set_hour(21.0)
	await shot("s04_vale_noite", 20)
	cam.make_current()
	await shot("s02_noite", 20)

func combat() -> void:
	get_window().size = Vector2i(1280, 720)
	await start()
	world.get_node("Territory").max_health = 100000
	world.get_node("Territory").health = 100000
	for slot_name in ["SlotRuinMeadow", "SlotWestInner", "SlotEastInner"]:
		world.get_node("DefenseSlots/" + slot_name).build()
	var team := allies(2)
	for i in team.size():
		team[i].set_physics_process(true)
		team[i].global_position = Vector3(-1.5 + i * 3.0, 0.5, -3.0)
	world.get_node("WaveManager").base_enemy_count = 10
	world.get_node("WaveManager").spawn_interval = 0.6
	await put_player(Vector3(0.0, 0.1, -1.0))
	DayNightManager.gameplay_enabled = true
	DayNightManager.start_night()
	for i in 60 * 11:
		await get_tree().physics_frame
	await shot("k01_onda_hud", 2)
	look(Vector3(5.0, 6.5, 3.0), Vector3(0.0, 0.5, -3.0), 52.0)
	await shot("k02_combate_perto", 2)
	DayNightManager.gameplay_enabled = false

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=").trim_suffix("/") + "/"
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(out)
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await wait(5)
	if wants("menu"): await menus()
	if wants("inv"): await inventory()
	if wants("char"): await characters()
	if wants("biome"): await biomes()
	if wants("combat"): await combat()
	print("[O4] capturas em " + out)
	app.show_menu()
	get_tree().quit.call_deferred()
