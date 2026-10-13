extends Node

# Direcao do golpe do Player. Gameplay 5.0 (playtest externo): o golpe sai na
# direcao em que o heroi OLHA (WASD); o cursor, agora oculto, nao orienta nada.
# Cliques REAIS do mouse (push_input), quase sempre feitos ATRAS do jogador
# para provar que a posicao do cursor e ignorada.
# Uso: Godot [--headless] --path . res://tests/attack_direction.tscn [-- --report=<arquivo>]
const WILD := preload("res://scenes/enemies/wild_dino.tscn")
var passed: Array[String] = []
var failed: Array[String] = []
var app
var world: Node3D
var player
var cam: Camera3D

func check(ok: bool, label: String) -> void:
	(passed if ok else failed).append(label)
	print(("PASS: " if ok else "FAIL: ") + label)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## Clique fisico com o cursor no ponto de tela de `world_point`.
func click_at(world_point: Vector3) -> void:
	player.get_node("AttackCooldownTimer").stop()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = cam.unproject_position(world_point)
	get_viewport().push_input(ev, true)
	var up := ev.duplicate()
	up.pressed = false
	get_viewport().push_input(up, true)
	await frames(2)

## Clique com o cursor 3 m ATRAS do jogador (o lado oposto ao que ele olha).
func click_behind() -> void:
	await click_at(player.global_position + player.global_basis.z * 3.0)

func dummy(pos: Vector3):
	var d = WILD.instantiate()
	world.add_child(d)
	d.global_position = pos
	d.set_physics_process(false)
	d.hp = 500.0 # so mede golpes; nunca morre nem fica domesticavel
	return d

func yaw_to(p: Vector3) -> float:
	var d: Vector3 = p - player.global_position
	return atan2(-d.x, -d.z)

