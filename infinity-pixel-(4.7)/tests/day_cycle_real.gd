extends Node

# Spec 013 com os tempos REAIS de gameplay (sem acelerar o DayNightManager):
# 90 s de dia, aviso a 20 s, contagem nos 10 s finais, 45 s de relogio noturno.
# Headless com --fixed-fps 60 simula os ~150 s de jogo em poucos segundos;
# com janela leva o tempo real.
var passed: Array[String] = []
var failed: Array[String] = []
var warning_at := -1.0

func check(ok: bool, title: String) -> void:
	(passed if ok else failed).append(title)
	print(("PASS: " if ok else "FAIL: ") + title)

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func until(condition: Callable, limit: float) -> bool:
	var t := 0.0
	while not condition.call() and t < limit:
		await get_tree().physics_frame
		t += 1.0 / 60.0
	return condition.call()

func _ready() -> void:
	var dnm := DayNightManager
	# [1][3][5] valores de jogo normal, sem nenhuma sobrescrita
	check(dnm.day_duration_seconds == 90.0 and dnm.night_duration_seconds == 45.0, "Jogo normal: dia 90 s, relogio noturno 45 s")
	check(dnm.night_warning_seconds == 20.0 and dnm.night_countdown_seconds == 10.0, "Jogo normal: aviso 20 s, contagem 10 s")
	dnm.night_warning.connect(func(): warning_at = dnm.phase_elapsed)
	var app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	app.start_game()
	check(dnm.clock_text() == "08:00", "Dia 1 comeca as 08:00")
	await get_tree().process_frame # o encontro nasce no quadro seguinte
	await get_tree().process_frame
	var world: Node3D = app.world
	world.get_node("EncounterSpawner").current_encounter.set_physics_process(false)
	var player = world.get_node("Player")
	player._invulnerable_left = INF # este teste mede tempo, nao combate
	var wave = world.get_node("WaveManager")
	# [8] pausa congela
	await wait(30.0)
	check(absf(dnm.phase_elapsed - 30.0) < .2 and absi(dnm.clock_minutes() - (11 * 60 + 20)) <= 1, "30 s de dia ~ 11:20 (%s)" % dnm.clock_text())
	var paused_clock: String = dnm.clock_text()
	app.pause_game()
	var frozen: float = dnm.phase_elapsed
	await wait(5.0)
	check(dnm.phase_elapsed == frozen and dnm.clock_text() == paused_clock, "Pausa congela o relogio")
	app.resume_game()
	# [2] aviso faltando 20 s (70 s de 90 = 466,7 min de jogo = 15:46)
	await until(func(): return warning_at >= 0.0, 45.0)
	check(absf(warning_at - 70.0) < .1, "Aviso dispara faltando 20 s (aos %.2f s)" % warning_at)
	check(absi(dnm.clock_minutes() - (15 * 60 + 46)) <= 1, "Aviso por volta das 15:46 (%s)" % dnm.clock_text())
	# [3] contagem so nos ultimos 10 s
	await until(func(): return dnm.seconds_until_night() <= 10.5, 15.0)
	await get_tree().process_frame
	check(not app.countdown_text.visible, "Contagem oculta faltando mais de 10 s")
	await until(func(): return dnm.seconds_until_night() <= 9.9, 2.0)
	await get_tree().process_frame
	check(app.countdown_text.visible and app.countdown_text.text == "ANOITECE EM 10", "Contagem 'ANOITECE EM 10' (%s)" % app.countdown_text.text)
	await until(func(): return dnm.seconds_until_night() <= .9, 10.0)
	await get_tree().process_frame
	check(app.countdown_text.text == "ANOITECE EM 1", "Contagem chega a 'ANOITECE EM 1'")
	# [4] noite automatica aos 90 s
	await until(func(): return dnm.is_night(), 2.0)
	check(dnm.is_night() and dnm.clock_text() == "18:00" and wave.enemy_count == 3, "Noite 1 automatica aos 90 s, 18:00, 3 inimigos")
	# [5] relogio noturno: 45 s ate 05:59 (12 h = 720 min => 1 min a cada 0,0625 s)
	await wait(22.5)
	var mid := dnm.clock_minutes()
	check(mid >= 1439 or mid <= 1, "Meio da noite (22,5 s) ~ 00:00 (%s)" % dnm.clock_text())
	await until(func(): return dnm.phase_elapsed >= 45.0, 25.0)
	await get_tree().process_frame
	# [6] inimigos vivos seguram 05:59
	check(dnm.clock_text() == "05:59" and dnm.is_night() and wave._active_wave_enemies.size() > 0, "45 s: 05:59 com inimigos vivos, noite continua")
	await wait(10.0)
	check(dnm.clock_text() == "05:59" and dnm.is_night() and dnm.nights_defended == 0, "55 s: ainda 05:59, noite nao termina pelo relogio")
	# [7] matar todos -> amanhecer
	for foe in wave._active_wave_enemies.keys():
		foe.take_damage(1000)
	await until(func(): return dnm.is_day(), 2.0)
	check(dnm.is_day() and dnm.day_number == 2 and dnm.nights_defended == 1 and dnm.clock_text() == "08:00", "Matar todos: amanhecer, Dia 2, 08:00")
	app.show_menu()
	await get_tree().process_frame
	var report := {"passed": passed, "failed": failed, "display": DisplayServer.get_name()}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file := FileAccess.open(argument.trim_prefix("--report="), FileAccess.WRITE)
			file.store_string(JSON.stringify(report, "  "))
			file.close()
	print("SPEC013 REAL RESULTS: %d passed; %d failed" % [passed.size(), failed.size()])
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)
