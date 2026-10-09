extends Node

# Balanceamento do combate (playtest 09/10/2026: "o jogador recebe dano demais").
# Jogo real; um "jogador-robo" simples: parado, mira o hostil mais proximo e
# golpeia sempre que o recarregamento deixa. Opcionalmente recua quando um
# hostil prepara o golpe (o que um jogador atento faria). Mede tempos e dano.
# Os limites (check) sao os criterios do balanceamento; o JSON guarda os numeros.
# Uso: Godot [--headless] --path . res://tests/combat_balance.tscn [-- --report=<arquivo>]
const WILD := preload("res://scenes/enemies/wild_dino.tscn")
var passed: Array[String] = []
var failed: Array[String] = []
var metrics := {}
var app
var world: Node3D
var player

func check(ok: bool, label: String) -> void:
	(passed if ok else failed).append(label)
	print(("PASS: " if ok else "FAIL: ") + label)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func fresh_game() -> void:
	app.start_game()
	await frames(8)
	world = app.world
	player = world.get_node("Player")
	player.set_process_unhandled_input(false)
	for d in world.get_node("EncounterSpawner").encounters:
		if is_instance_valid(d): d.queue_free()
	await frames(2)

func spawn(pos: Vector3, night := false):
	var d = WILD.instantiate()
	world.add_child(d)
	d.global_position = pos
	if night:
		d.add_to_group("wave_enemy")
		d.get_node("Visual").set_night_threat()
	return d

func hostiles() -> Array:
	return get_tree().get_nodes_in_group("wild_dino").filter(func(d): return is_instance_valid(d) and d.hp > 0.0)

## Um quadro do robo: mira o hostil mais proximo e golpeia se der.
## `dodge`: recua 1 passo quando um hostil ao alcance esta preparando o golpe.
func bot_step(dodge: bool, stop_hp := 0.0) -> void:
	var best = null
	var best_d := INF
	for d in hostiles():
		var dist: float = Vector2(d.global_position.x - player.global_position.x, d.global_position.z - player.global_position.z).length()
		if dist < best_d and (stop_hp <= 0.0 or d.hp > stop_hp):
			best_d = dist
			best = d
	player.velocity = Vector3.ZERO
	if best == null or player.is_dead:
		return
	var dir: Vector3 = best.global_position - player.global_position
	dir.y = 0.0
	if dodge and best.get("_windup_left") != null and best._windup_left > 0.0 and best_d < 2.6:
		player.global_position -= dir.normalized() * 0.12 # passo para tras
		return
	player.rotation.y = atan2(-dir.x, -dir.z)
	if best_d <= 2.3 and player.attack_cooldown.is_stopped():
		player._try_attack()

