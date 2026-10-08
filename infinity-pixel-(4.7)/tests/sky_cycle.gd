extends Node

# Spec 014 — ceu, iluminacao e transicao visual do dia/noite. Verificacao
# automatizada (headless ou com janela). Cobre os itens A–S da spec, mais a
# preservacao dos tempos do ciclo (90 s / 45 s / aviso 20 s / contagem 10 s).
const Recipes := preload("res://scenes/world/build_recipes.gd")
const Visual := preload("res://scenes/world/day_night_visual.gd")
var passed: Array[String] = []
var failed: Array[String] = []
var app
var world: Node3D
var visual

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func check(ok: bool, label: String) -> void:
	(passed if ok else failed).append(label)
	print(("PASS: " if ok else "FAIL: ") + label)

## Poe o relogio do DayNightManager na hora pedida e encaixa o visual.
func set_hour(h: float) -> void:
	if h >= 8.0 and h < 18.0:
		DayNightManager.state = DayNightManager.State.DAY
		DayNightManager.phase_elapsed = (h - 8.0) / 10.0 * DayNightManager.day_duration_seconds
	else:
		var hn := h + 24.0 if h < 12.0 else h
		DayNightManager.state = DayNightManager.State.NIGHT
		DayNightManager.phase_elapsed = (hn - 18.0) / 12.0 * DayNightManager.night_duration_seconds
	visual.snap()

func lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

func sky(param: String):
	return visual.sky_material.get_shader_parameter(param)

func start() -> void:
	app.start_game()
	await frames(4)
	world = app.world
	visual = world.get_node("DayNightVisual")
	world.get_node("Player").set_process_unhandled_input(false)
	for d in world.get_node("EncounterSpawner").encounters:
		d.set_physics_process(false)

