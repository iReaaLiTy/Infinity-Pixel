extends Node

# Regressao da orientacao do Player. Gameplay 5.0: o WASD define a direcao do
# golpe e do modelo; o cursor nao orienta nada.
var passed: Array[String] = []
var failed: Array[String] = []

func check(ok: bool, title: String) -> void:
	(passed if ok else failed).append(title)
	print(("PASS: " if ok else "FAIL: ") + title)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func visual_forward(player: Node3D) -> Vector3:
	var f: Vector3 = -player.get_node("Visual").global_basis.z
	f.y = 0.0
	return f.normalized()

func _ready() -> void:
	var app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	app.start_game()
	await frames(5)
	var world: Node3D = app.world
	var player: CharacterBody3D = world.get_node("Player")
	# Gameplay 5.0: o mouse real (com janela) nao interfere mais na orientacao,
	# entao a suite nao precisa isola-lo.
	var camera: Camera3D = player.get_node("StrategicCamera")
	world.get_node("EncounterSpawner").current_encounter.set_physics_process(false)
	var cam_basis := camera.global_basis
	var cases := {
		"W": [[KEY_W], Vector3(0, 0, -1)],
		"S": [[KEY_S], Vector3(0, 0, 1)],
		"A": [[KEY_A], Vector3(-1, 0, 0)],
		"D": [[KEY_D], Vector3(1, 0, 0)],
		"W+D": [[KEY_W, KEY_D], Vector3(1, 0, -1).normalized()],
		"W+A": [[KEY_W, KEY_A], Vector3(-1, 0, -1).normalized()],
		"S+D": [[KEY_S, KEY_D], Vector3(1, 0, 1).normalized()],
		"S+A": [[KEY_S, KEY_A], Vector3(-1, 0, 1).normalized()],
	}
	for label in cases:
		var keys: Array = cases[label][0]
		var expected: Vector3 = camera.planar_direction(Vector3(cases[label][1].x, 0, cases[label][1].z))
		player.global_position = Vector3(0, .1, 0)
		# Direcao inicial oposta: o WASD precisa sobrescreve-la.
		player.rotation.y = atan2(expected.x, expected.z)
		for k in keys: key(k, true)
		await frames(40)
		var moved := player.global_position - Vector3(0, .1, 0)
		moved.y = 0.0
		var max_jitter := 0.0
		var prev := visual_forward(player)
		for i in 10:
			await frames(1)
			var cur := visual_forward(player)
			max_jitter = maxf(max_jitter, prev.angle_to(cur))
			prev = cur
		for k in keys: key(k, false)
		await frames(2)
		check(moved.normalized().dot(expected) > .99, label + ": move na direcao relativa a camera")
		check(visual_forward(player).dot(expected) > .99, label + ": modelo olha para o movimento")
		check(max_jitter < .01, label + ": sem jitter em regime")
		check(absf(angle_difference(player.rotation.y, atan2(-expected.x, -expected.z))) < .001, label + ": direcao do golpe segue o WASD")
	var last := visual_forward(player)
	await frames(30)
	check(visual_forward(player).is_equal_approx(last), "Parado: mantem ultima orientacao")
	check(camera.global_basis.is_equal_approx(cam_basis), "Camera nao gira com Player")
	# Gameplay 5.0: andando para a direita, o golpe sai para a DIREITA (WASD),
	# mesmo com o clique do mouse feito do outro lado do jogador.
	var dummy = world.get_node("EncounterSpawner").current_encounter
	player.global_position = Vector3(0, .1, 0)
	key(KEY_D, true)
	await frames(30)
	key(KEY_D, false)
	await frames(1)
	var right: Vector3 = camera.planar_direction(Vector3(1, 0, 0))
	dummy.global_position = player.global_position + right * 1.5
	await frames(3)
	var hp_before: float = dummy.hp
	player.get_node("AttackCooldownTimer").stop()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = camera.unproject_position(player.global_position - right * 3.0)
	get_viewport().push_input(click, true)
	await frames(2)
	check(dummy.hp < hp_before, "Ataque atinge o lado do movimento, nao o do cursor")
	check(absf(angle_difference(player.last_attack_yaw, atan2(-right.x, -right.z))) < .01, "Direcao logica do golpe = ultima direcao do WASD")
	await frames(6)
	check(visual_forward(player).dot(right) > .99, "Modelo encara o golpe (giro rapido, sem salto)")
	key(KEY_A, true)
	await frames(40)
	key(KEY_A, false)
	check(visual_forward(player).dot(camera.planar_direction(Vector3(-1, 0, 0))) > .99, "Volta a seguir o movimento apos o golpe")
	print("RESULT: %d/%d" % [passed.size(), passed.size() + failed.size()])
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)
