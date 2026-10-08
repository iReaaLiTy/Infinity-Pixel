extends Node
var app: Node
var checks: Array[String] = []
var failures: Array[String] = []
# Padrão em user://: rodar a suíte não sobrescreve a evidência versionada da AC1
# (docs/ac1/evidence). Evidência intencional: --evidence-dir=<pasta> ou a
# variável INFINITY_PIXEL_EVIDENCE_DIR (tools/test_ac1.ps1 já passa a pasta).
var evidence := "user://ac1-evidence/" if OS.get_environment("INFINITY_PIXEL_EVIDENCE_DIR").is_empty() else OS.get_environment("INFINITY_PIXEL_EVIDENCE_DIR").trim_suffix("/") + "/"

func check(ok: bool, title: String) -> void:
	(checks if ok else failures).append(title)
	print(("PASS: " if ok else "FAIL: ") + title)

func wait(seconds: float = .1) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(evidence + name + ".png")

func key_e(pressed: bool) -> void:
	if pressed: Input.action_press("domesticate")
	else: Input.action_release("domesticate")
	var ev := InputEventKey.new()
	ev.keycode = KEY_E
	ev.physical_keycode = KEY_E
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _ready() -> void:
	# Optional external destination preserves historical AC1 evidence during regressions.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="):
			evidence = argument.trim_prefix("--evidence-dir=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(evidence)
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await wait(.5)
	await shot("01_menu_1280")
	DayNightManager.start_night()
	check(DayNightManager.is_day() and not DayNightManager.gameplay_enabled, "N no menu bloqueado")
	get_window().size = Vector2i(1920,1080)
	await wait(.2)
	await shot("02_menu_1920")
	get_window().size = Vector2i(1280,720)
	await wait(.1)
	if DisplayServer.get_name() != "headless":
		var play_button: Button
		for button in app.ui.find_children("*", "Button", true, false):
			if button.text.to_upper() == "JOGAR":
				play_button = button
				break
		if play_button != null:
			for pressed in [true, false]:
				var menu_click := InputEventMouseButton.new()
				menu_click.button_index = MOUSE_BUTTON_LEFT
				menu_click.pressed = pressed
				menu_click.position = play_button.get_global_rect().get_center()
				get_viewport().push_input(menu_click, true)
			await wait(.1)
		check(app.screen == "playing", "Botao Jogar do menu responde ao clique")
	if app.screen != "playing":
		app.start_game()
	await wait(.3)
	var world = app.world
	var player = world.get_node("Player")
	var encounter = world.get_node("EncounterSpawner").current_encounter
	var channel = player.get_node("DomesticationChannel")
	var base = world.get_node("Territory")
	check(encounter != null and encounter.territorial, "Encontro diurno sem T e territorial")
	await shot("03_dia")
	await wait(.5)
	check(base.health == 100, "Base preservada durante preparação")
	# Move into real Area3D overlap; cooldown and damage remain game values.
	encounter.set_physics_process(false)
	player.global_position = encounter.global_position + Vector3(0,0,1.5)
	player.rotation.y = 0
	await wait(.1)
	if DisplayServer.get_name() != "headless":
		# Spec 007: a camera e estrategica e fixa; o mouse so mira.
		var camera: Camera3D = player.get_node("StrategicCamera")
		var cam_basis := camera.global_basis
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(100, 0)
		get_viewport().push_input(motion, true)
		await wait(.05)
		check(camera.global_basis.is_equal_approx(cam_basis), "Movimento do mouse nao gira a camera estrategica")
		# A mira segue o cursor real: leva o cursor ao alvo antes do clique,
		# como acontece no jogo, e depois desliga a mira para o resto da suite.
		# Espera a camera suavizada alcancar o teleporte do jogador antes de mirar.
		await wait(1.5)
		var target_pos := camera.unproject_position(encounter.global_position)
		Input.warp_mouse(target_pos)
		await wait(.1)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = target_pos
		get_viewport().push_input(click, true)
		await wait(.1)
		check(encounter.hp == 65, "Clique esquerdo aciona ataque por evento de input (15, Spec 013C)")
		player.set("_aim_active", false)
		player.rotation.y = 0
		encounter.hp = 80
		encounter._update_label()
		await wait(.82)
	for i in range(4): # Spec 013C: golpe de 15 -> 80, 65, 50, 35, 20
		player.global_position = encounter.global_position + Vector3(0,0,1.5)
		await wait(.08)
		player._try_attack()
		await wait(.82)
	check(encounter.hp == 20, "Quatro ataques (15) deixam 20/80 HP")
	key_e(true)
	await wait(.6)
	check(channel.get_progress() > .1, "E inicia canalização")
	key_e(false)
	await wait(.1)
	check(channel.get_progress() == 0 and is_instance_valid(encounter), "Soltar E cancela sem remover criatura")
	key_e(true)
	await wait(.5)
	app.pause_game()
	await wait(.1)
	check(channel.get_progress() == 0 and not encounter.is_being_domesticated, "Pausa cancela canalização e libera alvo")
	key_e(false)
	var before = player.global_position
	DayNightManager.start_night()
	check(DayNightManager.is_day() and player.global_position == before, "N e movimento bloqueados na pausa")
	await shot("04_pausa")
	app.resume_game()
	key_e(true)
	await wait(.5)
	var locked = channel._target
	# Another eligible target closer must not steal an in-progress channel.
	var other = load("res://scenes/enemies/wild_dino.tscn").instantiate()
	other.territorial = true
	other.position = player.global_position + Vector3(1,0,0)
	world.add_child(other)
	other.hp = 20
	other._update_label()
	other.set_physics_process(false)
	await wait(.3)
	check(channel._target == locked and channel.get_progress() > .3, "Alvo permanece travado com outro elegível próximo")
	await shot("05_domesticacao")
	await wait(1.3)
	key_e(false)
	check(encounter.is_domesticated and encounter.hp == 80 and encounter.ally_state == 0, "Conversão restaura a vida (80, Spec 013C) e inicia seguir")
	check(encounter.get_node("Visual/Collar").visible, "Domesticação atualiza visual do aliado")
	other.queue_free()
	await wait(.1)
	player._try_attack()
	check(encounter.hp == 80, "Ataque do jogador não fere aliado")
	encounter.set_physics_process(true)
	player.global_position += Vector3(0,0,5)
	var distance_before: float = encounter.global_position.distance_to(player.global_position)
	await wait(.6)
	check(encounter.global_position.distance_to(player.global_position) < distance_before, "Aliado segue fisicamente")
	player.global_position = encounter.global_position + Vector3(0,0,1)
	Input.action_press("command_stay")
	await wait(.06)
	Input.action_release("command_stay")
	check(encounter.ally_state == 1, "F posiciona aliado em ficar")
	await shot("06_aliado")
	var enemy = load("res://scenes/enemies/wild_dino.tscn").instantiate()
	enemy.territorial = true
	enemy.position = encounter.global_position + Vector3(1.4,0,0)
	world.add_child(enemy)
	enemy.set_physics_process(false)
	await wait(1.1)
	check(enemy.hp < 80, "Aliado em ficar detecta e ataca hostil")
	enemy.queue_free()
	await wait(.1)
	# Run the actual wave timers, neutralizing enemies after their real spawns.
	player.global_position = Vector3(17,0,-17)
	encounter.global_position = Vector3(-17,0,-17)
	encounter.set_physics_process(false)
	DayNightManager.start_night()
	await wait(.2)
	var wave = world.get_node("WaveManager")
	check(wave._spawned_count == 1, "Primeiro spawn no início da noite")
	var times: Array[float] = []
	var elapsed := 0.0
	while elapsed < 5.1:
		for d in wave._active_wave_enemies.keys():
			times.append(elapsed)
			if times.size() == 1:
				d.take_damage(60)
				d.domesticate()
				d.take_damage(100)
				check(wave._active_wave_enemies.is_empty(), "Domesticação e morte posterior contam uma neutralização")
			else: d.take_damage(80)
		await wait(.1)
		elapsed += .1
		if times.size()<3: check_no_early_victory()
	check(times.size()==3 and times[1]-times[0]>1.5 and times[2]-times[1]>1.5, "Três spawns escalonados em aproximadamente 2 segundos")
	# Spec 008: vencer a noite nao abre modal nem pausa; o jogo segue no dia.
	check(app.screen == "playing" and not get_tree().paused and DayNightManager.is_day(), "Vitória após três ameaças volta ao dia sem pausar")
	check(not is_instance_valid(app.overlay), "Vitória não abre modal")
	check(is_instance_valid(encounter), "Vitória preserva aliado existente")
	await shot("08_vitoria")
	await wait(.15)
	check(world.get_node("EncounterSpawner").is_encounter_wild(), "Novo dia repõe somente encontro necessário")
	# Defeat and two restarts exercise autoload / audio / scene lifetime.
	for attempt in range(2):
		app.world.get_node("Territory").take_damage(100)
		await wait(.1)
		check(app.screen=="defeat" and DayNightManager.is_game_over, "Derrota real da base — tentativa %d" % attempt)
		if attempt==0: await shot("09_derrota")
		app.start_game()
		await wait(.2)
		check(not DayNightManager.is_game_over and app.world.get_node("Territory").health==100, "Reinício limpa estado — tentativa %d" % attempt)
	# Regression: losing target, invalid non-domesticable variant.
	player=app.world.get_node("Player")
	encounter=app.world.get_node("EncounterSpawner").current_encounter
	encounter.set_physics_process(false)
	encounter.take_damage(60)
	player.global_position=encounter.global_position+Vector3(0,0,1.5)
	key_e(true)
	await wait(.4)
	player.global_position+=Vector3(10,0,0)
	await wait(.1)
	check(player.get_node("DomesticationChannel").get_progress()==0 and not encounter.is_being_domesticated, "Sair do alcance cancela e solta alvo")
	key_e(false)
	var carno=load("res://scenes/enemies/carnotauro.tscn").instantiate()
	app.world.add_child(carno)
	carno.take_damage(60)
	check(not carno.can_be_domesticated(), "Carnotauro enfraquecido continua não domesticável")
	carno.queue_free()
	# Same-frame last threat / base death; deferred victory must lose.
	DayNightManager.start_night()
	wave=app.world.get_node("WaveManager")
	await wait(.1)
	wave._spawned_count=wave.enemy_count # Spec 013: noite 2 tem 4 inimigos
	for d in wave._active_wave_enemies.keys(): d.take_damage(80)
	app.world.get_node("Territory").take_damage(100)
	await wait(.1)
	check(app.screen=="defeat", "Base e último inimigo no mesmo quadro: derrota tem prioridade")
	app.show_menu()
	app.start_game()
	await wait(.4)
	check(get_tree().get_nodes_in_group("audio_director").size()==1, "Menu→jogar mantém um único diretor de áudio")
	check(DayNightManager.day_started.get_connections().size()==3, "Reinícios não acumulam conexões de dia")
	await wait(1)
	check(app.audio.music.playing and app.audio.music.stream.loop_mode==1, "Música real tocando em loop")
	app.audio.set_muted(true)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Silenciar atua no bus real")
	app.audio.set_muted(false)
	app.show_menu()
	var report := {"passed": checks, "failed": failures, "engine": Engine.get_version_info(), "display": DisplayServer.get_name(), "note": "Testes automatizados em execução; não equivalem a aprovação humana de jogabilidade ou áudio."}
	var f=FileAccess.open(evidence+"acceptance_"+DisplayServer.get_name()+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"  "))
	print("AC1 RESULTS: %d passed; %d failed" % [checks.size(),failures.size()])
	await wait(.1)
	get_tree().quit(0 if failures.is_empty() else 1)

func check_no_early_victory() -> void:
	if app.victory_count > 0 and not failures.has("Vitória prematura"):
		failures.append("Vitória prematura")
