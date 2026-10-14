extends Node

# World 6.0: capturas reais (nao e teste). Roda igual antes e depois da
# atualizacao, com os mesmos enquadramentos: menu, inventario, HUD das
# criaturas (aliado cheio, ferido, sendo curado), pegadas, visao geral, as
# quatro regioes, cachoeira, vulcao, transicoes, Refugio e onda noturna.
# Posicoes fixas aqui (a copia "antes" nao tem o modulo de biomas). Exige janela.
# Uso: res://tools/world6_capture.tscn -- --output=<pasta> [--only=menu,inv,dino,prints,map,night]
var out := "user://world6-capture/"
var only := ""
var app
var world: Node3D
var player: CharacterBody3D
var extra: Camera3D

func wait(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func shot(label: String, frames := 20) -> void:
	if app.screen == "paused":
		app.resume_game()
	await wait(frames)
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png("%s%s.png" % [out, label])
	print("[W6] %s" % label)

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
	DayNightManager.clock_hold = true
	extra = Camera3D.new()
	extra.far = 220.0
	world.add_child(extra)
	set_hour(10.5)

func put_player(p: Vector3) -> void:
	player.global_position = p
	player.velocity = Vector3.ZERO
	await wait(3)

func game_camera() -> void:
	player.get_node("StrategicCamera").make_current()

func ally_at(p: Vector3) -> Node3D:
	var d = load("res://scenes/enemies/wild_dino.tscn").instantiate()
	world.add_child(d)
	d.global_position = p
	d.set_physics_process(false)
	d.domesticate()
	return d

func menus() -> void:
	for size in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		get_window().size = size
		app.show_menu()
		await shot("01_menu_%d" % size.x, 150)
	get_window().size = Vector2i(1920, 1080)

func inventory() -> void:
	for size in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		get_window().size = size
		await start()
		world.get_node("ResourceStock").add(&"wood", 46)
		world.get_node("ResourceStock").add(&"stone", 23)
		await put_player(Vector3(0, 0.1, -10))
		var a := ally_at(Vector3(-2, 0.5, -12))
		a.hp = 47.0
		a._update_label()
		ally_at(Vector3(2, 0.5, -12)).ally_state = 1
		game_camera()
		app.toggle_inventory()
		await shot("02_inventario_%d" % size.x, 30)
		if app.hud.has_method("show_inventory_tab"):
			app.hud.show_inventory_tab("companions")
			await shot("02b_inventario_companheiros_%d" % size.x, 20)
			app.hud.show_inventory_tab("build")
			await shot("02c_inventario_construcoes_%d" % size.x, 20)
		app.toggle_inventory()
	get_window().size = Vector2i(1920, 1080)

func dino_hud() -> void:
	await start()
	await put_player(Vector3(0, 0.1, -6))
	var a := ally_at(Vector3(1.6, 0.5, -6.8))
	game_camera()
	look(Vector3(3.2, 3.4, -1.6), Vector3(1.2, 1.2, -6.8), 45.0)
	await shot("03_hud_dinossauro_aliado_cheio", 20)
	a.take_damage(42.0)
	await shot("14b_aliado_ferido", 50)
	var elixir = world.get_node_or_null("JadeElixir")
	if elixir != null:
		elixir.stored = 1
		elixir.use_on(a)
	else:
		a.heal_ally(30.0)
	await shot("16_aliado_curado", 14)
	a.hp = 80.0
	a._update_label()
	await shot("14_aliado_barra_cheia", 60)
	# Varios: selvagem golpeado, guardiao e invasores juntos.
	var foes := []
	for i in 3:
		var f = load("res://scenes/enemies/wild_dino.tscn").instantiate()
		world.add_child(f)
		f.global_position = Vector3(-3.0 + i * 1.6, 0.5, -9.5)
		f.set_physics_process(false)
		f.add_to_group("wave_enemy")
		if f.has_node("Visual"): f.get_node("Visual").set_night_threat()
		f.take_damage(20.0 * i)
		f._update_label()
		foes.append(f)
	game_camera()
	await shot("03b_hud_dinossauros_varios", 30)
	for f in foes: f.queue_free()

func footprints() -> void:
	await start()
	game_camera()
	await put_player(Vector3(-2, 0.1, -4))
	player.set_physics_process(false)
	for i in 70: # anda de verdade (posicao), as pegadas nascem pelo caminho
		player.global_position += Vector3(0.06, 0, -0.04) * 1.5
		player.rotation.y = atan2(-0.06, 0.04)
		await get_tree().physics_frame
	look(player.global_position + Vector3(2.2, 3.0, 3.6), player.global_position + Vector3(-1.6, 0.0, 0.8), 48.0)
	await shot("13_pegadas_player", 4)

func map_views() -> void:
	await start()
	set_hour(11.0)
	# [rotulo, camera de, para, fov]
	var views := [
		["04_visao_geral_mapa", Vector3(0, 62, 28), Vector3(0, 0, -6), 62.0],
		["20_quatro_biomas", Vector3(-8, 46, 40), Vector3(0, 0, -10), 70.0],
		["05_floresta", Vector3(-14, 7.5, 30), Vector3(-22, 0.5, 16), 55.0],
		["06_pedra", Vector3(18, 8.5, 2), Vector3(26, 0.5, 12), 55.0],
		["07_agua", Vector3(-10, 8, -10), Vector3(-23, 0.5, -22), 55.0],
		["08_cachoeira", Vector3(-15, 6, -24), Vector3(-32, 4.0, -31), 55.0],
		["09_vulcao", Vector3(4, 10, -22), Vector3(13, 12, -66), 55.0],
		["10_regiao_vulcanica", Vector3(8, 9, -24), Vector3(14, 0.5, -36), 58.0],
		["11_transicao_floresta_agua", Vector3(-14, 9, 0), Vector3(-26, 0.5, -12), 58.0],
		["12_transicao_pedra_vulcao", Vector3(18, 9, -14), Vector3(24, 0.5, -30), 58.0],
		["18_refugio_mapa_expandido", Vector3(0, 22, 8), Vector3(0, 0, -18), 60.0],
	]
	for v in views:
		look(v[1], v[2], v[3])
		await shot(v[0], 30)
	await put_player(Vector3(0, 0.1, -3))
	game_camera()
	await shot("04b_gameplay_dia", 20)

func night_wave() -> void:
	await start()
	world.get_node("Territory").max_health = 100000
	world.get_node("Territory").health = 100000
	for slot in world.get_node("DefenseSlots").get_children():
		slot.build()
	world.get_node("WaveManager").base_enemy_count = 10
	world.get_node("WaveManager").spawn_interval = 0.6
	await put_player(Vector3(0, 0.1, 2))
	game_camera()
	DayNightManager.clock_hold = false
	DayNightManager.gameplay_enabled = true
	DayNightManager.start_night()
	for i in 60 * 11:
		await get_tree().physics_frame
	await shot("17_onda_noturna", 2)
	look(Vector3(0, 40, 22), Vector3(0, 0, -4), 62.0)
	await shot("17b_onda_noturna_alto", 2)
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
	if wants("inv"): await inventory()
	if wants("dino"): await dino_hud()
	if wants("prints"): await footprints()
	if wants("map"): await map_views()
	if wants("night"): await night_wave()
	print("[W6] capturas em " + out)
	DayNightManager.clock_hold = false
	app.show_menu()
	get_tree().quit.call_deferred()
