extends Node

# Spec 017A: desempenho antes x depois da reforma visual, na mesma maquina.
# Exige janela; rodar SEM --fixed-fps e com --disable-vsync. Jogo congelado
# (relogio parado, criaturas paradas): so o custo de desenhar a cena muda.
# Uso: res://tests/perf_probe.tscn -- --report=<json> [--seconds=10] [--live]
const VIEWS := [
	["padrao_1200", Vector3(0, 0.1, -10), 12.0],
	["padrao_1730", Vector3(0, 0.1, -10), 17.5],
	["padrao_2100", Vector3(0, 0.1, -10), 21.0],
	["refugio_1200", Vector3(0, 0.1, -12), 12.0],
	["slot_oeste_2100", Vector3(-9, 0.1, -3), 21.0],
]
var seconds := 10.0
var live := false # --live: tambem mede cenarios com o jogo rodando
var app
var visual
var _times: PackedFloat64Array = []
var _draws: PackedInt64Array = []
var _prims: PackedInt64Array = []
var _measuring := false
var _last := 0

func set_hour(h: float) -> void:
	if h >= 8.0 and h < 18.0:
		DayNightManager.state = DayNightManager.State.DAY
		DayNightManager.phase_elapsed = (h - 8.0) / 10.0 * DayNightManager.day_duration_seconds
	else:
		var hn := h + 24.0 if h < 12.0 else h
		DayNightManager.state = DayNightManager.State.NIGHT
		DayNightManager.phase_elapsed = (hn - 18.0) / 12.0 * DayNightManager.night_duration_seconds
	visual.snap()

func _process(_delta: float) -> void:
	if get_tree().paused and app != null and app.get("screen") == "paused":
		app.resume_game() # perda de foco pausa o jogo e cobriria a cena com o menu
	if not _measuring:
		return
	var now := Time.get_ticks_usec()
	_times.append((now - _last) / 1000.0)
	_last = now
	_draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	_prims.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))

func measure(label: String) -> Dictionary:
	await get_tree().create_timer(2.0, true, false, true).timeout # aquecimento
	_times.clear(); _draws.clear(); _prims.clear()
	_last = Time.get_ticks_usec()
	_measuring = true
	await get_tree().create_timer(seconds, true, false, true).timeout
	_measuring = false
	var sorted := _times.duplicate()
	sorted.sort()
	var total := 0.0
	for t in _times: total += t
	var worst := maxi(1, int(ceil(sorted.size() * 0.01)))
	var worst_sum := 0.0
	for i in worst: worst_sum += sorted[sorted.size() - 1 - i]
	var draws := 0
	var prims := 0
	for i in _draws.size(): draws += _draws[i]; prims += _prims[i]
	var d := {
		"view": label, "frames": _times.size(),
		"fps_avg": snappedf(1000.0 * _times.size() / total, 0.1),
		"fps_1pct_low": snappedf(1000.0 / (worst_sum / worst), 0.1),
		"frame_ms_avg": snappedf(total / _times.size(), 0.01),
		"frame_ms_max": snappedf(sorted[sorted.size() - 1], 0.01),
		"draw_calls_avg": draws / maxi(1, _draws.size()),
		"primitives_avg": prims / maxi(1, _prims.size()),
	}
	print("[PERF] %s" % JSON.stringify(d))
	return d

