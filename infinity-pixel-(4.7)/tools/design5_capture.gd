extends Node

# Design Overhaul 5.0: capturas comparativas (nao e teste). Roda igual antes e
# depois da reforma, com os mesmos enquadramentos: menu, HUD (3 resolucoes e
# painel da torre), torres L1/L2/L3 de perto, as tres lado a lado, torre de dia,
# de noite e disparando, inventario, Refugio, seis torres e onda noturna.
# Jogo real, congelado em cada foto (a onda roda de verdade antes da foto).
# Exige janela.
# Uso: res://tools/design5_capture.tscn -- --output=<pasta> [--only=menu,hud,tower,world]
var out := "user://design5-capture/"
var only := ""
var app
var world: Node3D
var player: CharacterBody3D
var extra: Camera3D

const MEADOW := Vector3(-3.5, 0.0, 1.0) # SlotRuinMeadow (layout aprovado na 5.0)

func wait(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func shot(label: String, frames := 20) -> void:
	if app.screen == "paused":
		app.resume_game()
	await wait(frames)
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png("%s%s.png" % [out, label])
	print("[D5] %s %dx%d" % [label, get_window().size.x, get_window().size.y])

func wants(part: String) -> bool:
	return only == "" or part in only.split(",")

func set_hour(h: float) -> void:
	if h >= 8.0 and h < 18.0:
		DayNightManager.state = DayNightManager.State.DAY
		DayNightManager.phase_elapsed = (h - 8.0) / 10.0 * DayNightManager.day_duration_seconds
	else:
		var hn := h + 24.0 if h < 12.0 else h
		DayNightManager.state = DayNightManager.State.NIGHT
		DayNightManager.phase_elapsed = (hn - 18.0) / 12.0 * DayNightManager.night_duration_seconds
	world.get_node("DayNightVisual").snap()

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
	player.set_physics_process(false)
	player._invulnerable_left = INF
	player.get_node("StrategicCamera").follow_smoothing = 0.0
	for dino in world.get_node("EncounterSpawner").encounters:
		if is_instance_valid(dino): dino.set_physics_process(false)
	DayNightManager.gameplay_enabled = false
	extra = Camera3D.new()
	world.add_child(extra)
	set_hour(10.5)

func put_player(p: Vector3, yaw := 0.0) -> void:
	player.global_position = p
	player.velocity = Vector3.ZERO
	player.rotation.y = yaw
	await wait(3)

func game_camera() -> void:
	player.get_node("StrategicCamera").make_current()

func slot(slot_name: String) -> Node3D:
	return world.get_node("DefenseSlots/" + slot_name)

func tower_at(slot_name: String, level: int) -> Node3D:
	var s := slot(slot_name)
	if s.is_empty():
		s.build()
	while s.tower.level < level:
		s.tower.upgrade()
	return s.tower

# --- Menu ----------------------------------------------------------------------
func menus() -> void:
	for size in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		get_window().size = size
		app.show_menu()
		await shot("01_menu_%d" % size.x, 150)
	get_window().size = Vector2i(1920, 1080)
	app.show_settings(app._close_overlay)
	await shot("01b_configuracoes_1920")
	app._close_overlay()
	app.show_info(true)
	await shot("01c_creditos_1920")
	app._close_overlay()
	app.show_info(false)
	await shot("01d_controles_1920")
	app._close_overlay()
	await start()
	app.pause_game()
	await wait(20)
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png("%s01e_pausa_1920.png" % out)
	app.resume_game()
	DayNightManager.report_defeat()
	await shot("01f_derrota_1920", 60)

# --- HUD -----------------------------------------------------------------------
func hud() -> void:
	for size in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		get_window().size = size
		await start()
		var stock = world.get_node("ResourceStock")
		stock.add(&"wood", 46)
		stock.add(&"stone", 23)
		world.get_node("DefenseEconomy").add_points(25)
		await put_player(Vector3(0.0, 0.1, -6.0))
		game_camera()
		await shot("02_hud_dia_%d" % size.x, 30)
		# Painel contextual da torre (L2 construida ao lado do Player).
		tower_at("SlotRuinMeadow", 2)
		await put_player(MEADOW + Vector3(1.6, 0.1, 1.2))
		await shot("02b_hud_torre_%d" % size.x, 30)
	get_window().size = Vector2i(1920, 1080)

# --- Torres --------------------------------------------------------------------
func towers() -> void:
	get_window().size = Vector2i(1920, 1080)
	await start()
	app.hud.visible = false # fotos das torres sem a HUD por cima (antes e depois)
	set_hour(11.0)
	await put_player(Vector3(0.0, 0.1, -10.0))
	# Mesmo enquadramento para os tres niveis (3/4, um pouco acima).
	var eye := MEADOW + Vector3(4.4, 3.6, 7.8)
	var aim := MEADOW + Vector3(0, 1.85, 0)
	for level in [1, 2, 3]:
		tower_at("SlotRuinMeadow", level)
		look(eye, aim, 42.0)
		await shot("0%d_torre_nivel%d" % [level + 4, level], 40)
	# As tres lado a lado: torres de vitrine na estrada (so visual, sem slot).
	var DefenseTower = load("res://scenes/world/defense_tower.gd")
	var show := []
	for i in 3:
		var holder := Node3D.new()
		world.add_child(holder)
		holder.global_position = Vector3(-3.4 + 3.4 * i, 0.0, 9.0)
		var t = DefenseTower.new()
		holder.add_child(t)
		t.position.y = 0.2
		t.set_physics_process(false)
		while t.level < i + 1:
			t.upgrade()
		show.append(holder)
	look(Vector3(0.0, 4.0, 16.2), Vector3(0.0, 1.8, 9.0), 46.0)
	await shot("08_tres_niveis_lado_a_lado", 60)
	set_hour(21.5)
	await shot("08b_tres_niveis_noite", 40)
	for h in show:
		h.queue_free()
	# Torre (L3) de dia e de noite, com o jogo enquadrando de perto.
	set_hour(13.0)
	look(eye, aim, 42.0)
	await shot("09_torre_dia", 30)
	set_hour(21.5)
	await shot("10_torre_noite", 30)
	# Disparo: invasor parado no alcance; foto no meio do voo da lasca. So nesta
	# foto o tempo anda a 0,2x (a lasca voa em 0,18 s), igual antes e depois.
	DayNightManager.gameplay_enabled = true
	var foe = load("res://scenes/enemies/wild_dino.tscn").instantiate()
	world.add_child(foe)
	foe.add_to_group("wave_enemy")
	foe.global_position = MEADOW + Vector3(4.2, 0.5, 2.6)
	foe.set_physics_process(false)
	set_hour(19.5)
	look(MEADOW + Vector3(1.8, 3.4, 9.6), MEADOW + Vector3(2.0, 1.7, 1.2), 50.0)
	var t3 = slot("SlotRuinMeadow").tower
	t3._cooldown = 0.6
	Engine.time_scale = 0.2
	var waited := 0
	while t3._cooldown < t3.stats().interval - 0.01 and waited < 600:
		await get_tree().physics_frame
		waited += 1
	await shot("11_torre_disparo", 25) # ~0,08 s de jogo: lasca no meio do voo
	Engine.time_scale = 1.0
	DayNightManager.gameplay_enabled = false
	foe.queue_free()

# --- Mundo, inventario, Refugio, seis torres e onda noturna --------------------
func world_views() -> void:
	get_window().size = Vector2i(1920, 1080)
	await start()
	var stock = world.get_node("ResourceStock")
	stock.add(&"wood", 46)
	stock.add(&"stone", 23)
	await put_player(Vector3(0.0, 0.1, -10.0))
	game_camera()
	app.toggle_inventory()
	await shot("12_inventario", 30)
	if app.hud.has_method("show_inventory_tab"):
		app.hud.show_inventory_tab("companions")
		await shot("12b_inventario_companheiros", 20)
		app.hud.show_inventory_tab("resources")
	app.toggle_inventory()
	set_hour(16.5)
	look(Vector3(6.5, 5.2, -5.0), Vector3(0.0, 1.3, -14.5), 50.0)
	await shot("13_refugio", 30)
	set_hour(11.0)
	var levels := {"SlotWestInner": 1, "SlotWestOuter": 2, "SlotRuinMeadow": 3, "SlotRuinArch": 2, "SlotEastInner": 3, "SlotEastOuter": 1}
	for n in levels:
		tower_at(n, levels[n])
	await put_player(Vector3(0.0, 0.1, -3.0))
	game_camera()
	await shot("14_gameplay_varias_torres", 30)
	look(Vector3(0.0, 30.0, -26.0), Vector3(0.0, 0.0, 1.0), 58.0)
	await shot("14b_vale_seis_torres", 30)
	# Onda noturna real (10 invasores), Refugio sem risco de derrota na foto.
	world.get_node("Territory").max_health = 100000
	world.get_node("Territory").health = 100000
	world.get_node("WaveManager").base_enemy_count = 10
	world.get_node("WaveManager").spawn_interval = 0.6
	await put_player(Vector3(0.0, 0.1, 2.0))
	game_camera()
	DayNightManager.gameplay_enabled = true
	DayNightManager.start_night()
	for i in 60 * 11:
		await get_tree().physics_frame
	await shot("15_onda_noturna", 2)
	look(Vector3(0.0, 30.0, -26.0), Vector3(0.0, 0.0, 1.0), 58.0)
	await shot("15b_onda_noturna_alto", 2)
	DayNightManager.gameplay_enabled = false

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=").strip_edges()
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	if not out.ends_with("/"): out += "/"
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1920, 1080)
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await wait(5)
	if wants("menu"): await menus()
	if wants("hud"): await hud()
	if wants("tower"): await towers()
	if wants("world"): await world_views()
	print("[D5] capturas em " + out)
	app.show_menu()
	get_tree().quit.call_deferred()
