extends Node

# Spec 019: capturas de criaturas e combate (nao e teste). Jogo real, congelado
# em cada foto: selvagem domesticavel (anel jade), canalizacao em andamento,
# aliado em FICAR, guardiao, invasores noturnos, torre mirando com o disparo
# em voo, lampejo de dano, eliminacao e conclusao da domesticacao. Exige janela.
# Uso: res://tools/creature_capture.tscn -- --output=<pasta>
var out := "user://creature-capture/"
var app
var visual
var world: Node3D
var player: CharacterBody3D
var cam: Camera3D
var extra: Camera3D

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

func shot(label: String, frames := 20) -> void:
	if get_tree().paused:
		app.resume_game()
	await wait(frames)
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(out + label + ".png")
	print("[019] %s  relogio %s" % [label, DayNightManager.clock_text()])

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
	world = app.world
	visual = world.get_node("DayNightVisual")
	player = world.get_node("Player")
	player.set_process_unhandled_input(false)
	player.set_physics_process(false)
	player._invulnerable_left = INF
	cam = player.get_node("StrategicCamera")
	cam.follow_smoothing = 0.0
	extra = Camera3D.new()
	world.add_child(extra)
	var channel = player.get_node("DomesticationChannel")
	channel.set_physics_process(false) # progresso posto a mao abaixo
	var wild: Array = world.get_node("EncounterSpawner").encounters
	# Noite 1 real: a onda cria os invasores (depois o relogio e posto a mao).
	DayNightManager.start_night()
	await wait(60 * 6)
	var foes: Array = world.get_node("WaveManager")._active_wave_enemies.keys()
	DayNightManager.gameplay_enabled = false
	# Selvagem comum ferido (elegivel) para a domesticacao.
	var tame: CharacterBody3D = load("res://scenes/enemies/wild_dino.tscn").instantiate()
	world.add_child(tame)
	tame.take_damage(60.0) # 80 -> 20: elegivel
	# --- Leitura dos tipos de criatura, dia ---------------------------------------
	pose(wild[0], Vector3(-4.5, 0.5, -6.5), PI / 2.0) # guardiao
	pose(tame, Vector3(-1.5, 0.5, -6.5), PI / 2.0) # selvagem domesticavel
	pose(foes[0], Vector3(1.5, 0.5, -6.5), PI / 2.0) # invasor
	wild[1].domesticate()
	pose(wild[1], Vector3(4.5, 0.5, -6.5), PI / 2.0)
	wild[1].ally_state = 1 # FICAR
	wild[1]._update_label()
	for i in range(1, foes.size()):
		pose(foes[i], Vector3(-30.0 - i * 3.0, 0.5, 40.0), 0.0)
	player.global_position = Vector3(0.0, 0.1, -1.0)
	look(Vector3(0.0, 3.4, -0.5), Vector3(0.0, 0.9, -6.5), 55.0)
	set_hour(12.0)
	await shot("30_tipos_1200")
	set_hour(21.0)
	await shot("30_tipos_2100")
	cam.make_current()
	set_hour(12.0)
	await shot("31_tipos_jogo_1200")
	# --- Canalizacao da domesticacao (60%) ------------------------------------------
	player.global_position = Vector3(-1.5, 0.1, -4.5)
	channel._target = tame
	channel._progress = 1.2
	tame.set_prompt("Domesticando... 1.2 / 2.0 s")
	look(Vector3(-0.2, 3.0, -1.6), Vector3(-1.5, 0.6, -6.5), 50.0)
	await shot("32_canalizando_1200")
	cam.make_current()
	await shot("32_canalizando_jogo_1200")
	# Conclusao: aneis jade e lascas.
	channel._progress = 0.0
	channel._target = null
	tame.domesticate()
	look(Vector3(-0.2, 3.0, -1.6), Vector3(-1.5, 0.6, -6.5), 50.0)
	await shot("33_domesticado_1200", 9)
	# --- Combate a noite: torre mirando, disparo em voo, lampejo -------------------
	set_hour(21.0)
	var slot = world.get_node("DefenseSlots/SlotRuinMeadow")
	var tower = slot.build()
	await wait(5)
	pose(foes[0], Vector3(-1.0, 0.5, 3.0), 0.0)
	tower.target = foes[0]
	player.global_position = Vector3(-2.0, 0.1, 1.0)
	cam.make_current()
	await shot("34_torre_alvo_2100")
	tower._fire(foes[0])
	await shot("35_disparo_2100", 6)
	foes[0].get_node("Visual").flash()
	await shot("36_impacto_2100", 3)
	look(Vector3(1.5, 2.6, 7.0), Vector3(-1.0, 0.8, 3.0), 50.0)
	foes[0].get_node("Visual").flash()
	await shot("36_impacto_perto_2100", 3)
	# Eliminacao (so o efeito; o inimigo e escondido logo apos).
	foes[0].get_node("Visual").defeated()
	foes[0].hide()
	await shot("37_eliminacao_2100", 8)
	print("[019] capturas em " + out)
	app.show_menu()
	get_tree().quit.call_deferred()