func _ready() -> void:
	var report := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report = arg.trim_prefix("--report=")
		if arg.begins_with("--seconds="): seconds = float(arg.trim_prefix("--seconds="))
		if arg == "--live": live = true
	if DisplayServer.get_name() == "headless":
		print("FAIL: perf_probe exige janela")
		get_tree().quit(1)
		return
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	app.start_game()
	for i in 30: await get_tree().physics_frame
	var world: Node3D = app.world
	visual = world.get_node("DayNightVisual")
	var player: CharacterBody3D = world.get_node("Player")
	player.set_process_unhandled_input(false)
	player.set_physics_process(false)
	player._invulnerable_left = INF
	var cam: Camera3D = player.get_node("StrategicCamera")
	cam.follow_smoothing = 0.0
	var dinos: Array = world.get_node("EncounterSpawner").encounters
	for i in dinos.size():
		dinos[i].set_physics_process(false)
		dinos[i].global_position = Vector3(-12.0 + i * 2.5, 0.5, 12.0)
	DayNightManager.gameplay_enabled = false
	var results := []
	for v in VIEWS:
		player.global_position = v[1]
		set_hour(v[2])
		results.append(await measure(v[0]))
	# --live: cenarios com o jogo RODANDO (IA, torres, efeitos), nao congelado.
	# So para medir: torres erguidas direto no ponto, Refugio com vida alta para a
	# onda maior nao encerrar a partida no meio da medicao.
	if live:
		results.append_array(await live_scenarios())
	var info := {
		"adapter": RenderingServer.get_video_adapter_name(),
		"vendor": RenderingServer.get_video_adapter_vendor(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"vsync": DisplayServer.window_get_vsync_mode(),
		"window": DisplayServer.window_get_size(),
		"seconds_per_view": seconds,
		"views": results,
	}
	print("RESULT: %s" % JSON.stringify(info))
	if report != "":
		var f := FileAccess.open(report, FileAccess.WRITE)
		f.store_string(JSON.stringify(info, "\t", false))
		f.close()
	app.show_menu()
	get_tree().quit.call_deferred()

func live_scenarios() -> Array:
	var out := []
	var world: Node3D = app.world
	var player = world.get_node("Player")
	var dinos: Array = world.get_node("EncounterSpawner").encounters
	DayNightManager.gameplay_enabled = true
	# 1. Dia com os dois dinossauros diurnos vivos, jogador na clareira.
	for d in dinos:
		if is_instance_valid(d):
			d.set_physics_process(true)
	player.global_position = Vector3(-6.0, 0.1, 6.0)
	set_hour(10.0)
	out.append(await measure("vivo_dia_dinos"))
	# 2. Noite 1 (3 invasores) com 3 torres atirando e um aliado defendendo.
	for slot_name in ["SlotRuinMeadow", "SlotWestInner", "SlotEastInner"]:
		world.get_node("DefenseSlots/" + slot_name).build()
	if is_instance_valid(dinos[0]):
		dinos[0].domesticate()
		dinos[0].global_position = Vector3(1.5, 0.5, -4.0)
	player.global_position = Vector3(0.0, 0.1, -5.0)
	set_hour(12.0)
	DayNightManager.start_night()
	await get_tree().create_timer(4.0, true, false, true).timeout
	out.append(await measure("vivo_noite_3_torres_aliado"))
	# 3. Onda maior: nova partida, 10 invasores, as mesmas 3 torres.
	app.start_game()
	for i in 30: await get_tree().physics_frame
	world = app.world
	visual = world.get_node("DayNightVisual")
	player = world.get_node("Player")
	player.set_process_unhandled_input(false)
	player.set_physics_process(false)
	player._invulnerable_left = INF
	player.get_node("StrategicCamera").follow_smoothing = 0.0
	var base = world.get_node("Territory")
	base.max_health = 100000
	base.health = 100000
	for slot_name in ["SlotRuinMeadow", "SlotWestInner", "SlotEastInner"]:
		world.get_node("DefenseSlots/" + slot_name).build()
	world.get_node("WaveManager").base_enemy_count = 10
	world.get_node("WaveManager").spawn_interval = 0.6
	player.global_position = Vector3(0.0, 0.1, -5.0)
	DayNightManager.start_night()
	await get_tree().create_timer(6.0, true, false, true).timeout
	out.append(await measure("vivo_noite_10_torres"))
	DayNightManager.gameplay_enabled = false
	return out
