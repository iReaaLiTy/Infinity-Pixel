extends Node

# Regressao da orientacao visual do Player: movimento -> Visual, cursor -> ataque.
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
	# Esta suite mede a orientacao pelo TECLADO. Com janela, o cursor real do
	# sistema sobre o jogo gera movimento de mouse e ativa a mira continua (correto
	# no jogo), mudando rotation.y no meio da medicao. Isola o mouse real aqui.
	player.set_process_unhandled_input(false)
	player._aim_active = false
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
		# Mira logica (cursor) em direcao oposta, para provar a separacao.
		player.rotation.y = atan2(expected.x, expected.z)
		var aim_before := player.rotation.y
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
		check(absf(angle_difference(player.rotation.y, aim_before)) < .001, label + ": mira logica do ataque intacta")
	var last := visual_forward(player)
	await frames(30)
	check(visual_forward(player).is_equal_approx(last), "Parado: mantem ultima orientacao")
	check(camera.global_basis.is_equal_approx(cam_basis), "Camera nao gira com Player")
	# Andando para a direita, ataque mirado para a esquerda.
	var dummy = world.get_node("EncounterSpawner").current_encounter
	player.global_position = Vector3(0, .1, 0)
	key(KEY_D, true)
	await frames(30)
	key(KEY_D, false)
	await frames(1)
	dummy.global_position = player.global_position + Vector3(-1.5, 0, 0)
	player.rotation.y = atan2(1.0, 0.0) # -Z local aponta para -X mundo
	await frames(3)
	var hp_before: float = dummy.hp
	player.get_node("AttackCooldownTimer").stop()
	player._try_attack()
	check(dummy.hp < hp_before, "Ataque atinge o lado do cursor, nao o do movimento")
	check(visual_forward(player).dot(Vector3(-1, 0, 0)) > .99, "Modelo encara o golpe momentaneamente")
	key(KEY_D, true)
	await frames(40)
	key(KEY_D, false)
	check(visual_forward(player).dot(camera.planar_direction(Vector3(1, 0, 0))) > .99, "Volta a seguir o movimento apos o golpe")
	print("RESULT: %d/%d" % [passed.size(), passed.size() + failed.size()])
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)
