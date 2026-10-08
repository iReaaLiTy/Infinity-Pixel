extends Node
var app: Node
var passed: Array[String] = []
var failed: Array[String] = []
var metrics := {}
func check(ok: bool, title: String) -> void:
	(passed if ok else failed).append(title)
	print(("PASS: " if ok else "FAIL: ") + title)
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame

# Clique real: passa pelo _unhandled_input do Player (mesmo caminho do mouse).
func click() -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = get_viewport().get_visible_rect().size / 2.0
		get_viewport().push_input(ev, true)

# Spec 003 x Spec 015: o dono da segurada de E decide se o clique ataca.
func interaction_checks() -> void:
	app.start_game()
	await frames(6)
	var world = app.world
	var player = world.get_node("Player")
	var dom = player.get_node("DomesticationChannel")
	var tm = world.get_node("TerritoryManager")
	player._invulnerable_left = INF
	var gw = tm.guardians[&"west"]
	gw.take_damage(gw.MAX_HP) # guardiao derrotado: Oeste pronto para recuperar
	await frames(3)
	player.global_position = tm.markers[&"west"].global_position + Vector3(0, .1, 1.5)
	await frames(3)
	player.attack_cooldown.stop()
	Input.action_press("domesticate")
	await frames(30)
	var claiming_before: bool = tm.claim_progress() > 0.1
	var attacks: int = player.attack_count
	click()
	await frames(3)
	check(claiming_before and player.attack_count == attacks + 1 and tm.claim_progress() == 0.0, "Clique real durante a recuperacao ataca uma vez e cancela (RF-TER-005)")
	await frames(40)
	check(tm.claim_progress() == 0.0 and dom.get_progress() == 0.0 and player.attack_count == attacks + 1, "A mesma segurada de E nao recomeca o marco nem domestica")
	Input.action_release("domesticate")
	await frames(3)
	Input.action_press("domesticate")
	await frames(20)
	check(tm.claim_progress() > 0.0, "Nova segurada de E recomeca a recuperacao do zero")
	Input.action_release("domesticate")
	await frames(3)
	# Domesticacao (Spec 003): o clique real nao ataca nem consome cooldown.
	var wild = load("res://scenes/enemies/wild_dino.tscn").instantiate()
	wild.territorial = true
	wild.position = player.global_position + Vector3(1.2, 0, 0)
	world.add_child(wild)
	wild.set_physics_process(false)
	wild.hp = 20
	player.attack_cooldown.stop()
	Input.action_press("domesticate")
	await frames(20)
	attacks = player.attack_count
	click()
	await frames(3)
	check(dom.get_progress() > 0.0 and dom.e_hold_owner == "domesticate" and player.attack_count == attacks and player.attack_cooldown.is_stopped() and wild.hp == 20, "Clique real com E na domesticacao nao ataca nem consome cooldown")
	Input.action_release("domesticate")
	await frames(3)
	wild.queue_free()
	await frames(2)
	# Construcao (Spec 013D): o clique confirma a obra, nunca vira golpe.
	world.get_node("ResourceStock").add(&"wood", 20)
	world.get_node("ResourceStock").add(&"stone", 12)
	var placer = world.get_node("BuildPlacer")
	player.global_position = world.get_node("WorldRegions/SafeZone/BuildZone").global_position + Vector3(0, .1, 3)
	await frames(3)
	player.attack_cooldown.stop()
	placer.begin(&"campfire")
	attacks = player.attack_count
	click()
	await frames(3)
	check(player.attack_count == attacks, "Clique real durante o posicionamento nao ataca")
	if placer.is_placing(): placer.cancel()
	# Sem E e sem obra: um clique = um golpe.
	await frames(3)
	player.attack_cooldown.stop()
	attacks = player.attack_count
	click()
	await frames(3)
	check(player.attack_count == attacks + 1, "Sem E e sem construcao, um clique = um golpe")