func _ready() -> void:
	var report := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report = arg.trim_prefix("--report=")
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	app.start_game()
	await frames(10)
	world = app.world
	player = world.get_node("Player")
	cam = player.get_node("StrategicCamera")
	cam.follow_smoothing = 0.0
	player._invulnerable_left = INF
	for d in world.get_node("EncounterSpawner").encounters:
		if is_instance_valid(d): d.queue_free()
	var origin := Vector3(2.0, 0.1, -3.0) # patio aberto, sem coletaveis perto
	player.global_position = origin
	await frames(5)

	# 1. Oito direcoes: virado para o dinossauro, com o cursor atras, acerta ELE.
	var ok_dirs := 0
	var worst := 0.0
	for i in 8:
		var a := TAU * i / 8.0
		var spot := origin + Vector3(sin(a), 0, cos(a)) * 1.8
		spot.y = 0.5
		var d = dummy(spot)
		player.face_toward(d.global_position)
		await frames(2)
		var before: float = d.hp
		await click_behind()
		var err := absf(rad_to_deg(angle_difference(player.last_attack_yaw, yaw_to(d.global_position))))
		worst = maxf(worst, err)
		if d.hp < before and err < 2.0:
			ok_dirs += 1
		d.queue_free()
		await frames(2)
	check(ok_dirs == 8, "8 direcoes: virado para o dinossauro, cursor atras, acerta ele (%d/8, maior desvio %.1f graus)" % [ok_dirs, worst])
	await frames(30)
	check(absf(angle_difference(player._facing_yaw, player.last_attack_yaw)) < 0.05, "O modelo termina virado para o ultimo golpe (sem giro descontrolado)")

	# 2. Arvores coletaveis pelo sul, leste e oeste: cursor atras, golpe no tronco.
	var trees: Array = get_tree().get_nodes_in_group("collectable").filter(func(c): return c.kind == "wood")
	var tree_ok := 0
	var tree_worst := 0.0
	var approaches := [Vector3(0, 0.1, 2.2), Vector3(2.2, 0.1, 0.3), Vector3(-2.2, 0.1, 0.3)]
	for i in approaches.size():
		var tree: Node3D = trees[i]
		player.global_position = tree.global_position + approaches[i]
		player.face_toward(tree.global_position)
		await frames(4)
		var tree_hp: float = tree.hp
		await click_behind()
		var err := absf(rad_to_deg(angle_difference(player.last_attack_yaw, yaw_to(tree.global_position))))
		tree_worst = maxf(tree_worst, err)
		if tree.hp < tree_hp and err < 2.0:
			tree_ok += 1
	check(tree_ok == 3, "Arvore a frente, cursor atras: acerta, de 3 lados (%d/3)" % tree_ok)
	check(tree_worst < 2.0, "Arvore: golpe na direcao do tronco (maior desvio %.1f graus)" % tree_worst)

	# 3. Rocha coletavel, chegando pela diagonal.
	var stone: Node3D = null
	for c in get_tree().get_nodes_in_group("collectable"):
		if c.kind == "stone":
			stone = c
			break
	player.global_position = stone.global_position + Vector3(1.8, 0.1, 1.6)
	player.face_toward(stone.global_position)
	await frames(4)
	var stone_hp: float = stone.hp
	await click_behind()
	check(stone.hp < stone_hp, "Rocha na diagonal a frente, cursor atras: acerta (%.0f -> %.0f)" % [stone_hp, stone.hp])
	# Rocha larga de lado (borda dentro do cone): ainda conta como a frente.
	stone_hp = stone.hp
	player.global_position = stone.global_position + Vector3(1.4, 0.1, 0.9)
	player.rotation.y = yaw_to(stone.global_position) + deg_to_rad(60.0)
	await frames(3)
	await click_behind()
	check(stone.hp < stone_hp, "Rocha colada de lado (60 graus): a borda dela esta a frente e leva o golpe")

	# 4. Alvo a frente fora do alcance: sem dano, com aviso.
	player.global_position = origin
	player.rotation.y = 0.0
	await frames(3)
	var far = dummy(origin + Vector3(0, 0.4, -4.5))
	var warned := [false]
	player.attack_out_of_range.connect(func(t): warned[0] = t == far, CONNECT_ONE_SHOT)
	await frames(2)
	var far_hp: float = far.hp
	await click_behind()
	check(far.hp == far_hp and warned[0], "Fora do alcance (4,5 m a frente): sem dano e com aviso")
	far.queue_free()

	# 5. Objeto proximo nao rouba o golpe: vizinho ao lado, alvo na frente.
	var side = dummy(origin + Vector3(-1.4, 0.4, 0.2))
	var front = dummy(origin + Vector3(0.3, 0.4, -1.7))
	player.face_toward(front.global_position)
	await frames(3)
	var side_hp: float = side.hp
	var front_hp: float = front.hp
	await click_behind()
	check(front.hp < front_hp and side.hp == side_hp, "Alvo a frente leva o golpe; o vizinho ao lado nao")
	# Dois alvos no cone: o mais ALINHADO vence, mesmo um pouco mais longe; um alvo por golpe.
	side.global_position = origin + Vector3(0.9, 0.4, -0.9) # 45 graus, 1,3 m
	front.global_position = origin + Vector3(0, 0.4, -1.8) # reto, 1,8 m
	player.rotation.y = 0.0
	await frames(3)
	side_hp = side.hp
	front_hp = front.hp
	await click_behind()
	check(front.hp == front_hp - 15.0 and side.hp == side_hp, "Dois alvos a frente: so o mais alinhado leva o golpe (um alvo por golpe)")
	side.queue_free()
	front.queue_free()

	# 6. So um alvo ATRAS: o golpe frontal nao o atinge, nem com o cursor sobre ele.
	var back = dummy(origin + Vector3(0, 0.4, 1.5))
	player.rotation.y = 0.0
	await frames(3)
	var back_hp: float = back.hp
	await click_at(back.global_position + Vector3(0, 1.0, 0))
	check(back.hp == back_hp and is_equal_approx(player.last_attack_yaw, 0.0), "Alvo atras com o cursor sobre ele: nao e atingido e o heroi nao vira")
	back.queue_free()

	# 7. Aliado e Refugio nunca sao alvo do golpe.
	player.global_position = origin
	var ally = dummy(origin + Vector3(1.6, 0.4, 0))
	ally.domesticate()
	ally.hp = 80.0
	player.face_toward(ally.global_position)
	await frames(3)
	await click_behind()
	var base = world.get_node("Territory")
	player.global_position = Vector3(0, 0.1, -12.2)
	player.face_toward(base.global_position)
	await frames(3)
	await click_behind()
	check(ally.hp == 80.0 and base.health == base.max_health, "Aliado e Refugio nao sao atingidos pelo golpe")

	# 8. Cooldown: dois cliques seguidos num alvo = um golpe so.
	player.global_position = origin
	player.rotation.y = 0.0
	await frames(3)
	var cd = dummy(origin + Vector3(0, 0.4, -1.6))
	await frames(2)
	var cd_hp: float = cd.hp
	await click_behind()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = cam.unproject_position(player.global_position + Vector3(3, 0, 0))
	get_viewport().push_input(ev, true)
	await frames(2)
	check(cd.hp == cd_hp - 15.0, "Cooldown: segundo clique imediato nao causa dano extra")

	# 9. Cursor em 4 lados diferentes: mesma direcao e mesmo alvo.
	var yaws := []
	var hits := 0
	for offset in [Vector3(0, 0, -3), Vector3(0, 0, 3), Vector3(3, 0, 0), Vector3(-3, 0, 0)]:
		var hp_before: float = cd.hp
		await click_at(player.global_position + offset)
		yaws.append(player.last_attack_yaw)
		if cd.hp == hp_before - 15.0: hits += 1
	check(hits == 4 and yaws.all(func(y): return is_equal_approx(y, 0.0)), "Cursor a frente, atras e dos lados: 4 golpes iguais na direcao do heroi")

	print("ATTACK DIRECTION RESULTS: %d passed; %d failed" % [passed.size(), failed.size()])
	if report != "":
		var f := FileAccess.open(report, FileAccess.WRITE)
		f.store_string(JSON.stringify({"passed": passed, "failed": failed}, "\t"))
		f.close()
	get_tree().quit(0 if failed.is_empty() else 1)
