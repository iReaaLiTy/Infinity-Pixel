extends Node

# Spec 013 — relogio, ciclo automatico e ataques noturnos, na cena real.
# Duracoes aceleradas SO neste teste (exports do DayNightManager); o jogo usa
# 90 s / 45 s (ver tests/day_cycle_real.gd). Itens A–U do pedido entre colchetes.
const DAY := 6.0
const NIGHT := 4.0
var passed: Array[String] = []
var failed: Array[String] = []
var app: Node
var world: Node3D
var warnings := 0
var dawns := 0

func check(ok: bool, title: String) -> void:
	(passed if ok else failed).append(title)
	print(("PASS: " if ok else "FAIL: ") + title)

# Timer que corre mesmo pausado (o teste e PROCESS_MODE_ALWAYS).
func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func until(condition: Callable, limit: float) -> bool:
	var t := 0.0
	while not condition.call() and t < limit:
		await get_tree().physics_frame
		t += 1.0 / 60.0
	return condition.call()

# Rota de cada spawn: entrada (marcador da Spec 012) mais proxima.
func route_of(pos: Vector3) -> String:
	var best := ""
	var best_d := INF
	for entry in world.get_node("WorldRegions/NightRoutes").get_children():
		if entry is Marker3D:
			var d := Vector2(pos.x - entry.global_position.x, pos.z - entry.global_position.z).length()
			if d < best_d:
				best_d = d
				best = entry.name
	return best if best_d < 3.5 else "fora(%.1f m)" % best_d

# Registra o ponto de nascimento de cada inimigo da onda atual.
func watch_spawns(wave: Node, expected: int, limit: float) -> Array:
	var seen := {}
	var routes := []
	var t := 0.0
	while routes.size() < expected and t < limit:
		for enemy in wave._active_wave_enemies.keys():
			if not seen.has(enemy):
				seen[enemy] = true
				routes.append(route_of(enemy.global_position))
		await get_tree().physics_frame
		t += 1.0 / 60.0
	return routes