func _ready() -> void:
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	app.start_game()
	await frames(10)
	DayNightManager.set_process(false)
	var world = app.world
	var player = world.get_node("Player")
	player._invulnerable_left = INF
	for d in get_tree().get_nodes_in_group("wild_dino"): d.queue_free()
	await frames(2)
	var dino = load("res://scenes/enemies/wild_dino.tscn").instantiate()
	dino.position = Vector3(2, 0, 4)
	dino.territorial = true
	world.add_child(dino)
	player.position = Vector3(18, 1, -10)
	await frames(120)
	var origin: Vector3 = dino.position
	await frames(180)
	check(dino.position.distance_to(origin) < .01, "Territorial ocioso permanece estavel por 3 s")
	dino.set_physics_process(false)
	var ally = load("res://scenes/enemies/wild_dino.tscn").instantiate()
	world.add_child(ally)
	ally.domesticate()
	ally.set_physics_process(false)
	player.position = dino.position + Vector3(2, 0, 0)
	ally.position = dino.position + Vector3(-2.05, 0, 0)
	dino._target = player
	var switches := 0
	for i in 30:
		ally.position.x = dino.position.x - (1.95 if i % 2 == 0 else 2.05)
		var next: Node3D = dino._find_nearest_target()
		if next != dino._target: switches += 1
		dino._target = next
	metrics.target_switches = switches
	check(switches == 0, "Alvos quase equidistantes nao causam alternancia continua")
	ally.position = dino.position + Vector3(-.8, 0, 0)
	check(dino._find_nearest_target() == ally, "Ameaca claramente mais proxima ainda pode assumir prioridade")
	dino.rotation.y = 0
	dino._frame_delta = 1.0 / 60.0
	dino._face(Vector3.RIGHT)
	metrics.turn_one_frame = absf(dino.rotation.y)
	check(absf(dino.rotation.y) <= .2, "Virada limitada por quadro, sem salto instantaneo")
	dino.velocity = Vector3(4, 0, 0)
	var visual = dino.get_node("Visual")
	visual.set_process(false)
	visual._process(.1)
	check(absf(visual.get_node("LegL").rotation.x) < .01, "Sem deslocamento real, pernas nao caminham por velocidade residual")
	var hp: float = dino.hp
	dino.take_damage(-10)
	check(dino.hp == hp, "Dano negativo nao cura criatura")
	dino.hp = hp
	player.attack_cooldown.stop()
	world.get_node("ResourceStock").add(&"wood", 20)
	world.get_node("ResourceStock").add(&"stone", 12)
	var placer = world.get_node("BuildPlacer")
	placer.begin(&"campfire")
	var attacks: int = player.attack_count
	player._attack_queued = true
	player._on_attack_ready()
	check(player.attack_count == attacks, "Ataque guardado nao dispara durante construcao")
	placer.cancel()
	player.attack_cooldown.stop()
	player.channel.e_hold_owner = "domesticate"
	Input.action_press("domesticate")
	player._attack_queued = true
	player._on_attack_ready()
	check(player.attack_count == attacks, "Ataque guardado nao dispara durante domesticacao")
	Input.action_release("domesticate")
	player.channel.reset_channel()
	var resource = get_tree().get_nodes_in_group("collectable")[0]
	resource.take_damage(resource.hp)
	resource.restore()
	await frames(90)
	check(resource._visual.visible and resource._visual.scale.length() > 1, "Amanhecer durante queda do recurso nao o esconde depois")
	await interaction_checks()
	app.show_menu()
	await frames(3)
	var dest := "user://gameplay-stability.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): dest = arg.trim_prefix("--report=")
	FileAccess.open(dest, FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed,"metrics":metrics}, "  "))
	print("STABILITY RESULTS: %d passed; %d failed" % [passed.size(),failed.size()])
	get_tree().quit(0 if failed.is_empty() else 1)
