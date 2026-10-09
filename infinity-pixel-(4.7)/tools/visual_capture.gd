extends Node

# Spec 017A: capturas de comparacao antes x depois (nao e teste). O MESMO roteiro
# roda antes e depois da reforma visual: mesmas cameras, mesmos horarios, mesmas
# posicoes. Hora posta no proprio DayNightManager (como tests/sky_showcase.gd) e
# o jogo congelado em cada foto. Exige janela.
# Uso: res://tools/visual_capture.tscn -- --output=<pasta> [--only=<prefixo>]
const Recipes := preload("res://scenes/world/build_recipes.gd")
const HOURS := [[8.0, "0800"], [12.0, "1200"], [17.5, "1730"], [21.0, "2100"], [0.0, "0000"], [5.5, "0530"]]
var out := "user://017a-views/"
var only := ""
## A/B do toon: --diffuse=lambert troca SO o modo de difusao das pecas novas
## (mesma malha, mesmas cores), para separar o efeito do toon do resto.
var lambert := false
var app
var world: Node3D
var visual
var player: CharacterBody3D
var cam: Camera3D
var extra: Camera3D

func wait(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func shot(label: String) -> void:
	if get_tree().paused:
		app.resume_game() # perda de foco da janela pausa o jogo (main.gd)
	await wait(20) # HUD do relogio atualiza com atraso; o visual ja esta na hora
	if only != "" and not label.begins_with(only):
		return
	RenderingServer.force_draw(false) # desenha mesmo com a janela sem foco
	get_viewport().get_texture().get_image().save_png(out + label + ".png")
	print("[017A] %s  relogio %s  visual %.2f h" % [label, DayNightManager.clock_text(), visual.shown_hour])

func set_hour(h: float) -> void:
	if h >= 8.0 and h < 18.0:
		DayNightManager.state = DayNightManager.State.DAY
		DayNightManager.phase_elapsed = (h - 8.0) / 10.0 * DayNightManager.day_duration_seconds
	else:
		var hn := h + 24.0 if h < 12.0 else h
		DayNightManager.state = DayNightManager.State.NIGHT
		DayNightManager.phase_elapsed = (hn - 18.0) / 12.0 * DayNightManager.night_duration_seconds
	visual.snap()

## Camera do jogo, sem suavizacao: o enquadramento depende so da posicao do Player.
func put_player(p: Vector3) -> void:
	player.global_position = p
	player.velocity = Vector3.ZERO
	cam.make_current()
	await wait(3)

## Camera de diagnostico (nao e a do jogo): para ver os 3 objetos de perto.
func look(from: Vector3, at: Vector3, fov := 50.0) -> void:
	extra.global_position = from
	extra.look_at(at, Vector3.UP)
	extra.fov = fov
	extra.make_current()

func series(prefix: String, hours: Array) -> void:
	for pair in HOURS:
		if pair[1] in hours:
			set_hour(pair[0])
			await shot("%s_%s" % [prefix, pair[1]])

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=").trim_suffix("/") + "/"
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
		if arg == "--diffuse=lambert": lambert = true
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
	if lambert:
		var parts: Array = []
		if world.has_node("RefugeArt"): parts.append(world.get_node("RefugeArt"))
		parts.append(world.get_node("DefenseSlots/SlotWestInner"))
		for part in parts:
			for mi: MeshInstance3D in part.find_children("*", "MeshInstance3D", true, false):
				var m := mi.material_override as StandardMaterial3D
				if m != null and m.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON:
					m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY # padrao do Godot
					m.roughness = 1.0
		print("[017A] A/B: pecas novas com difusao padrao (Burley), sem toon")
	# Criaturas diurnas paradas em lugares fixos (fora das vistas do Refugio).
	var dinos: Array = world.get_node("EncounterSpawner").encounters
	for i in dinos.size():
		dinos[i].set_physics_process(false)
		dinos[i].global_position = Vector3(-12.0 + i * 2.5, 0.5, 12.0)
	DayNightManager.gameplay_enabled = false
	var spawn: Vector3 = world.get_node("PlayerSpawn").global_position
	# 1-2. Vista padrao (Player no PlayerSpawn) nas 6 horas de referencia.
	await put_player(spawn)
	await series("01_padrao", ["0800", "1200", "1730", "2100", "0000", "0530"])
	# 3. Refugio aproximado: Player a 3 m do cristal (camera do jogo).
	await put_player(Vector3(0, 0.1, -12))
	await series("03_refugio_jogo", ["1200", "2100"])
	# 4. Caminho do patio ate a bifurcacao.
	await put_player(Vector3(0, 0.1, -2))
	await series("04_caminho", ["1200"])
	# 8. Vista de cima da SafeZone (diagnostico de composicao).
	await put_player(spawn)
	look(Vector3(0, 34, -11.9), Vector3(0, 0, -12), 55.0)
	await series("08_cima", ["1200", "2100"])
	# Detalhe dos 3 objetos do prototipo (Etapa 2), camera de diagnostico.
	look(Vector3(2.2, 3.4, -8.6), Vector3(0, 1.6, -15))
	await series("10_cristal", ["0800", "1200", "1730", "2100", "0000", "0530"])
	look(Vector3(-7.6, 3.6, -1.4), Vector3(-10.5, 0.3, -5.5), 45.0)
	await series("11_slot_vazio", ["0800", "1200", "1730", "2100", "0000", "0530"])
	look(Vector3(3.0, 6.5, -12.5), Vector3(0, 2.0, -25), 60.0)
	await series("12_paredao", ["0800", "1200", "1730", "2100", "0000", "0530"])
	# 5. SlotWestInner vazio e com torre, pela camera do jogo.
	await put_player(Vector3(-9.0, 0.1, -3.0))
	await series("05_slot_vazio_jogo", ["1200", "2100"])
	set_hour(12.0)
	world.get_node("DefenseSlots/SlotWestInner").build()
	await series("05_slot_torre_jogo", ["1200", "2100"])
	look(Vector3(-7.6, 3.6, -1.4), Vector3(-10.5, 0.8, -5.5), 45.0)
	await series("13_slot_torre", ["1200", "2100"])
	# 6. BuildZone: fantasma da Fogueira valido e invalido (dia).
	set_hour(12.0)
	await put_player(Vector3(4.0, 0.1, -10.0))
	var stock = world.get_node("ResourceStock")
	var placer = world.get_node("BuildPlacer")
	stock.add(&"wood", 60)
	stock.add(&"stone", 30)
	placer.follow_cursor = false
	placer.begin(Recipes.CAMPFIRE)
	placer.move_ghost_to(Vector3(5.0, 0, -12.5))
	await shot("06_buildzone_valido_1200")
	placer.move_ghost_to(Vector3(-6.0, 0, -9.0))
	await shot("06_buildzone_invalido_1200")
	placer.cancel()
	# 7. Noite 1 com os 3 inimigos chegando ao Refugio (congelados), 21:00.
	set_hour(12.0) # start_night() so parte do DIA
	DayNightManager.gameplay_enabled = true
	DayNightManager.start_night()
	await wait(270)
	var foes: Array = world.get_node("WaveManager")._active_wave_enemies.keys()
	var spots := [Vector3(-5.5, 0.5, -6.5), Vector3(4.5, 0.5, -5.0), Vector3(-1.0, 0.5, -9.5)]
	for i in foes.size():
		foes[i].set_physics_process(false)
		foes[i].global_position = spots[i % spots.size()]
	DayNightManager.gameplay_enabled = false
	await put_player(spawn)
	await series("07_noite1_inimigos", ["2100"])
	print("[017A] %d inimigos na noite 1; capturas em %s" % [foes.size(), out])
	app.show_menu()
	get_tree().quit.call_deferred()
