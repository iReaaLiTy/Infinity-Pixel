extends Node

# Evidencia visual da Spec 014 (nao e teste): o mesmo cenario em varios
# horarios, pela camera REAL de gameplay, mais uma vista do ceu (camera extra
# so para conferir Sol/Lua/estrelas, que a camera estrategica nao enxerga).
# O horario e posto no proprio DayNightManager (state + phase_elapsed): nao ha
# relogio paralelo. Exige janela. Uso: -- --output=<pasta>
const Recipes := preload("res://scenes/world/build_recipes.gd")
var out := "user://spec014-views/"
var app
var world: Node3D
var visual

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + label + ".png")
	print("[SPEC014] %s  relogio %s  visual %.2f h" % [label, DayNightManager.clock_text(), visual.shown_hour])

func wait(seconds: float) -> void:
	for i in int(round(seconds * 60.0)):
		await get_tree().physics_frame

## Poe o relogio do DayNightManager na hora pedida (8-30, sendo 24+ madrugada).
func set_hour(h: float) -> void:
	if h >= 8.0 and h < 18.0:
		DayNightManager.state = DayNightManager.State.DAY
		DayNightManager.phase_elapsed = (h - 8.0) / 10.0 * DayNightManager.day_duration_seconds
	else:
		var hn := h + 24.0 if h < 12.0 else h
		DayNightManager.state = DayNightManager.State.NIGHT
		DayNightManager.phase_elapsed = (hn - 18.0) / 12.0 * DayNightManager.night_duration_seconds
	visual.snap()

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
	await wait(0.5)
	world = app.world
	visual = world.get_node("DayNightVisual")
	var player = world.get_node("Player")
	player.set_process_unhandled_input(false)
	player._invulnerable_left = INF
	# Cenario: refugio ao norte, Fogueira na BuildZone, torre, armadilha na rota,
	# um aliado domesticado e um selvagem diurno perto do Player.
	var stock = world.get_node("ResourceStock")
	var placer = world.get_node("BuildPlacer")
	stock.add(&"wood", 60)
	stock.add(&"stone", 30)
	placer.follow_cursor = false
	placer.begin(Recipes.CAMPFIRE)
	placer.move_ghost_to(Vector3(5.0, 0, -12.5))
	placer.confirm()
	for z in [-3.0, -2.0, -1.0, 0.0, 1.0, 2.0]:
		placer.begin(Recipes.TRAP)
		placer.move_ghost_to(Vector3(0.0, 0, z))
		if placer.confirm() != null:
			break
	placer.cancel()
	world.get_node("DefenseSlots/SlotRuinMeadow").build()
	var dinos: Array = world.get_node("EncounterSpawner").encounters
	for d in dinos: d.set_physics_process(false)
	dinos[0].domesticate()
	dinos[0].global_position = Vector3(-2.5, 0.5, -6.5)
	dinos[1].global_position = Vector3(4.0, 0.5, -3.0)
	player.global_position = Vector3(0.5, 0.1, -7.5)
	await wait(1.5)
	# Inimigos da onda (Noite 1) congelados em volta, para a leitura noturna.
	DayNightManager.start_night()
	await wait(4.5)
	var foes: Array = world.get_node("WaveManager")._active_wave_enemies.keys()
	var spots := [Vector3(-5.5, 0.5, -3.5), Vector3(2.5, 0.5, -1.5), Vector3(-1.0, 0.5, -11.0)]
	for i in foes.size():
		foes[i].set_physics_process(false)
		foes[i].global_position = spots[i % spots.size()]
	await wait(0.3)
	# Congela o jogo: cada captura mostra exatamente a hora posta.
	DayNightManager.gameplay_enabled = false
	for pair in [[8.0, "01_0800_manha"], [12.0, "02_1200_dia"], [16.5, "03_1630_fim_de_tarde"], [17.0, "04_1700_fim_de_tarde"], [17.5, "05_1730_por_do_sol"], [18.0, "06_1800_por_do_sol"], [18.5, "07_1830_anoitecer"], [21.0, "08_2100_noite"], [0.0, "09_0000_noite_profunda"], [4.5, "10_0430_madrugada"], [5.5, "11_0530_amanhecer"], [5.99, "12_0559_segurando"]]:
		set_hour(pair[0])
		await wait(0.1)
		await shot(pair[1])
	# 05:59 -> 08:00 (onda vencida): o relogio salta, o visual atravessa o amanhecer.
	set_hour(5.99)
	DayNightManager.gameplay_enabled = true
	DayNightManager.report_wave_victory()
	await wait(0.05)
	await shot("13_novo_dia_t0")
	await wait(1.3)
	await shot("14_novo_dia_t1_3s")
	await wait(2.0)
	await shot("15_novo_dia_t3_3s")
	DayNightManager.gameplay_enabled = false
	# Vista do ceu (camera extra, olhando o horizonte ao sul).
	var sky_cam := Camera3D.new()
	world.add_child(sky_cam)
	sky_cam.global_position = Vector3(0, 6, -5)
	sky_cam.rotation_degrees = Vector3(18, 180, 0)
	sky_cam.fov = 70
	sky_cam.make_current()
	for pair in [[12.0, "ceu_1200"], [18.0, "ceu_1800"], [21.0, "ceu_2100"], [0.0, "ceu_0000"], [5.5, "ceu_0530"]]:
		set_hour(pair[0])
		await wait(0.3)
		await shot(pair[1])
	print("[SPEC014] capturas salvas em " + out)
	app.show_menu()
	get_tree().quit.call_deferred()
