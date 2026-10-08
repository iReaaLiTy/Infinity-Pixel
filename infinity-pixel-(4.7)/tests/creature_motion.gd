extends Node

# P1 — estabilidade de movimento das criaturas (tremor, giro, anda-para).
# Mede quadro a quadro de fisica a posicao, a rotacao e o estado de cada criatura
# em cenarios do mundo real (IA, navmesh, avoidance e fisica reais; nada de
# movimento substituto) e grava as metricas em JSON. Uso:
#   Godot [--headless] --path . res://tests/creature_motion.tscn [-- --report=<arquivo>]
# Sem --headless roda com janela (mesma medicao, com renderizacao).
#
# Metricas por criatura e janela:
#   path        trajeto no plano XZ (m)       reversals  passo vira > 120 graus
#   toggles     andar<->parar (Schmitt)       chatter    parou < 0,25 s e voltou a andar
#   twitch      tranco: andou so 1-4 quadros entre duas paradas
#   yaw_travel  giro acumulado (rad)          yaw_flips  giro troca de sentido
#   yaw_wobble  troca de sentido depois de girar < 0,05 rad (tremor do rumo;
#               curvas de verdade giram bem mais antes de inverter)
#   target_sw   trocas de alvo                slot_sw    trocas de slot
#   leg_idle    giro acumulado das pernas com o corpo parado (pernas "andando no lugar")
const ApproachSlots := preload("res://scenes/enemies/approach_slots.gd")
const DINO := preload("res://scenes/enemies/wild_dino.tscn")
const LONE_ROCK := Vector3(8.46, 0, 0.74) # pedra isolada da Spec 010 (r = 0,67 m)
const DT := 1.0 / 60.0
const MOVE_ON := 0.6 # m/s: acima disso esta andando
const MOVE_OFF := 0.15 # m/s: abaixo disso esta parado (entre os dois mantem o estado)
const SHORT_SEGMENT := 0.25 # s
const FLIP_ANGLE := 2.094 # 120 graus
const YAW_EPS := 0.003 # rad por quadro (~0,18 rad/s): abaixo disso nao conta giro
const WOBBLE_TURN := 0.05 # rad: inverter o giro antes de girar isso = tremor
# Criterios por tipo de janela (valem para a pior criatura da janela).
const IDLE := {"path": 0.02, "yaw_travel": 0.02, "toggles": 0, "leg_idle": 0.05}
const HOLD := {"path": 0.05, "toggles": 0, "yaw_wobble": 0, "slot_sw": 0}
const MOVING := {"chatter": 1, "twitch": 1, "reversals": 2, "yaw_wobble": 2}

var passed: Array[String] = []
var failed: Array[String] = []
var scenarios := {}
var app: Node
var world: Node3D
var player: CharacterBody3D
var focus_resumes := 0 # pausas por perda de foco da janela, retomadas pelo teste

func check(ok: bool, title: String) -> void:
	(passed if ok else failed).append(title)
	print(("PASS: " if ok else "FAIL: ") + title)

# Com janela, o jogo pausa sozinho ao perder o foco (main.gd). Pausado, nada se
# move e uma janela "parada" passaria sem medir nada: o teste retoma na hora e o
# quadro pausado fica fora das metricas. Devolve true se o quadro estava pausado.
func keep_running() -> bool:
	if not get_tree().paused:
		return false
	if is_instance_valid(app) and app.screen == "paused":
		app.resume_game()
		focus_resumes += 1
		print("NOTA: jogo pausou (perda de foco da janela) e foi retomado pelo teste")
	return true

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		keep_running()

func seconds(s: float) -> void:
	await frames(int(round(s * 60.0)))

func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func spawn(pos: Vector3, territorial := false) -> CharacterBody3D:
	var dino := DINO.instantiate() as CharacterBody3D
	dino.territorial = territorial
	dino.position = pos
	world.add_child(dino, true)
	return dino

func spawn_ally(pos: Vector3) -> CharacterBody3D:
	var dino := spawn(pos)
	await frames(1)
	dino.take_damage(60)
	dino.domesticate()
	return dino

func clear_creatures() -> void:
	for group in ["wild_dino", "domesticated"]:
		for c in get_tree().get_nodes_in_group(group):
			c.queue_free()
	await frames(3)

