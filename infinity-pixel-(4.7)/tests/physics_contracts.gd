extends Node

# Real scene/physics regression for Spec 009. No replacement movement or AI.
const WORLD := 1 << 0
const PLAYER := 1 << 1
const CREATURES := 1 << 2
const BUILDINGS := 1 << 3
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

func _ready() -> void:
	var app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	app.start_game()
	await frames(5)
	var world: Node3D = app.world
	var player: CharacterBody3D = world.get_node("Player")
	var camera: Camera3D = player.get_node("StrategicCamera")
	var encounter = world.get_node("EncounterSpawner").current_encounter
	encounter.set_physics_process(false)
	check(player.collision_layer == PLAYER and player.collision_mask == (WORLD | CREATURES | BUILDINGS), "Player: camada 2; mascara mundo/criaturas/construcoes")
	check(encounter.collision_layer == CREATURES and encounter.collision_mask == (WORLD | PLAYER | BUILDINGS), "WildDino: mascara mundo/player/construcoes, sem criaturas")
	var carno = load("res://scenes/enemies/carnotauro.tscn").instantiate()
	check(carno.collision_layer == CREATURES and carno.collision_mask == encounter.collision_mask, "Carnotauro compartilha contrato fisico")
	carno.free()
	var solids := world.get_node("ArenaCollision").get_children()
	var valid := solids.size() == 66
	for body in solids:
		valid = valid and body is StaticBody3D and body.scale.is_equal_approx(Vector3.ONE) and body.collision_mask == 0
		valid = valid and body.get_node("CollisionShape3D").shape is Shape3D
	check(valid, "66 obstaculos estaticos com primitivas e escala unitaria")
	var area: Area3D = player.get_node("AttackArea3D")
	check(area.collision_layer == 0 and area.collision_mask == CREATURES, "Area de ataque detecta apenas criaturas e nao e corpo solido")
	check(camera.top_level and is_equal_approx(camera.fov, 50.0), "Camera estrategica preservada")
	var camera_basis := camera.global_basis
	player.rotation.y = 1.2
	await frames(2)
	check(camera.global_basis.is_equal_approx(camera_basis), "Camera nao gira com Player")
	player.global_position = Vector3(0, .1, 0)
	key(KEY_W, true)
	await frames(30)
	key(KEY_W, false)
	check(player.position.z < -2 and absf(player.position.x) < .1, "W real move na direcao da camera apesar da rotacao do Player")
	player.set_physics_process(false)
	for obstacle_name in ["Trunk0", "Rock0", "ArchPillar-1", "RefugeCore"]:
		var obstacle: StaticBody3D = world.get_node("ArenaCollision/" + obstacle_name)
		# Start near the chosen surface; distant approaches in the grove can hit another tree first.
		player.global_position = Vector3(obstacle.position.x, .05, obstacle.position.z + 1.4)
		player.velocity = Vector3.ZERO
		await frames(2)
		var result := KinematicCollision3D.new()
		var hit := player.test_move(player.global_transform, Vector3(0, 0, -4), result)
		check(hit and result.get_collider() == obstacle, "Capsula bloqueada por " + obstacle_name)
		for i in 45:
			await frames(1)
			player.velocity = Vector3(0, -1, -6)
			player.move_and_slide()
		check(player.position.z > obstacle.position.z + .4, "move_and_slide nao atravessa " + obstacle_name)
	# Spec 012: locate the actual boundary instead of the old 40 m arena edge.
	var boundary: StaticBody3D = world.get_node("ArenaArt/Boundary0")
	player.global_position = Vector3(boundary.position.x - .9, .05, 0)
	for i in 60:
		await frames(1)
		player.velocity = Vector3(4.24, -1, -4.24)
		player.move_and_slide()
	check(player.position.x < boundary.position.x - .59 and player.position.z < -3.5, "Movimento diagonal desliza ao longo da parede")
	# GUI gets the event before _unhandled_input, even with live gameplay.
	player.global_position = Vector3.ZERO
	player.set_physics_process(true)
	var cooldown: Timer = player.get_node("AttackCooldownTimer")
	cooldown.stop()
	await frames(3)
	var panel: PanelContainer = app.hud.find_children("*", "PanelContainer", true, false)[0]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = panel.get_global_rect().get_center()
	get_viewport().push_input(click, true)
	await frames(3)
	check(cooldown.is_stopped(), "Clique em painel HUD nao inicia ataque")
	app.pause_game()
	app.show_controls(app._show_pause_menu)
	check(get_tree().paused and app._is_showing_controls(), "Controles da pausa abre mantendo pausa")
	app._leave_controls()
	check(get_tree().paused and not app._is_showing_controls(), "Voltar de Controles retorna a pausa")
	app.resume_game()
	# Keep actual default AI; isolate its route from detection of player/encounter.
	player.set_physics_process(false)
	player.remove_from_group("player")
	player.collision_layer = 0
	player.collision_mask = 0
	player.position = Vector3(0, 0, -30)
	var enemy = load("res://scenes/enemies/wild_dino.tscn").instantiate()
	enemy.position = world.get_node("EnemySpawnPoint").position
	world.add_child(enemy)
	await frames(570 + 30) # balanceamento 09/10/2026: o golpe sai apos 0,4 s de preparacao
	check(world.get_node("Territory").health < 100, "IA direta percorre corredor spawn-base e causa dano real")
	check(enemy.position.distance_to(world.get_node("Territory").position) < 1.6, "Colisor do nucleo permite alcance atual de ataque a base")
	var ally_mask: int = enemy.collision_mask
	enemy.take_damage(60)
	enemy.domesticate()
	check(enemy.collision_mask == ally_mask and enemy.hp == 80, "Domesticar preserva mascara fisica e restaura a vida (Spec 013C)")
	app.show_menu()
	await frames(3)
	var report := {"passed": passed, "failed": failed, "engine": Engine.get_version_info(), "display": DisplayServer.get_name()}
	var destination := "user://spec009-physics.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			destination = argument.trim_prefix("--report=")
	var file := FileAccess.open(destination, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("SPEC009 RESULTS: %d passed; %d failed" % [passed.size(), failed.size()])
	# Let local Resource references leave _ready before the engine tears down.
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)
