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
# Visual Overhaul 4.0 (Fase A): onde o quadro gasta. Passe de sombra x passe
# visivel, CPU x GPU de render, scripts (process/physics) e memoria.
var _shadow_draws: PackedInt64Array = []
var _visible_draws: PackedInt64Array = []
var _visible_objects: PackedInt64Array = []
var _cpu_ms: PackedFloat64Array = []
var _gpu_ms: PackedFloat64Array = []
var _process_ms: PackedFloat64Array = []
var _physics_ms: PackedFloat64Array = []
var ablate := false # --ablate: mede a onda de 10 sem cada subsistema (diagnostico)
var audit := false # --audit: tambem lista luzes, malhas, sombras e particulas por vista
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

# Tempo dos scripts por quadro: este no roda PRIMEIRO (prioridade minima) e o
# Tail roda por ULTIMO; a diferenca e o _process/_physics_process de todo o jogo.
var _script_ms: PackedFloat64Array = []
var _phys_ms: PackedFloat64Array = []
var _head_us := 0
var _phys_head_us := 0

class Tail extends Node:
	var probe
	func _init(p) -> void:
		probe = p
		process_priority = 100000
		process_physics_priority = 100000
	func _process(_d: float) -> void:
		if probe._measuring:
			probe._script_ms.append((Time.get_ticks_usec() - probe._head_us) / 1000.0)
	func _physics_process(_d: float) -> void:
		if probe._measuring:
			probe._phys_ms.append((Time.get_ticks_usec() - probe._phys_head_us) / 1000.0)

func _physics_process(_delta: float) -> void:
	_phys_head_us = Time.get_ticks_usec()

static func _p99(a: PackedFloat64Array) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return snappedf(s[int(s.size() * 0.99)], 0.01)

func _process(_delta: float) -> void:
	_head_us = Time.get_ticks_usec()
	if get_tree().paused and app != null and app.get("screen") == "paused":
		app.resume_game() # perda de foco pausa o jogo e cobriria a cena com o menu
	if not _measuring:
		return
	var now := Time.get_ticks_usec()
	_times.append((now - _last) / 1000.0)
	_last = now
	_draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	_prims.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	var vp := get_viewport().get_viewport_rid()
	_shadow_draws.append(RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
	_visible_draws.append(RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
	_visible_objects.append(RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME))
	_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu())
	_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
	_process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)

static func _avg_i(a: PackedInt64Array) -> int:
	var t := 0
	for v in a: t += v
	return t / maxi(1, a.size())

static func _avg_f(a: PackedFloat64Array) -> float:
	var t := 0.0
	for v in a: t += v
	return snappedf(t / maxi(1, a.size()), 0.01)

## Composicao da cena desenhada (Fase A): o que existe e o que projeta sombra.
func scene_audit() -> Dictionary:
	var out := {"meshes_visible": 0, "meshes_casting_shadow": 0, "multimesh_instances": 0, "lights_visible": 0,
		"lights_shadow": 0, "particles_emitting": 0, "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"processing_nodes": 0, "materials_unique": 0, "by_branch": {}, "shadow_by_branch": {}}
	var mats := {}
	for n in get_tree().root.find_children("*", "", true, false):
		if n.is_processing() or n.is_physics_processing():
			out.processing_nodes += 1
		if n is Node3D and not n.is_visible_in_tree():
			continue
		var branch := "outros"
		if app != null and is_instance_valid(app.world) and app.world.is_ancestor_of(n):
			branch = String(app.world.get_path_to(n)).get_slice("/", 0)
		if n is MeshInstance3D:
			out.meshes_visible += 1
			out.by_branch[branch] = int(out.by_branch.get(branch, 0)) + 1
			if n.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				out.meshes_casting_shadow += 1
				out.shadow_by_branch[branch] = int(out.shadow_by_branch.get(branch, 0)) + 1
			if n.mesh != null:
				for i in n.mesh.get_surface_count():
					var m = n.get_active_material(i)
					if m != null: mats[m.get_instance_id()] = true
		elif n is MultiMeshInstance3D and n.multimesh != null:
			out.multimesh_instances += n.multimesh.instance_count
		elif n is OmniLight3D or n is SpotLight3D:
			out.lights_visible += 1
			if n.shadow_enabled: out.lights_shadow += 1
		elif (n is CPUParticles3D or n is GPUParticles3D) and n.emitting:
			out.particles_emitting += 1
	out.materials_unique = mats.size()
	return out

func measure(label: String) -> Dictionary:
	await get_tree().create_timer(2.0, true, false, true).timeout # aquecimento
	_times.clear(); _draws.clear(); _prims.clear()
	for a in [_shadow_draws, _visible_draws, _visible_objects, _cpu_ms, _gpu_ms, _process_ms, _physics_ms, _script_ms, _phys_ms]:
		a.clear()
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
		"draw_calls_shadow_avg": _avg_i(_shadow_draws),
		"draw_calls_visible_avg": _avg_i(_visible_draws),
		"objects_visible_avg": _avg_i(_visible_objects),
		"render_cpu_ms_avg": _avg_f(_cpu_ms),
		"render_gpu_ms_avg": _avg_f(_gpu_ms),
		"process_ms_max_per_s": _avg_f(_process_ms), # monitor do Godot: pior quadro de cada segundo
		"scripts_ms_avg": _avg_f(_script_ms), "scripts_ms_p99": _p99(_script_ms),
		"physics_scripts_ms_avg": _avg_f(_phys_ms), "physics_scripts_ms_p99": _p99(_phys_ms),
		"physics_ms_max_per_s": _avg_f(_physics_ms),
		"static_mem_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"video_mem_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
	}
	if audit:
		d["audit"] = scene_audit()
	print("[PERF] %s" % JSON.stringify(d))
	return d