func _ready() -> void:
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	await start()
	await frames(4) # estrelas do chao (MultiMesh) sao montadas apos 1 quadro de fisica
	var dnm = DayNightManager
	var light: DirectionalLight3D = visual.light
	var env: Environment = visual.env
	var connections := [dnm.day_started.get_connections().size(), dnm.night_started.get_connections().size()]

	# Tempos do ciclo preservados (a Spec 014 e so visual).
	check(dnm.day_duration_seconds == 90.0 and dnm.night_duration_seconds == 45.0 and dnm.night_warning_seconds == 20.0 and dnm.night_countdown_seconds == 10.0, "Tempos preservados: dia 90 s, noite 45 s, aviso 20 s, contagem 10 s")

	# [A] controlador existe e controla luz/ambiente/ceu do mundo.
	check(visual != null and visual.is_in_group("day_night_visual") and light != null and env != null and env.background_mode == Environment.BG_SKY and visual.sky_material != null, "[A] DayNightVisual existe e controla luz, Environment e ceu (shader)")
	check(world.get_node("WorldEnvironment").environment == env, "[A] Environment duplicado por mundo (nada vaza entre partidas)")

	# [B] fonte temporal = DayNightManager (o visual acompanha clock_hours()).
	check(dnm.clock_text() == "08:00" and visual.shown_hour < 8.05 and absf(visual.shown_hour - dnm.clock_hours()) < 0.001, "[B] Inicio: relogio 08:00 e visual na mesma hora (%.3f h)" % visual.shown_hour)
	await frames(60)
	check(absf(visual.shown_hour - dnm.clock_hours()) < 0.001 and visual.shown_hour > 8.05, "[B] Com o jogo andando, o visual segue clock_hours() (%.3f h = %.3f h)" % [visual.shown_hour, dnm.clock_hours()])
	dnm.phase_elapsed = 45.0 # 13:00 posto no proprio DayNightManager
	visual.snap()
	check(is_equal_approx(visual.shown_hour, 13.0) and dnm.clock_text() == "13:00", "[B] Mudar o DayNightManager muda o visual (13:00)")

	# [C] sem segundo relogio: com o DayNightManager parado, nada anda.
	dnm.gameplay_enabled = false
	var frozen_h: float = visual.shown_hour
	var frozen_dir := light.global_basis.z
	var frozen_e := light.light_energy
	await frames(90)
	check(visual.shown_hour == frozen_h and light.global_basis.z.is_equal_approx(frozen_dir) and light.light_energy == frozen_e, "[C] Relogio parado = Sol, luz e hora visual parados (sem relogio proprio)")
	var src := FileAccess.get_file_as_string("res://scenes/world/day_night_visual.gd")
	check(not src.contains("Time.get_") and not src.contains("get_ticks") and visual.find_children("*", "Timer", true, false).is_empty(), "[C] Controlador nao le relogio do sistema nem usa Timer")
	dnm.gameplay_enabled = true

	# [D] Sol muda de posicao/direcao ao longo do dia.
	set_hour(8.0)
	var d8 := light.global_basis.z
	set_hour(12.0)
	var d12 := light.global_basis.z
	set_hour(17.5)
	var d17 := light.global_basis.z
	check(d12.y > d8.y and d8.y > d17.y, "[D] Altura do Sol: 12:00 (%.2f) > 08:00 (%.2f) > 17:30 (%.2f)" % [d12.y, d8.y, d17.y])
	check(d8.x > 0.3 and d17.x < -0.3, "[D] Sol a leste de manha (x %.2f) e a oeste no fim da tarde (x %.2f)" % [d8.x, d17.x])
	check(rad_to_deg(asin(d8.y)) > 25.0 and rad_to_deg(asin(d8.y)) < 35.0, "[D] 08:00 e manha (Sol a %.0f graus, nao meio-dia)" % rad_to_deg(asin(d8.y)))

	# [E] intensidade solar varia.
	set_hour(12.0)
	var e12 := light.light_energy
	set_hour(18.0)
	var e18 := light.light_energy
	set_hour(0.0)
	var e0 := light.light_energy
	check(e12 > e18 and e18 > e0 and e0 > 0.1, "[E] Intensidade: 12:00 %.2f > 18:00 %.2f > 00:00 %.2f (> 0: noite jogavel)" % [e12, e18, e0])
	check(e12 <= 0.8 and env.tonemap_exposure <= 1.15, "[E] Meio-dia sem estourar (energia %.2f)" % e12)

	# [F] cor da luz varia: quente no fim da tarde, fria a noite.
	set_hour(12.0)
	var c12 := light.light_color
	set_hour(18.0)
	var c18 := light.light_color
	set_hour(0.0)
	var c0 := light.light_color
	check(c18.g < c12.g - 0.2 and c18.r >= c18.b, "[F] Por do sol mais quente que o meio-dia")
	check(c0.b > c0.r, "[F] Luz da Lua fria (azulada)")

	# [G] luz ambiente varia (cor e energia).
	set_hour(12.0)
	var a12: Color = env.ambient_light_color * env.ambient_light_energy
	set_hour(0.0)
	var a0: Color = env.ambient_light_color * env.ambient_light_energy
	check(lum(a12) > lum(a0) * 1.4 and a0.b > a0.r and env.ambient_light_energy > 0.4, "[G] Ambiente: dia claro, noite azul e mais escura, mas nao preta")

	# [H] estrelas praticamente invisiveis de dia.
	var day_stars := true
	for h in [8.0, 10.0, 12.0, 16.5, 17.5]:
		set_hour(h)
		day_stars = day_stars and sky("stars") <= 0.001 and not visual.glints.visible
	check(day_stars, "[H] Estrelas (ceu e chao) invisiveis de 08:00 a 17:30")
	set_hour(18.0)
	var s18: float = sky("stars")
	set_hour(18.8)
	var s188: float = sky("stars")
	check(s18 <= 0.01 and s188 > s18 and s188 < 0.5, "[H] Estrelas surgem aos poucos ao anoitecer (18:00 %.2f, 18:48 %.2f)" % [s18, s188])

	# [I] estrelas visiveis a noite.
	set_hour(21.0)
	check(sky("stars") >= 0.99 and visual.glints != null and visual.glints.visible and visual.glint_material.get_shader_parameter("stars") >= 0.99 and visual.glints.multimesh.instance_count >= 60, "[I] Noite: estrelas no ceu e no chao (%d pontos, 1 MultiMesh)" % visual.glints.multimesh.instance_count)
	set_hour(5.5)
	var s55: float = sky("stars")
	check(s55 > 0.0 and s55 < 0.4, "[I] Estrelas somem aos poucos no amanhecer (05:30 %.2f)" % s55)

	# [J] Lua visivel a noite e e ela a luz direcional.
	set_hour(0.0)
	check(sky("moon_alpha") >= 0.99 and light.global_basis.z.is_equal_approx(visual.moon_dir) and visual.moon_dir.y > 0.5, "[J] 00:00: Lua visivel e alta, luz direcional = Lua")
	set_hour(22.0)
	var m22: Vector3 = visual.moon_dir
	set_hour(3.0)
	check(not m22.is_equal_approx(visual.moon_dir), "[J] Lua se move ao longo da noite")

	# [K] Lua sem destaque de dia.
	set_hour(12.0)
	check(sky("moon_alpha") <= 0.001 and light.global_basis.z.is_equal_approx(visual.sun_dir), "[K] Dia: Lua apagada, luz direcional = Sol")

	# Fontes locais: brilho noturno (Fogueira, refugio, torres, armadilha).
	var stock = world.get_node("ResourceStock")
	var placer = world.get_node("BuildPlacer")
	stock.add(&"wood", 60)
	stock.add(&"stone", 30)
	set_hour(9.0)
	placer.follow_cursor = false
	placer.begin(Recipes.CAMPFIRE)
	placer.move_ghost_to(Vector3(8.5, 0, -17))
	var fire = placer.confirm()
	var trap = null
	for z in [-3.0, -2.0, -1.0, 0.0, 1.0, 2.0]:
		placer.begin(Recipes.TRAP)
		placer.move_ghost_to(Vector3(0.0, 0, z))
		trap = placer.confirm()
		if trap != null:
			break
	placer.cancel()
	var tower = world.get_node("DefenseSlots/SlotRuinMeadow").build()
	await frames(2)
	visual.snap()
	var fire_light: OmniLight3D = fire.find_children("*", "OmniLight3D", true, false)[0]
	var refuge_light: OmniLight3D = world.get_node("Territory/RefugeNightLight")
	var day_fire_range := fire_light.omni_range
	var day_crystal: float = tower._glow_mats[0].emission_energy_multiplier
	var day_spike: float = trap._spike_mat.emission_energy_multiplier
	var tower_stats_day: Dictionary = tower.stats().duplicate()
	check(not refuge_light.visible and visual.night_glow == 0.0, "[Refugio] De dia a luz noturna do refugio fica apagada")
	set_hour(21.0)
	await frames(2)
	check(refuge_light.visible and refuge_light.light_energy > 1.0 and not refuge_light.shadow_enabled, "[Refugio] A noite o refugio ganha luz local (sem sombra)")
	check(fire_light.omni_range > day_fire_range and fire_light.light_energy > 1.5, "[Fogueira] A noite a luz da Fogueira fica mais perceptivel")
	check(tower._glow_mats[0].emission_energy_multiplier > day_crystal + 1.0, "[Torre] A noite o cristal brilha mais")
	check(trap._spike_mat.emission_energy_multiplier > day_spike and trap._spike_mat.emission_energy_multiplier <= 0.4 and trap.find_children("*", "Light3D", true, false).is_empty(), "[Armadilha] Leve brilho nas pontas, sem luz propria")

	# [P] Fogueira: mecanica intacta (so a luz muda).
	var player = world.get_node("Player")
	check(fire.HEAL_AMOUNT == 25.0 and fire.CHANNEL_TIME == 3.0 and fire.RANGE == 2.5 and fire.MAX_CHARGES == 2 and fire.COOLDOWN == 25.0, "[P] Fogueira: +25, 3 s, 2,5 m, 2 cargas, 25 s (inalterados)")
	player.global_position = fire.global_position + Vector3(0, 0.1, 4.0)
	await frames(2)
	check(not fire.player_in_range() and fire_light.omni_range > 4.0, "[P] Luz noturna maior nao amplia o alcance da cura (Player a 4 m fora)")
	player.global_position = fire.global_position + Vector3(0, 0.1, 1.8)
	player.current_hp = 50.0
	await frames(2)
	Input.action_press("heal_interact")
	await frames(int(3.1 * 60) + 4)
	Input.action_release("heal_interact")
	check(player.current_hp == 75.0 and fire.charges == 1, "[P] Cura a noite continua +25 em 3 s e gasta 1 carga (HP %.0f)" % player.current_hp)

	# [Q] Torres: valores intactos.
	check(tower.stats() == tower_stats_day, "[Q] Torre: dano, alcance e cadencia iguais de dia e de noite")

	# [R] Inimigos: valores intactos (inclusive o buff noturno ja existente).
	var dino = world.get_node("EncounterSpawner").encounters[0]
	check(dnm.night_damage_multiplier == 1.30 and dnm.night_speed_multiplier == 1.20 and dino.MAX_HP == 80.0 and dino.BASE_ATTACK_DAMAGE == 15.0 and dino.BASE_SPEED == 4.0, "[R] Inimigos: HP 80, dano 15, velocidade 4, buff noturno 1,30/1,20 inalterados")

	# [S] Coleta intacta (a noite visual nao interfere).
	var tree: Node = null
	for c in get_tree().get_nodes_in_group("collectable"):
		if c.kind == "wood" and not c.depleted:
			tree = c
			break
	set_hour(10.0)
	var wood_before: int = stock.get_amount(&"wood")
	tree.take_damage(tree.max_hp)
	await frames(2)
	check(tree.reward() == 10 and stock.get_amount(&"wood") == wood_before + 10, "[S] Coleta: arvore da +10 Madeira")

	# [M] Pausa congela tempo e visual (inclusive o cintilar das estrelas).
	set_hour(21.0)
	await frames(10)
	app.pause_game()
	var p_phase: float = dnm.phase_elapsed
	var p_h: float = visual.shown_hour
	var p_tw = visual.glint_material.get_shader_parameter("twinkle_time")
	var p_e := light.light_energy
	for i in 60:
		await get_tree().process_frame
	check(get_tree().paused and dnm.phase_elapsed == p_phase and visual.shown_hour == p_h and visual.glint_material.get_shader_parameter("twinkle_time") == p_tw and light.light_energy == p_e, "[M] Pausa congela relogio, Sol/Lua, ceu e estrelas")
	app.resume_game()
	await frames(10)
	check(visual.shown_hour > p_h, "[M] Ao despausar, o ciclo visual continua de onde parou")

	# [O] 05:59 -> 08:00: sem flash e sem estado noturno preso.
	set_hour(5.99)
	await frames(30)
	check(absf(dnm.clock_hours() - 29.983) < 0.01 and visual.shown_hour > 5.9 and visual.shown_hour < 6.0, "[O] Segurando em 05:59: visual de amanhecer (%.2f h)" % visual.shown_hour)
	for foe in world.get_node("WaveManager")._active_wave_enemies.keys():
		if is_instance_valid(foe): foe.queue_free()
	dnm.report_wave_victory()
	await frames(1)
	check(dnm.clock_text() == "08:00" and visual.shown_hour < 6.5, "[O] Relogio salta para 08:00; visual nao salta (%.2f h)" % visual.shown_hour)
	var max_step := 0.0
	var last_e := light.light_energy
	var last_a := env.ambient_light_energy
	for i in 60 * 4:
		await get_tree().physics_frame
		max_step = maxf(max_step, maxf(absf(light.light_energy - last_e), absf(env.ambient_light_energy - last_a)))
		last_e = light.light_energy
		last_a = env.ambient_light_energy
	check(max_step < 0.03, "[O] Transicao suave: maior variacao por quadro %.3f" % max_step)
	check(absf(Visual.wrapped_gap(visual.shown_hour, dnm.clock_hours())) < 0.01 and sky("stars") == 0.0 and sky("moon_alpha") == 0.0 and visual.night_glow == 0.0 and not refuge_light.visible, "[O] Em ~4 s o visual alcanca o relogio: sem estrelas, Lua ou brilho noturno presos")

	# [N] Derrota: o ciclo para.
	set_hour(15.0)
	await frames(5)
	world.get_node("Territory").take_damage(1000.0)
	await frames(2)
	var d_phase: float = dnm.phase_elapsed
	var d_h: float = visual.shown_hour
	var d_dir := light.global_basis.z
	await frames(90)
	check(dnm.is_game_over and dnm.phase_elapsed == d_phase and visual.shown_hour == d_h and light.global_basis.z.is_equal_approx(d_dir), "[N] Derrota congela relogio e ambiente")

	# [L] Reiniciar em noite profunda volta a MANHA, sem nada do ciclo anterior.
	var old_env := env
	await start()
	set_hour(0.0)
	await frames(5)
	await start()
	await frames(4)
	var nv = visual
	var morning: Dictionary = Visual.sample(nv.shown_hour)
	check([dnm.day_started.get_connections().size(), dnm.night_started.get_connections().size()] == connections, "[L] Reinicios nao acumulam conexoes do visual nos sinais do DayNightManager")
	check(dnm.clock_text() == "08:00" and nv.shown_hour < 8.05 and absf(nv.shown_hour - dnm.clock_hours()) < 0.001 and nv.env != old_env, "[L] Reiniciar: Dia 1 08:00 com Environment novo")
	check(nv.sky_material.get_shader_parameter("stars") == 0.0 and nv.sky_material.get_shader_parameter("moon_alpha") == 0.0 and nv.night_glow == 0.0 and not nv.glints.visible, "[L] Reiniciar: sem Lua, estrelas ou brilho noturno")
	check(is_equal_approx(nv.light.light_energy, morning.energy) and nv.light.light_color.is_equal_approx(morning.light) and nv.env.ambient_light_color.is_equal_approx(morning.amb), "[L] Reiniciar: luz e ambiente de manha (%.2f h)" % nv.shown_hour)

	# Menu intacto: o fundo do menu nao herda a noite.
	app.show_menu()
	await frames(3)
	var report_path := "user://sky-cycle.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
	var report := FileAccess.open(report_path, FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": passed, "failed": failed, "display": DisplayServer.get_name()}, "  "))
	report.close()
	print("SPEC014 RESULTS: %d passed; %d failed" % [passed.size(), failed.size()])
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)
