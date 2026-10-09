extends Node

# Capturas do inimigo noturno (Spec 019 antecipada), nao e teste. Mesmo cenario
# lado a lado: selvagem diurno (guardiao do territorio), inimigo da onda e um
# aliado domesticado, em varias horas. Jogo congelado em cada foto. Exige janela.
# Uso: res://tools/night_enemy_capture.tscn -- --output=<pasta>
var out := "user://night-enemy/"
var app
var visual

func wait(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func set_hour(h: float) -> void:
	if h >= 8.0 and h < 18.0:
		DayNightManager.state = DayNightManager.State.DAY
		DayNightManager.phase_elapsed = (h - 8.0) / 10.0 * DayNightManager.day_duration_seconds
	else:
		var hn := h + 24.0 if h < 12.0 else h
		DayNightManager.state = DayNightManager.State.NIGHT
		DayNightManager.phase_elapsed = (hn - 18.0) / 12.0 * DayNightManager.night_duration_seconds
	visual.snap()

func shot(label: String) -> void:
	if get_tree().paused:
		app.resume_game()
	await wait(20)
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(out + label + ".png")
	print("[NOITE-VISUAL] %s  relogio %s" % [label, DayNightManager.clock_text()])

func pose(dino: Node3D, at: Vector3, yaw: float) -> void:
	dino.set_physics_process(false)
	dino.velocity = Vector3.ZERO
	dino.global_position = at
	dino.rotation.y = yaw

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	app.start_game()
	await wait(30)
	var world: Node3D = app.world
	visual = world.get_node("DayNightVisual")
	var player: CharacterBody3D = world.get_node("Player")
	player.set_process_unhandled_input(false)
	player.set_physics_process(false)
	player._invulnerable_left = INF
	var cam: Camera3D = player.get_node("StrategicCamera")
	cam.follow_smoothing = 0.0
	var wild: Array = world.get_node("EncounterSpawner").encounters
	DayNightManager.start_night() # a onda e quem cria os inimigos noturnos
	await wait(60 * 6)
	var foes: Array = world.get_node("WaveManager")._active_wave_enemies.keys()
	DayNightManager.gameplay_enabled = false
	# Linha de comparacao no patio do Refugio (perfil, lado a lado).
	pose(wild[0], Vector3(-3.0, 0.5, -8.0), PI / 2.0)
	pose(foes[0], Vector3(0.0, 0.5, -8.0), PI / 2.0)
	wild[1].domesticate() # aliado de referencia (domesticado comum)
	pose(wild[1], Vector3(3.0, 0.5, -8.0), PI / 2.0)
	for i in range(1, foes.size()):
		pose(foes[i], Vector3(-30.0 - i * 3.0, 0.5, 40.0), 0.0) # fora de cena
	player.global_position = Vector3(0.0, 0.1, -3.0)
	await wait(5)
	var extra := Camera3D.new()
	world.add_child(extra)
	extra.global_position = Vector3(0.0, 3.0, -1.8)
	extra.look_at(Vector3(0.0, 0.9, -8.0), Vector3.UP)
	extra.fov = 50.0
	# Camera de perto: selvagem | inimigo noturno | aliado.
	extra.make_current()
	for pair in [[21.0, "perto_2100_noite"], [0.0, "perto_0000_noite"], [5.5, "perto_0530_amanhecer"], [18.5, "perto_1830_anoitecer"], [12.0, "perto_1200_dia"]]:
		set_hour(pair[0])
		await shot(pair[1])
	# Camera do jogo (a leitura real em partida).
	cam.make_current()
	for pair in [[21.0, "jogo_2100_noite"], [0.0, "jogo_0000_noite"], [12.0, "jogo_1200_dia"]]:
		set_hour(pair[0])
		await shot(pair[1])
	# Noite 1 real: os 3 inimigos da onda chegando, pela camera do jogo.
	for i in foes.size():
		pose(foes[i], [Vector3(-4.5, 0.5, -1.0), Vector3(3.5, 0.5, 0.5), Vector3(0.5, 0.5, 2.5)][i % 3], 0.0)
	pose(wild[0], Vector3(-9.0, 0.5, -4.0), PI / 2.0)
	player.global_position = Vector3(0.0, 0.1, -6.0)
	set_hour(21.0)
	await shot("onda_2100_jogo")
	print("[NOITE-VISUAL] capturas em " + out)
	app.show_menu()
	get_tree().quit.call_deferred()