func _ready() -> void:
	var report := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report = arg.trim_prefix("--report=")
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame

	# A. Domesticacao: 4 golpes do jogador deixam 80 -> 20 (contrato aprovado).
	await fresh_game()
	player.global_position = Vector3(0, 0.1, -4)
	var tame = spawn(Vector3(0, 0.5, -5.6))
	tame.set_physics_process(false)
	await frames(3) # corpo registrado na fisica antes do primeiro golpe
	for i in 4:
		player.attack_cooldown.stop()
		player.rotation.y = 0.0
		player._try_attack()
		await frames(1)
	check(tame.hp == 20.0 and tame.can_be_domesticated(), "Domesticacao preservada: 4 golpes -> 20/80 HP (%.0f)" % tame.hp)

	# B. Jogador parado x 1 selvagem de dia, ate o selvagem ficar domesticavel.
	await fresh_game()
	player.global_position = Vector3(0, 0.1, -4)
	var w = spawn(Vector3(0, 0.5, 1))
	var t := 0
	while t < 60 * 20 and not w.can_be_domesticated() and not player.is_dead:
		bot_step(false, 24.0)
		await get_tree().physics_frame
		t += 1
	metrics["dia_1x1_enfraquecer_s"] = snappedf(t / 60.0, 0.01)
	metrics["dia_1x1_vida_perdida"] = 100.0 - player.current_hp
	check(w.can_be_domesticated() and player.current_hp >= 55.0, "Dia 1x1: enfraquece o selvagem e sobra vida (perdeu %.0f em %.1f s)" % [100.0 - player.current_hp, t / 60.0])

	# C. Jogador parado x 3 inimigos da noite, sem ajuda: quanto aguenta.
	await fresh_game()
	player.global_position = Vector3(0, 0.1, -6)
	DayNightManager.state = DayNightManager.State.NIGHT
	for p in [Vector3(-2, 0.5, -2), Vector3(2, 0.5, -2), Vector3(0, 0.5, -1)]:
		spawn(p, true)
	t = 0
	var killed := 0
	while t < 60 * 15 and not player.is_dead and not hostiles().is_empty():
		bot_step(false)
		await get_tree().physics_frame
		t += 1
	killed = 3 - hostiles().size()
	metrics["noite_1x3_parado_s"] = snappedf(t / 60.0, 0.01)
	metrics["noite_1x3_parado_abatidos"] = killed
	metrics["noite_1x3_parado_vida"] = player.current_hp
	print("[BAL] 1x3 parado: %.1f s, %d abatidos, vida %.0f" % [t / 60.0, killed, player.current_hp])
	check(t / 60.0 >= 6.0, "Noite 1x3 parado: o jogador nao cai em menos de 6 s (%.1f s)" % [t / 60.0])

	# D. Mesmo cenario, jogador que recua quando o inimigo prepara o golpe.
	await fresh_game()
	player.global_position = Vector3(0, 0.1, -6)
	DayNightManager.state = DayNightManager.State.NIGHT
	var trio := []
	for p in [Vector3(-2, 0.5, -2), Vector3(2, 0.5, -2), Vector3(0, 0.5, -1)]:
		trio.append(spawn(p, true))
	t = 0
	while t < 60 * 20 and not player.is_dead and not hostiles().is_empty():
		bot_step(true)
		await get_tree().physics_frame
		t += 1
	var dealt := 0.0
	for f in trio:
		dealt += 80.0 - (f.hp if is_instance_valid(f) else 0.0)
	metrics["noite_1x3_esquiva_s"] = snappedf(t / 60.0, 0.01)
	metrics["noite_1x3_esquiva_abatidos"] = 3 - hostiles().size()
	metrics["noite_1x3_esquiva_dano_causado"] = dealt
	metrics["noite_1x3_esquiva_vida"] = player.current_hp
	print("[BAL] 1x3 com recuo: %.1f s, %d abatidos, %.0f de dano causado, vida %.0f" % [t / 60.0, 3 - hostiles().size(), dealt, player.current_hp])
	check(t / 60.0 >= 7.0 and dealt >= 120.0, "Noite 1x3 recuando: resiste >= 7 s e causa >= 120 de dano (%.1f s, %.0f)" % [t / 60.0, dealt])

	# E. Aliado x inimigo da noite, 1x1 (o aliado precisa valer a pena).
	await fresh_game()
	player.global_position = Vector3(0, 0.1, -16)
	player._invulnerable_left = INF
	DayNightManager.state = DayNightManager.State.NIGHT
	var ally = spawn(Vector3(0, 0.5, -4))
	ally.domesticate()
	ally.ally_state = 1
	ally._stay_position = ally.global_position
	var foe = spawn(Vector3(0, 0.5, 0), true)
	t = 0
	while t < 60 * 15 and is_instance_valid(foe) and is_instance_valid(ally) and ally.hp > 0.0:
		await get_tree().physics_frame
		t += 1
	var ally_won: bool = not is_instance_valid(foe) and is_instance_valid(ally)
	metrics["aliado_1x1_vence"] = ally_won
	metrics["aliado_1x1_vida_restante"] = ally.hp if is_instance_valid(ally) else 0.0
	check(ally_won, "Aliado x inimigo noturno 1x1: o aliado vence (vida %.0f)" % (ally.hp if is_instance_valid(ally) else 0.0))

	# F. Primeira noite real com decisoes razoaveis: 1 torre no posto da estrada,
	# 1 aliado em FICAR na frente do Refugio e o robo lutando perto da base.
	await fresh_game()
	player.global_position = Vector3(0, 0.1, -9)
	var guard = spawn(Vector3(0, 0.5, -7))
	guard.domesticate()
	guard.ally_state = 1
	guard._stay_position = guard.global_position
	world.get_node("DefenseSlots/SlotRuinMeadow").build()
	var base = world.get_node("Territory")
	DayNightManager.start_night()
	t = 0
	while t < 60 * 90 and DayNightManager.is_night() and not DayNightManager.is_game_over:
		bot_step(true)
		await get_tree().physics_frame
		t += 1
	metrics["noite1_vencida"] = not DayNightManager.is_night() and not DayNightManager.is_game_over
	metrics["noite1_refugio"] = base.health
	metrics["noite1_jogador_vida"] = player.current_hp
	metrics["noite1_tempo_s"] = snappedf(t / 60.0, 0.01)
	print("[BAL] Noite 1 (torre + aliado + jogador): vencida=%s refugio=%.0f jogador=%.0f em %.1f s" % [metrics.noite1_vencida, base.health, player.current_hp, t / 60.0])
	check(metrics.noite1_vencida and base.health >= 50.0, "Primeira noite com 1 torre + 1 aliado: vencida com o Refugio >= 50 (%.0f)" % base.health)

	print("[BAL] %s" % JSON.stringify(metrics))
	print("BALANCE RESULTS: %d passed; %d failed" % [passed.size(), failed.size()])
	if report != "":
		var f := FileAccess.open(report, FileAccess.WRITE)
		f.store_string(JSON.stringify({"passed": passed, "failed": failed, "metrics": metrics}, "\t"))
		f.close()
	get_tree().quit(0 if failed.is_empty() else 1)
