extends Node

# Gameplay 5.0: capturas reais do jogo para a validacao (nao e teste). Golpe
# frontal (arvore e dinossauro), cinco armadilhas, layout das torres de dia e de
# noite, mochila com o Elixir de Jade, cura com a dica G, tutorial e a previa de
# construcao. O cursor do sistema nunca aparece em capturas do viewport: o estado
# dele e comprovado pelos testes com janela. Exige janela.
# Uso: res://tools/gameplay5_capture.tscn -- --output=<pasta>
var out := "user://gameplay5-capture/"
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
	print("[G5] %s %dx%d" % [label, get_window().size.x, get_window().size.y])

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

func game_camera() -> void:
	player.get_node("StrategicCamera").make_current()

func start(tutorial := false) -> void:
	if tutorial:
		app.start_tutorial()
	else:
		app.start_game()
	await wait(30)
	world = app.world
	player = world.get_node("Player")
	player._invulnerable_left = INF
	player.get_node("StrategicCamera").follow_smoothing = 0.0
	for dino in world.get_node("EncounterSpawner").encounters:
		if is_instance_valid(dino): dino.set_physics_process(false)
	DayNightManager.clock_hold = true
	extra = Camera3D.new()
	world.add_child(extra)
	set_hour(10.5)

## Golpe real (mesmo caminho do clique) e foto no meio do arco.
func strike_at(target: Node3D, from_offset: Vector3, label: String) -> void:
	player.global_position = target.global_position + from_offset
	player.face_toward(target.global_position)
	player._facing_yaw = player.rotation.y
	game_camera()
	await wait(10)
	player.attack_cooldown.stop()
	player._try_attack()
	await shot(label, 4)

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=")
	if not out.ends_with("/"): out += "/"
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1280, 720)
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await wait(10)
	await start()

	# 1-2. Golpe frontal: arvore e dinossauro a frente.
	var tree: Node3D = world.get_node("Collectables/Tree7")
	await strike_at(tree, Vector3(0.4, 0.1, -1.9), "01_golpe_frontal_arvore")
	var dino: Node3D = world.get_node("EncounterSpawner").encounters[0]
	dino.global_position = Vector3(2, 0.5, -4.2)
	dino.rotation.y = 0.0
	await strike_at(dino, Vector3(-1.2, -0.4, 1.4), "02_golpe_frontal_dinossauro")

	# 3. Cinco armadilhas na estrada (uma ja ativada: 2 de 3 pedras acesas).
	var stock = world.get_node("ResourceStock")
	stock.add(&"wood", 600)
	stock.add(&"stone", 600)
	var placer = world.get_node("BuildPlacer")
	placer.follow_cursor = false
	var traps := []
	for z in [3.5, 6.5, 9.5, 16.5, 19.5]:
		if placer.begin(&"trap"):
			placer.move_ghost_to(Vector3(0, 0, z))
			var t = placer.confirm()
			if t != null: traps.append(t)
	var foe = load("res://scenes/enemies/wild_dino.tscn").instantiate()
	world.add_child(foe)
	foe.global_position = Vector3(40, -20, 40)
	foe.set_physics_process(false)
	traps[1]._trigger(foe)
	player.global_position = Vector3(3, 0.1, 2)
	look(Vector3(5.5, 7.5, 1.0), Vector3(0, 0, 9.5), 55.0)
	await get_tree().create_timer(4.0).timeout # avisos de "construida" somem
	await shot("03_cinco_armadilhas", 10)

	# 4-5. Seis torres no novo layout, de dia e de noite (vista do alto).
	for slot in world.get_node("DefenseSlots").get_children():
		slot.build()
	player.global_position = Vector3(0, 0.1, -10)
	look(Vector3(0, 42, -24), Vector3(0, 0, 0), 62.0)
	await shot("04_torres_layout_dia", 40)
	set_hour(21.0)
	await shot("05_torres_layout_noite", 40)
	set_hour(10.5)

	# 6. Mochila -> Companheiros com o Elixir de Jade (Dia 2, recursos de sobra).
	DayNightManager.day_number = 2
	var ally = load("res://scenes/enemies/wild_dino.tscn").instantiate()
	world.add_child(ally)
	ally.set_physics_process(false)
	ally.domesticate()
	ally.hp = 42.0
	ally._update_label()
	ally.global_position = player.global_position + Vector3(1.6, 0.4, -1.0)
	game_camera()
	app.toggle_inventory()
	app.hud.show_inventory_tab("companions")
	await shot("06_mochila_companheiros_elixir", 30)
	world.get_node("JadeElixir").craft()
	app.hud._refresh_inventory()
	await shot("07_mochila_elixir_guardado", 20)
	app.toggle_inventory()

	# 8-9. Dica G com aliado ferido perto e a cura (+38 HP, sem passar do maximo).
	await shot("08_dica_g_aliado_ferido", 30)
	world.get_node("JadeElixir").use_nearest()
	await shot("09_cura_elixir", 12)

	# 10. Previa de construcao (armadilha) com o cursor oculto: a pegada marca o lugar.
	for t in traps:
		t.remove_from_group("spike_trap")
		t.queue_free()
	await wait(2)
	player.global_position = Vector3(2.5, 0.1, -1.0)
	player.face_toward(Vector3(0, 0, 4))
	placer.begin(&"trap")
	placer.move_ghost_to(Vector3(0, 0, 4))
	await shot("10_previa_construcao_armadilha", 20)
	placer.cancel()

	# 11. Tutorial: passo do ataque com o texto novo.
	await start(true)
	# Mesmo caminho do jogador: andar 3 m (passo 1) e chegar ao sinal jade (passo 2).
	DayNightManager.clock_hold = false
	player.global_position += Vector3(3, 0, 0)
	await wait(20)
	player.global_position = app.tutorial.WALK_POINT + Vector3(0, 0.1, 0)
	await wait(40)
	game_camera()
	await shot("11_tutorial_passo_ataque", 20)

	app.show_menu()
	get_tree().quit()