func _ready() -> void:
	var report := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report = arg.trim_prefix("--report=")
		if arg.begins_with("--seconds="): seconds = float(arg.trim_prefix("--seconds="))
		if arg == "--live": live = true
		if arg == "--audit": audit = true
		if arg == "--ablate": ablate = true
	if DisplayServer.get_name() == "headless":
		print("FAIL: perf_probe exige janela")
		get_tree().quit(1)
		return
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	process_priority = -100000
	process_physics_priority = -100000
	add_child(Tail.new(self))
	var t0 := Time.get_ticks_usec()
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	var menu_load_ms := (Time.get_ticks_usec() - t0) / 1000.0
	# Visual Overhaul 3.0: o menu principal (diorama 3D) tambem e medido.
	var menu_result := await measure("menu_principal")
	menu_result["load_ms"] = snappedf(menu_load_ms, 0.1)
	var t1 := Time.get_ticks_usec()
	app.start_game()
	await get_tree().process_frame
	var game_load_ms := (Time.get_ticks_usec() - t1) / 1000.0
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
	var results := [menu_result]
	for v in VIEWS:
		player.global_position = v[1]
		set_hour(v[2])
		results.append(await measure(v[0]))
	# Design 5.0 (--ablate): quanto custam o grao de superficie, o ajuste de cor
	# e a HUD na vista padrao das 12:00. Configuracoes intercaladas e repetidas
	# (o ruido da maquina pesa igual em todas). So diagnostico.
	if ablate:
		player.global_position = VIEWS[0][1]
		set_hour(12.0)
		var finish = load("res://scenes/visuals/surface_finish.gd")
		var env: Environment = visual.env
		var grade0 := env.adjustment_enabled # o estado do jogo (5.0: desligado)
		var configure := func(grain: bool, grade: bool, hud: bool) -> void:
			for m in finish._cache.values():
				m.detail_enabled = grain
			env.adjustment_enabled = grade
			app.hud.visible = hud
		for round_i in 2:
			for c in [["referencia", true, grade0, true], ["sem_grao", false, grade0, true], ["com_ajuste_cor", true, true, true], ["sem_hud", true, grade0, false], ["sem_nada", false, false, false]]:
				configure.call(c[1], c[2], c[3])
				results.append(await measure("ablacao_%s_r%d" % [c[0], round_i + 1]))
		configure.call(true, grade0, true)
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
		"game_load_ms": snappedf(game_load_ms, 0.1),
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
	# 2b. A mesma noite com o inventario aberto (veu + cartao sobre a cena).
	if app.has_method("toggle_inventory"):
		app.toggle_inventory()
		out.append(await measure("vivo_noite_3_inventario"))
		app.toggle_inventory()
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
	# --ablate (Fase A): a mesma onda desligando um subsistema por vez, para
	# saber quanto cada um custa (so medicao; nada disso vale para o jogo).
	if ablate:
		app.hud.set_process(false)
		out.append(await measure("ablacao_sem_hud_process"))
		app.hud.set_process(true)
		var visuals := []
		for v in world.find_children("Visual", "Node3D", true, false):
			if v.get_script() != null and v.is_processing():
				visuals.append(v)
				v.set_process(false)
		out.append(await measure("ablacao_sem_animacao_criaturas"))
		for v in visuals:
			if is_instance_valid(v): v.set_process(true)
		var light: DirectionalLight3D = world.get_node("DirectionalLight3D")
		light.shadow_enabled = false
		out.append(await measure("ablacao_sem_sombra_direcional"))
		light.shadow_enabled = true
		world.get_node("ArenaArt").visible = false
		out.append(await measure("ablacao_sem_arena_art"))
		world.get_node("ArenaArt").visible = true
	# 4. Onda de 10 com 3 torres e 3 aliados em combate.
	app.start_game()
	for i in 30: await get_tree().physics_frame
	world = app.world
	visual = world.get_node("DayNightVisual")
	player = world.get_node("Player")
	player.set_process_unhandled_input(false)
	player.set_physics_process(false)
	player._invulnerable_left = INF
	player.get_node("StrategicCamera").follow_smoothing = 0.0
	world.get_node("Territory").max_health = 100000
	world.get_node("Territory").health = 100000
	for slot_name in ["SlotRuinMeadow", "SlotWestInner", "SlotEastInner"]:
		world.get_node("DefenseSlots/" + slot_name).build()
	var wild_scene: PackedScene = load("res://scenes/enemies/wild_dino.tscn")
	for k in 3:
		var ally = wild_scene.instantiate()
		world.add_child(ally)
		ally.global_position = Vector3(-2.0 + k * 2.0, 0.5, -6.0)
		ally.domesticate()
		ally.ally_state = 1
		ally._stay_position = ally.global_position
	world.get_node("WaveManager").base_enemy_count = 10
	world.get_node("WaveManager").spawn_interval = 0.6
	player.global_position = Vector3(0.0, 0.1, -5.0)
	DayNightManager.start_night()
	await get_tree().create_timer(6.0, true, false, true).timeout
	out.append(await measure("vivo_noite_10_torres_3aliados"))
	# Gameplay 5.0: 6 torres, 5 armadilhas, 3 aliados, onda de 10 e o Elixir.
	app.start_game()
	for i in 30: await get_tree().physics_frame
	world = app.world
	visual = world.get_node("DayNightVisual")
	player = world.get_node("Player")
	player.set_physics_process(false)
	player._invulnerable_left = INF
	player.get_node("StrategicCamera").follow_smoothing = 0.0
	world.get_node("Territory").max_health = 100000
	world.get_node("Territory").health = 100000
	for slot in world.get_node("DefenseSlots").get_children():
		slot.build()
	world.get_node("ResourceStock").add(&"wood", 500)
	world.get_node("ResourceStock").add(&"stone", 500)
	var placer = world.get_node("BuildPlacer")
	placer.follow_cursor = false
	for z in [4, 7, 10, 16, 19]:
		if placer.begin(&"trap"):
			placer.move_ghost_to(Vector3(0, 0, z))
			placer.confirm()
	var g5_allies := []
	for k in 3:
		var ally = wild_scene.instantiate()
		world.add_child(ally)
		ally.global_position = Vector3(-2.0 + k * 2.0, 0.5, -6.0)
		ally.domesticate()
		ally.ally_state = 1
		ally._stay_position = ally.global_position
		g5_allies.append(ally)
	world.get_node("WaveManager").base_enemy_count = 10
	world.get_node("WaveManager").spawn_interval = 0.6
	player.global_position = Vector3(0.0, 0.1, -5.0)
	DayNightManager.start_night()
	await get_tree().create_timer(6.0, true, false, true).timeout
	var elixir = world.get_node("JadeElixir")
	elixir.stored = 1
	g5_allies[0].hp = 30.0
	elixir.use_on(g5_allies[0]) # particulas jade, anel e "+40 HP" durante a medicao
	out.append(await measure("vivo_gameplay5_6torres_5armadilhas_3aliados"))
	# Design 5.0: as seis torres no nivel 3 (modelo mais detalhado) com a onda
	# ainda em curso, e a mesma vista de dia com o jogo congelado.
	for slot in world.get_node("DefenseSlots").get_children():
		while not slot.tower.is_max_level():
			slot.tower.upgrade()
	await get_tree().create_timer(1.0, true, false, true).timeout
	out.append(await measure("vivo_noite_6torres_nivel3"))
	DayNightManager.gameplay_enabled = false
	player.global_position = Vector3(0.0, 0.1, -3.0)
	set_hour(12.0)
	out.append(await measure("dia_6torres_nivel3"))
	DayNightManager.gameplay_enabled = true
	# 5. Tutorial (dia, sinal jade e painel ativos).
	if app.has_method("start_tutorial"):
		app.start_tutorial()
		for i in 30: await get_tree().physics_frame
		app.world.get_node("Player").set_process_unhandled_input(false)
		out.append(await measure("vivo_tutorial"))
	DayNightManager.gameplay_enabled = false
	return out