func place_player(pos: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	await frames(3)

# --- medicao ---------------------------------------------------------------------

func target_id(body: Node) -> int:
	var t = body.get("_target")
	return t.get_instance_id() if is_instance_valid(t) else 0

func slot_key(body: Node) -> String:
	var st = body.get("_slot_target")
	if not is_instance_valid(st):
		return ""
	var kind: StringName = body.get("_slot_kind")
	return "%d/%s/%s" % [st.get_instance_id(), kind, ApproachSlots.slot_of(st, kind, body)]

func new_track(body: Node3D, label: String) -> Dictionary:
	return {"body": body, "label": label, "start": body.global_position, "last_pos": body.global_position,
		"last_step": Vector3.ZERO, "last_yaw": body.rotation.y, "last_dyaw": 0.0, "turn_seg": 0.0,
		"yaw_wobble": 0, "moving": false,
		"seg": 0, "segs": 0, "frames": 0, "path": 0.0, "yaw_travel": 0.0, "yaw_flips": 0, "reversals": 0,
		"toggles": 0, "chatter": 0, "twitch": 0, "target_sw": 0, "slot_sw": 0, "last_target": target_id(body),
		"last_slot": slot_key(body), "leg_idle": 0.0, "last_leg": leg_angle(body), "max_speed": 0.0}

func leg_angle(body: Node) -> float:
	return body.get_node("Visual/LegL").rotation.x if body.has_node("Visual/LegL") else 0.0

func sample(t: Dictionary) -> void:
	var body: Node3D = t.body
	if not is_instance_valid(body) or not body.is_inside_tree():
		return
	t.frames += 1
	var pos := body.global_position
	var step := Vector3(pos.x - t.last_pos.x, 0.0, pos.z - t.last_pos.z)
	var speed := step.length() / DT
	t.path += step.length()
	t.max_speed = maxf(t.max_speed, speed)
	var last_step: Vector3 = t.last_step
	if speed > MOVE_ON and last_step.length() / DT > MOVE_ON and step.angle_to(last_step) > FLIP_ANGLE:
		t.reversals += 1
	var dyaw := wrapf(body.rotation.y - t.last_yaw, -PI, PI)
	t.yaw_travel += absf(dyaw)
	if absf(dyaw) > YAW_EPS:
		if absf(t.last_dyaw) > YAW_EPS and signf(dyaw) != signf(t.last_dyaw):
			t.yaw_flips += 1
			if t.turn_seg < WOBBLE_TURN:
				t.yaw_wobble += 1
			t.turn_seg = 0.0
		t.turn_seg += absf(dyaw)
		t.last_dyaw = dyaw
	var was: bool = t.moving
	if t.moving and speed < MOVE_OFF:
		t.moving = false
	elif not t.moving and speed > MOVE_ON:
		t.moving = true
	if t.moving != was:
		t.toggles += 1
		if t.segs > 0: # o trecho que terminou comecou numa transicao (nao no inicio da janela)
			if t.moving and t.seg * DT < SHORT_SEGMENT:
				t.chatter += 1 # parada curta entre dois trechos andando
			elif not t.moving and t.seg <= 4:
				t.twitch += 1 # andou 1-4 quadros entre duas paradas
		t.segs += 1
		t.seg = 0
	t.seg += 1
	var leg := leg_angle(body)
	if speed < 0.05:
		t.leg_idle += absf(leg - t.last_leg)
	t.last_leg = leg
	var tid := target_id(body)
	if tid != t.last_target:
		t.target_sw += 1
		t.last_target = tid
	var sk := slot_key(body)
	if sk != t.last_slot:
		t.slot_sw += 1
		t.last_slot = sk
	t.last_pos = pos
	t.last_step = step
	t.last_yaw = body.rotation.y

func summary(t: Dictionary) -> Dictionary:
	var body: Node3D = t.body
	var end: Vector3 = body.global_position if is_instance_valid(body) else t.last_pos
	return {"label": t.label, "path": snappedf(t.path, 0.001), "net": snappedf(flat(end, t.start), 0.001),
		"toggles": t.toggles, "chatter": t.chatter, "twitch": t.twitch, "reversals": t.reversals,
		"yaw_travel": snappedf(t.yaw_travel, 0.001), "yaw_flips": t.yaw_flips, "yaw_wobble": t.yaw_wobble,
		"target_sw": t.target_sw, "slot_sw": t.slot_sw, "leg_idle": snappedf(t.leg_idle, 0.001),
		"max_speed": snappedf(t.max_speed, 0.01)}

func measure(name: String, bodies: Array, labels: Array, secs: float) -> Array:
	var tracks: Array = []
	for i in bodies.size():
		tracks.append(new_track(bodies[i], labels[i]))
	for f in int(round(secs * 60.0)):
		await get_tree().physics_frame
		if keep_running():
			continue
		for t in tracks:
			sample(t)
	var out: Array = tracks.map(func(t): return summary(t))
	scenarios[name] = out
	print("MOTION %s %s" % [name, JSON.stringify(out)])
	return out

# Contra "passar sem medir": a criatura que MENOS andou precisa ter andado isso.
func expect_moved(stats: Array, title: String, minimum: float) -> void:
	var least := INF
	for s in stats:
		least = minf(least, float(s.path))
	check(not stats.is_empty() and least >= minimum, "%s (menor trajeto %.2f m >= %.2f)" % [title, least if least != INF else 0.0, minimum])

func worst(stats: Array, field: String) -> float:
	var w := 0.0
	for s in stats:
		w = maxf(w, float(s[field]))
	return w

# Uma linha por janela: os limites valem para a pior criatura da janela.
func expect(stats: Array, title: String, limits: Dictionary) -> void:
	var ok := true
	var parts: Array[String] = []
	for field in limits:
		var w := worst(stats, field)
		ok = ok and w <= float(limits[field])
		parts.append("%s %s<=%s" % [field, snappedf(w, 0.001), limits[field]])
	check(ok, "%s (%s)" % [title, ", ".join(parts)])

# --- padroes de entrada do Player ------------------------------------------------

func taps(pattern: Array, hold: float, gap: float) -> void:
	for code in pattern:
		key(code, true)
		await seconds(hold)
		key(code, false)
		await seconds(gap)

func run_for(code: Key, secs: float) -> void:
	key(code, true)
	await seconds(secs)
	key(code, false)

# --- cenarios ---------------------------------------------------------------------

func _ready() -> void:
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	app.start_game()
	await frames(10)
	DayNightManager.set_process(false) # relogio parado: tudo de dia, sem noite surpresa
	world = app.world
	player = world.get_node("Player")
	player._invulnerable_left = INF
	await clear_creatures()

	# 1. Parado em casa (encontro territorial sem alvo).
	await place_player(Vector3(11, 1, 17))
	var home := Vector3(-10, 0.5, 5)
	var idle := spawn(home, true)
	await seconds(1.5)
	var s := await measure("parado_em_casa", [idle], ["territorial"], 4.0)
	expect(s, "Parado em casa nao se mexe nem gira", IDLE)
	await clear_creatures()

	# 2. Perseguir e atacar um Player parado (aproximacao + permanencia no slot).
	await place_player(Vector3(4, 1, 6))
	var hunter := spawn(Vector3(4, 0.5, 12.5))
	s = await measure("perseguir_aproximacao", [hunter], ["cacador"], 4.0)
	expect_moved(s, "Cacador de fato se aproximou", 3.0)
	expect(s, "Aproximacao ao Player sem anda-para nem tremor", MOVING)
	s = await measure("atacar_parado", [hunter], ["cacador"], 4.0)
	expect(s, "Atacando o Player parado: firme no slot", HOLD)
	check(flat(hunter.global_position, player.global_position) <= 2.0, "Cacador continua no alcance do golpe (%.2f m)" % flat(hunter.global_position, player.global_position))
	await clear_creatures()

	# 3. Grupo de 4 cerca o Player parado.
	await place_player(Vector3(4, 1, 6))
	var pack: Array = []
	for offset in [Vector3(-6, 0, 0), Vector3(6, 0, 0.5), Vector3(0.5, 0, 6), Vector3(-4, 0, 4.5)]:
		pack.append(spawn(player.global_position + offset + Vector3(0, -0.5, 0)))
	var labels := ["oeste", "leste", "sul", "sudoeste"]
	s = await measure("grupo_aproximacao", pack, labels, 5.0)
	expect_moved(s, "Todo o grupo de fato se aproximou", 2.5)
	expect(s, "Grupo se aproxima sem tremor", MOVING)
	s = await measure("grupo_cercando", pack, labels, 4.0)
	expect(s, "Grupo cercando o Player parado: ninguem empurra ninguem", HOLD)
	await clear_creatures()

	# 4. Player da passos curtos (taps de 0,12 s) com 2 cacadores no slot.
	await place_player(Vector3(4, 1, 6))
	var duo := [spawn(Vector3(-1, 0.5, 6)), spawn(Vector3(9, 0.5, 6.5))]
	await seconds(4.0)
	taps([KEY_D, KEY_A, KEY_D, KEY_A, KEY_W, KEY_S, KEY_D], 0.12, 0.6)
	s = await measure("player_passos_curtos", duo, ["oeste", "leste"], 5.0)
	expect_moved(s, "Cacadores de fato acompanharam os passos", 0.3)
	# 7 inversoes de direcao do Player: ate 7 viradas legitimas do rosto (+3 de folga).
	expect(s, "Passos curtos do Player nao viram anda-para nos cacadores", MOVING.merged({"yaw_flips": 10}))
	await clear_creatures()

	# 5. Player corre e para: perseguicao e assentamento.
	await place_player(Vector3(0, 1, 2))
	duo = [spawn(Vector3(-4, 0.5, 2)), spawn(Vector3(4, 0.5, 2.5))]
	await seconds(3.5)
	run_for(KEY_S, 1.0)
	s = await measure("player_corre_e_para", duo, ["oeste", "leste"], 4.0)
	expect_moved(s, "Cacadores de fato perseguiram", 3.0)
	expect(s, "Perseguicao apos corrida sem anda-para", MOVING)
	s = await measure("depois_da_corrida", duo, ["oeste", "leste"], 2.0)
	expect(s, "Depois da corrida os cacadores assentam", HOLD)
	await clear_creatures()

	# 6. Aliados seguindo: corrida e passos curtos.
	await place_player(Vector3(2, 1, 4))
	var allies := [await spawn_ally(Vector3(0, 0.5, 2)), await spawn_ally(Vector3(4, 0.5, 2))]
	await seconds(3.0)
	run_for(KEY_D, 1.2)
	s = await measure("aliados_seguem", allies, ["aliado1", "aliado2"], 5.0)
	expect_moved(s, "Aliados de fato seguiram", 3.0)
	expect(s, "Aliados seguem a corrida sem anda-para", MOVING)
	s = await measure("aliados_parados", allies, ["aliado1", "aliado2"], 2.0)
	expect(s, "Aliados parados com o Player parado", IDLE)
	taps([KEY_A, KEY_D, KEY_A, KEY_D], 0.12, 0.6)
	s = await measure("aliados_passos_curtos", allies, ["aliado1", "aliado2"], 3.5)
	expect(s, "Passos curtos do Player nao fazem os aliados tremer", MOVING)

	# 7. Aliado em FICAR, parado no posto.
	var guard: CharacterBody3D = allies[0]
	await place_player(guard.global_position + Vector3(0, 0.5, 1.0))
	Input.action_press("command_stay")
	await frames(2)
	Input.action_release("command_stay")
	await place_player(Vector3(12, 1, 4))
	await seconds(1.0)
	check(guard.ally_state == 1, "Aliado de fato entrou em FICAR")
	s = await measure("aliado_ficar", [guard], ["posto"], 3.0)
	expect(s, "Aliado em FICAR fica firme no posto", IDLE)
	await clear_creatures()

	# 8. Dois territoriais com casas a 0,8 m (nao se empurram para sempre).
	await place_player(Vector3(11, 1, 17))
	var close := [spawn(Vector3(-10, 0.5, 5), true), spawn(Vector3(-9.2, 0.5, 5), true)]
	await seconds(3.0)
	s = await measure("dois_proximos", close, ["a", "b"], 4.0)
	expect(s, "Dois dinos proximos param e nao se empurram", IDLE)
	await clear_creatures()

	# 9. Contorna a pedra isolada ate o Player.
	await place_player(LONE_ROCK + Vector3(0, 1, -2.2))
	var rounder := spawn(LONE_ROCK + Vector3(0, 0.5, 3.2))
	var reach_rock := -1.0
	var tr := new_track(rounder, "pedra")
	for f in 360:
		await get_tree().physics_frame
		if keep_running():
			continue
		sample(tr)
		if reach_rock < 0.0 and flat(rounder.global_position, player.global_position) <= 2.0:
			reach_rock = f * DT
	s = [summary(tr)]
	scenarios["contorna_pedra"] = s
	print("MOTION contorna_pedra %s" % JSON.stringify(s))
	check(reach_rock >= 0.0, "Contorna a pedra e alcanca o Player (%.2f s)" % reach_rock)
	expect(s, "Contornar a pedra sem tremor", MOVING)
	await clear_creatures()

	# 10. Atravessa o bosque (arvores reais) ate o Player.
	var tree_pos := Vector3.INF
	for res in get_tree().get_nodes_in_group("collectable"):
		if res.get("kind") == "wood" and (tree_pos == Vector3.INF or flat(res.global_position, Vector3(-14, 0, 18)) < flat(tree_pos, Vector3(-14, 0, 18))):
			tree_pos = res.global_position
	await place_player(tree_pos + Vector3(0, 1, -2.4))
	var woodsman := spawn(tree_pos + Vector3(0.3, 0.5, 3.4))
	var reach_tree := -1.0
	tr = new_track(woodsman, "bosque")
	for f in 420:
		await get_tree().physics_frame
		if keep_running():
			continue
		sample(tr)
		if reach_tree < 0.0 and flat(woodsman.global_position, player.global_position) <= 2.0:
			reach_tree = f * DT
	s = [summary(tr)]
	scenarios["atravessa_bosque"] = s
	print("MOTION atravessa_bosque (arvore %s) %s" % [tree_pos, JSON.stringify(s)])
	check(reach_tree >= 0.0, "Atravessa o bosque e alcanca o Player (%.2f s)" % reach_tree)
	expect(s, "Atravessar o bosque sem tremor", MOVING)
	await clear_creatures()

	# 11. Troca de alvo: Player e aliado quase a mesma distancia; o aliado defende.
	await place_player(Vector3(-10, 1, 5) + Vector3(2.3, 0, 0))
	var contested := spawn(Vector3(-10, 0.5, 5), true)
	var defender := await spawn_ally(Vector3(-12.4, 0.5, 5))
	defender.ally_state = 1 # FICAR: defende o posto
	defender._stay_position = defender.global_position
	s = await measure("troca_de_alvo", [contested, defender], ["selvagem", "aliado"], 5.0)
	check(worst(s, "path") >= 0.3, "Disputa de fato aconteceu (maior trajeto %.2f m >= 0,3)" % worst(s, "path"))
	expect(s, "Disputa Player x aliado sem alternancia de alvo", MOVING.merged({"target_sw": 2}))
	await clear_creatures()

	# 11b. Aliado em FICAR luta com um selvagem que mira o aliado (Player longe):
	# cada um tem slot ao redor do outro — nao podem ficar se perseguindo em roda.
	await place_player(Vector3(11, 1, 17))
	var keeper := await spawn_ally(Vector3(2, 0.5, 9))
	keeper.ally_state = 1
	keeper._stay_position = keeper.global_position
	var raider := spawn(Vector3(6.5, 0.5, 9.6), true)
	await seconds(1.5)
	s = await measure("aliado_x_selvagem", [keeper, raider], ["aliado", "selvagem"], 3.0)
	check(not is_instance_valid(raider) or raider.hp < raider.MAX_HP, "Aliado x selvagem de fato lutaram")
	expect(s, "Aliado x selvagem lutam sem andar em roda", MOVING.merged({"path": 0.6}))
	await clear_creatures()

	# 12. Onda noturna no refugio e fim de sessao.
	await place_player(Vector3(11, 1, 17))
	var base = world.get_node("Territory")
	var wave = world.get_node("WaveManager")
	base.health = 100000.0
	DayNightManager.start_night()
	for i in 1500:
		await get_tree().physics_frame
		keep_running()
		var alive: Array = wave._active_wave_enemies.keys().filter(func(e): return is_instance_valid(e))
		if alive.size() == 3 and alive.all(func(e): return flat(e.global_position, base.global_position) <= 1.6):
			break
	await seconds(1.5)
	var raiders: Array = wave._active_wave_enemies.keys()
	check(raiders.size() == 3, "Onda: 3 inimigos chegaram e foram medidos no refugio (%d)" % raiders.size())
	s = await measure("onda_no_refugio", raiders, raiders.map(func(e): return str(e.name)), 3.0)
	expect(s, "Onda atacando o refugio: firmes nos slots", HOLD)
	# Andando quando a sessao acaba: corpo para e pernas param junto.
	base.health = 50.0
	var walkers: Array = []
	for i in 2:
		walkers.append(spawn(Vector3(-3 + i * 6, 0.5, -5)))
	await seconds(0.8)
	base.take_damage(base.health)
	await frames(2)
	s = await measure("fim_de_sessao", walkers, ["andando1", "andando2"], 1.5)
	check(DayNightManager.is_game_over, "Fim de sessao ativo durante a medicao")
	# Ate 0,6 rad = as pernas voltarem ao repouso uma vez; mais que isso = andando no lugar.
	expect(s, "Fim de sessao: criaturas paradas nao andam no lugar", {"path": 0.01, "leg_idle": 0.6})

	app.show_menu()
	await frames(3)
	if focus_resumes > 0:
		print("NOTA: %d pausa(s) por perda de foco retomada(s); quadros pausados ficaram fora das metricas" % focus_resumes)
	var report := {"passed": passed, "failed": failed, "scenarios": scenarios, "focus_resumes": focus_resumes, "engine": Engine.get_version_info(), "display": DisplayServer.get_name()}
	var destination := "user://creature-motion.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			destination = argument.trim_prefix("--report=")
	var file := FileAccess.open(destination, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("MOTION RESULTS: %d passed; %d failed" % [passed.size(), failed.size()])
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)