func _ready() -> void:
	DayNightManager.day_duration_seconds = DAY
	DayNightManager.night_duration_seconds = NIGHT
	DayNightManager.night_warning_seconds = 3.0
	DayNightManager.night_countdown_seconds = 2.0
	DayNightManager.night_warning.connect(func(): warnings += 1)
	DayNightManager.day_started.connect(func(): dawns += 1)
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	check(DayNightManager.clock_text() == "08:00" and not DayNightManager.can_play(), "Menu: relogio parado antes de JOGAR")
	app.start_game() # o mesmo que o botao JOGAR chama
	var start_clock: String = DayNightManager.clock_text() # no instante do JOGAR
	await get_tree().process_frame
	await get_tree().process_frame
	world = app.world
	var wave = world.get_node("WaveManager")
	var player: CharacterBody3D = world.get_node("Player")
	var base = world.get_node("Territory")
	world.get_node("EncounterSpawner").current_encounter.set_physics_process(false)

	# [A] novo jogo
	check(DayNightManager.day_number == 1 and DayNightManager.is_day() and DayNightManager.nights_defended == 0, "[A] Novo jogo: Dia 1, estado DIA, 0 noites")
	check(start_clock == "08:00", "[A] Novo jogo comeca as 08:00 (%s)" % start_clock)
	check(app.phase_text.text == "DIA 1" and app.clock_text.text == DayNightManager.clock_text() and app.wave_text.text.begins_with("PREPARAÇÃO"), "[A] HUD mostra DIA 1 • relogio e PREPARAÇÃO (layout 013C)")
	check(app.wave_text.text == "PREPARAÇÃO  ·  Noites: 0" and not "Sem cronômetro" in app.wave_text.text, "[A] HUD sem 'Sem cronometro', com noites defendidas")
	# [B] horario avanca (10 h em DAY s)
	await wait(1.5)
	var expected := 8 * 60 + int(DayNightManager.phase_elapsed / DAY * 600)
	check(DayNightManager.clock_minutes() > 8 * 60 + 100 and absi(DayNightManager.clock_minutes() - expected) <= 1, "[B] Horario avanca proporcionalmente (%s)" % DayNightManager.clock_text())
	# N nao inicia a noite no jogo normal
	var n_key := InputEventAction.new()
	n_key.action = "start_night"
	n_key.pressed = true
	Input.parse_input_event(n_key)
	await get_tree().process_frame
	n_key.pressed = false
	Input.parse_input_event(n_key)
	check(DayNightManager.is_day(), "N nao inicia a noite fora do modo de depuracao")
	# [C][D] pausa congela, retomar continua
	app.pause_game()
	var frozen: float = DayNightManager.phase_elapsed
	var frozen_clock: String = DayNightManager.clock_text()
	await wait(1.0)
	check(is_equal_approx(DayNightManager.phase_elapsed, frozen) and DayNightManager.clock_text() == frozen_clock, "[C] Pausa congela o horario")
	app.resume_game()
	await wait(.5)
	check(DayNightManager.phase_elapsed > frozen + .3, "[D] Retomar continua o horario")
	# [E] aviso unico; [F] contagem final
	check(warnings == 0, "[E] Sem aviso antes da janela de aviso")
	await until(func(): return DayNightManager.seconds_until_night() <= 2.5, 10.0)
	await get_tree().process_frame
	check(warnings == 1 and app.hud.find_child("NightWarningToast", true, false) != null, "[E] Aviso 'A noite se aproxima' dispara uma vez")
	check(not app.countdown_text.visible, "[F] Contagem ainda oculta fora dos ultimos segundos")
	await until(func(): return DayNightManager.seconds_until_night() <= 1.5, 10.0)
	await get_tree().process_frame
	check(app.countdown_text.visible and app.countdown_text.text == "ANOITECE EM 2", "[F] Contagem final visivel (%s)" % app.countdown_text.text)
	check(app.overlay == null and not get_tree().paused, "[F] Contagem sem modal e sem pausa")
	# [G][H] 18:00 inicia a noite e a onda
	await until(func(): return DayNightManager.is_night(), 5.0)
	check(DayNightManager.is_night() and DayNightManager.clock_text() == "18:00", "[G] 18:00 inicia NOITE automaticamente")
	check(wave._wave_active and wave.enemy_count == 3, "[H][I] WaveManager iniciou sozinho com 3 inimigos")
	check(warnings == 1, "[E] Aviso nao repete no mesmo dia")
	await get_tree().process_frame
	check(app.phase_text.text == "NOITE 1" and app.wave_text.text.begins_with("DEFESA") and not app.countdown_text.visible, "HUD muda para NOITE 1 • DEFESA")
	var spider = load("res://scenes/enemies/wild_dino.tscn").instantiate()
	world.add_child(spider)
	spider.global_position = Vector3(0, .5, 40) # longe de tudo: so le o dano
	check(is_equal_approx(spider._current_attack_damage(), 19.5), "Dano noturno 19,5 alimentado pelo estado automatico")
	# [I][J] 3 inimigos, 3 rotas
	var routes1 := await watch_spawns(wave, 3, 6.0)
	routes1.sort()
	check(routes1 == ["EastEntry", "RuinEntry", "WestEntry"], "[I][J] Noite 1: 3 inimigos, um por rota %s" % [routes1])
	check("criados" in app.onda_text.text and "ativos" in app.onda_text.text and app.onda_text.visible, "HUD da noite mostra criados/neutralizados/ativos")
	# [T] relogio segura 05:59 com inimigos ativos
	await until(func(): return DayNightManager.phase_elapsed > NIGHT + .5, 5.0)
	check(DayNightManager.is_night() and DayNightManager.clock_text() == "05:59" and wave._active_wave_enemies.size() > 0, "[T] Relogio segura 05:59; noite continua com inimigos ativos")
	await wait(1.0)
	check(DayNightManager.is_night() and DayNightManager.nights_defended == 0, "[T] O relogio nao encerra a noite sozinho")
	# [U] domesticar e depois matar o mesmo inimigo conta uma vez
	var foes: Array = wave._active_wave_enemies.keys()
	foes[0].take_damage(60)
	foes[0].domesticate()
	foes[0].take_damage(100)
	check(wave._active_wave_enemies.size() == foes.size() - 1, "[U] Domesticacao + morte posterior = uma neutralizacao")
	for foe in wave._active_wave_enemies.keys():
		foe.take_damage(1000)
	# [K][L][M] amanhecer
	await until(func(): return DayNightManager.is_day(), 2.0)
	await get_tree().process_frame
	check(DayNightManager.nights_defended == 1 and dawns == 1, "[K] Onda vencida: Noites defendidas = 1")
	check(DayNightManager.day_number == 2 and DayNightManager.clock_text() == "08:00", "[L][M] Dia 2 comeca as 08:00")
	var dawn_toast = app.hud.find_child("DawnToast", true, false)
	check(dawn_toast != null and app.overlay == null and not get_tree().paused and app.screen == "playing", "Amanhecer sem modal, sem pausa, com aviso discreto")
	await get_tree().process_frame
	check(app.phase_text.text == "DIA 2" and app.wave_text.text == "PREPARAÇÃO  ·  Noites: 1", "HUD mostra DIA 2 e 1 noite defendida (%s | %s)" % [app.phase_text.text, app.wave_text.text])
	await wait(.3)
	check(DayNightManager.nights_defended == 1, "[U] Sem contagem dupla depois do amanhecer")

	# [N][O] noite 2: 4 inimigos distribuidos
	check(wave.enemy_count_for_night(3) == 5 and wave.enemy_count_for_night(4) == 6, "Formula: noite 3 = 5, noite 4 = 6")
	await until(func(): return DayNightManager.is_night(), DAY + 2.0)
	check(DayNightManager.is_night() and DayNightManager.day_number == 2 and wave.enemy_count == 4, "[N] Noite 2 automatica com 4 inimigos")
	check(warnings == 2, "[E] Um aviso por dia (2 dias, 2 avisos)")
	# [P] Player morre: relogio e onda continuam
	var before_death: float = DayNightManager.phase_elapsed
	player.take_damage(1000)
	check(player.is_dead, "[P] Player morreu durante a noite")
	var routes2 := await watch_spawns(wave, 4, 10.0)
	check(DayNightManager.phase_elapsed > before_death + 1.0 and DayNightManager.is_night(), "[P] Relogio e noite continuam com o Player morto")
	var per_route := {}
	for r in routes2: per_route[r] = per_route.get(r, 0) + 1
	check(routes2.size() == 4 and per_route.size() == 3 and per_route.values().max() == 2, "[O] Noite 2: 4 inimigos nas 3 rotas %s" % [per_route])
	await until(func(): return not player.is_dead, 3.0)
	check(not player.is_dead and player.current_hp == 100.0, "[P] Respawn normal durante a noite")
	# [Q] pausa congela relogio e onda
	app.pause_game()
	var paused_elapsed: float = DayNightManager.phase_elapsed
	var paused_spawned: int = wave._spawned_count
	await wait(1.0)
	check(is_equal_approx(DayNightManager.phase_elapsed, paused_elapsed) and wave._spawned_count == paused_spawned, "[Q] Pausa congela relogio e onda")
	app.resume_game()
	for foe in wave._active_wave_enemies.keys():
		foe.take_damage(1000)
	await until(func(): return DayNightManager.is_day(), 2.0)
	check(DayNightManager.day_number == 3 and DayNightManager.nights_defended == 2, "Dia 3 apos a segunda noite defendida")

	# [R][S] noite 3: ultimo inimigo e refugio no mesmo quadro -> derrota vence
	await until(func(): return DayNightManager.is_night(), DAY + 2.0)
	check(wave.enemy_count == 5, "Noite 3 com 5 inimigos")
	await until(func(): return wave._active_wave_enemies.size() > 0, 3.0)
	wave._spawned_count = wave.enemy_count
	for foe in wave._active_wave_enemies.keys():
		foe.take_damage(1000)
	base.take_damage(1000)
	await wait(.2)
	check(app.screen == "defeat" and DayNightManager.is_game_over, "[R] Refugio em 0 abre 'O refúgio caiu'")
	check(DayNightManager.nights_defended == 2 and dawns == 2, "[S] Derrota tem prioridade sobre o fim da noite no mesmo quadro")
	var stopped: float = DayNightManager.phase_elapsed
	await wait(.5)
	check(is_equal_approx(DayNightManager.phase_elapsed, stopped), "Relogio parado apos a derrota")
	app.start_game()
	await get_tree().process_frame
	check(DayNightManager.day_number == 1 and DayNightManager.nights_defended == 0 and DayNightManager.clock_minutes() <= 8 * 60 + 2, "Reiniciar volta ao Dia 1, 08:00")

	app.show_menu()
	await get_tree().process_frame
	var report := {"passed": passed, "failed": failed, "engine": Engine.get_version_info(), "display": DisplayServer.get_name()}
	var destination := "user://spec013-cycle.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			destination = argument.trim_prefix("--report=")
	var file := FileAccess.open(destination, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("SPEC013 RESULTS: %d passed; %d failed" % [passed.size(), failed.size()])
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)
