extends Node

# Spec 017B/020: capturas da HUD (nao e teste) em 1280x720 e 1920x1080, nas
# mesmas situacoes, para comparar antes x depois. Jogo real, congelado em cada
# foto. Exige janela. Uso: res://tools/hud_capture.tscn -- --output=<pasta> --label=<antes|depois>
var out := "user://hud-capture/"
var label := "atual"
var app
var world: Node3D
var player: CharacterBody3D

func wait(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func shot(name: String, frames := 12) -> void:
	if get_tree().paused:
		app.resume_game()
	await wait(frames)
	RenderingServer.force_draw(false)
	var size := get_window().size
	get_viewport().get_texture().get_image().save_png("%s%s_%s_%d.png" % [out, label, name, size.x])
	print("[HUD] %s %dx%d" % [name, size.x, size.y])

func set_hour(h: float) -> void:
	if h >= 8.0 and h < 18.0:
		DayNightManager.state = DayNightManager.State.DAY
		DayNightManager.phase_elapsed = (h - 8.0) / 10.0 * DayNightManager.day_duration_seconds
	else:
		var hn := h + 24.0 if h < 12.0 else h
		DayNightManager.state = DayNightManager.State.NIGHT
		DayNightManager.phase_elapsed = (hn - 18.0) / 12.0 * DayNightManager.night_duration_seconds
	world.get_node("DayNightVisual").snap()

func put_player(p: Vector3) -> void:
	player.global_position = p
	player.velocity = Vector3.ZERO
	await wait(3)

func series(size: Vector2i) -> void:
	get_window().size = size
	await wait(10)
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
	set_hour(10.5)
	var stock = world.get_node("ResourceStock")
	# 1. Dia, comeco da partida (recursos zerados).
	await shot("01_dia")
	# 2. Inventario aberto sem recursos suficientes (custos em falta).
	stock.add(&"wood", 12)
	stock.add(&"stone", 4)
	app.toggle_inventory()
	await shot("02_inventario_falta")
	app.toggle_inventory()
	# 3. Menu de construcao com recursos suficientes.
	stock.add(&"wood", 40)
	stock.add(&"stone", 20)
	app.toggle_build_menu()
	await shot("03_construir")
	app.toggle_build_menu()
	# 4. Posicionamento invalido (fora da area).
	var placer = world.get_node("BuildPlacer")
	placer.follow_cursor = false
	await put_player(Vector3(4.0, 0.1, -10.0))
	placer.begin(&"campfire")
	placer.move_ghost_to(Vector3(-6.0, 0, -9.0))
	await shot("04_posicionar_invalido")
	placer.move_ghost_to(Vector3(5.0, 0, -12.5))
	await shot("05_posicionar_valido")
	placer.cancel()
	# 6. Perto de uma arvore coletavel.
	await put_player(Vector3(-14.0, 0.1, 18.0))
	await shot("06_coleta")
	# 7. Perto de um ponto de defesa.
	await put_player(Vector3(-9.6, 0.1, -4.4))
	await shot("07_ponto_defesa")
	# 8. Vida baixa.
	player.current_hp = 35.0
	player.health_changed.emit(35.0, player.max_hp)
	await put_player(Vector3(0.0, 0.1, -10.0))
	set_hour(17.4)
	await shot("08_entardecer_vida_baixa")
	# 9. Noite com onda (inicio).
	set_hour(12.0)
	DayNightManager.gameplay_enabled = true
	DayNightManager.start_night()
	await wait(150)
	DayNightManager.gameplay_enabled = false
	set_hour(21.0)
	await shot("09_noite_onda", 4)

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=").trim_suffix("/") + "/"
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
	DirAccess.make_dir_recursive_absolute(out)
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	await series(Vector2i(1280, 720))
	await series(Vector2i(1600, 900))
	await series(Vector2i(1920, 1080))
	print("[HUD] capturas em " + out)
	app.show_menu()
	get_tree().quit.call_deferred()
