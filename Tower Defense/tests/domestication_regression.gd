extends Node

# Spec 003: complementa acceptance.tscn com casos de entrada e ciclo de vida.
# Usa a cena real, com atores parados apenas para isolar alcance e input.
# Não representa aprovação humana de controle, câmera ou dificuldade.
var app: Node
var player: Node3D
var channel: Node
var dino: Node3D
var passed: Array[String] = []
var failed: Array[String] = []

func check(ok: bool, title: String) -> void:
	(passed if ok else failed).append(title)
	print(("PASS: " if ok else "FAIL: ") + title)

func wait(seconds: float = 0.1) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func key_e(pressed: bool, physical: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.physical_keycode = KEY_E if physical else 0
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func attack_click() -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)

func press_test_spawn() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_T
		event.keycode = KEY_T
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func reset_case() -> void:
	key_e(false)
	key_e(false, false)
	app.start_game()
	await wait()
	player = app.world.get_node("Player")
	channel = player.get_node("DomesticationChannel")
	dino = app.world.get_node("EncounterSpawner").current_encounter
	dino.set_physics_process(false)
	player.set_physics_process(false)
	player.global_position = dino.global_position + Vector3(0, 0, 1.5)
	player.rotation.y = 0
	await wait()

func spawn_other(scene: String, offset: Vector3, hp: float) -> Node3D:
	var other = load(scene).instantiate()
	other.position = player.global_position + offset
	other.territorial = true
	app.world.add_child(other)
	other.set_physics_process(false)
	other.hp = hp
	return other

func _ready() -> void:
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	# Aguarda a abertura/foco inicial da janela ainda no menu.
	await wait(0.6)
	await reset_case()
	key_e(true)
	await wait(0.25)
	check(channel.get_progress() == 0 and dino.get_node("PromptLabel3D").text.is_empty(), "HP acima do limiar: sem aviso nem canalização")
	key_e(false)
	# Golpes reais por overlap; sem atribuir HP neste fluxo principal.
	for i in range(3):
		player._try_attack()
		await wait(0.85)
	check(dino.hp == 20, "Três golpes deixam alvo vivo com 20/80 HP")
	check(not dino.get_node("PromptLabel3D").text.is_empty(), "Alvo enfraquecido próximo mostra opção")
	key_e(true)
	await wait(0.25)
	check(channel.get_progress() > 0 and dino.is_being_domesticated, "E físico inicia canalização e suspende hostilidade")
	# Toda entrada de ataque deve respeitar a canalização, inclusive chamadas diretas.
	player._try_attack()
	check(is_instance_valid(dino) and dino.hp == 20 and player.attack_cooldown.is_stopped(), "Ataque durante E não fere alvo nem consome cooldown")
	key_e(false)
	await wait()

	await reset_case()
	dino.take_damage(60)
	key_e(true, false)
	await wait(0.25)
	check(not Input.is_action_pressed("domesticate") and channel.get_progress() > 0, "E lógico alternativo inicia canalização sem ação física do Input Map")
	if DisplayServer.get_name() != "headless":
		attack_click()
		check(is_instance_valid(dino) and dino.hp == 20, "Clique não mata alvo quando E é reconhecido pelo caminho alternativo")
	else:
		player._try_attack()
		check(is_instance_valid(dino) and dino.hp == 20, "Ataque direto respeita E reconhecido pelo caminho alternativo")
	key_e(false, false)
	await wait()
	if is_instance_valid(dino):
		check(channel.get_progress() == 0 and not dino.is_being_domesticated, "Soltar E alternativo cancela e libera criatura")
		await wait(0.85)
		if DisplayServer.get_name() != "headless": attack_click()
		else: player._try_attack()
		check(dino.hp <= 0, "Após soltar E, o quarto golpe volta a derrotar normalmente")

	await reset_case()
	dino.take_damage(60)
	var full = spawn_other("res://scenes/enemies/wild_dino.tscn", Vector3(1, 0, 0), 80)
	var carno = spawn_other("res://scenes/enemies/carnotauro.tscn", Vector3(-0.8, 0, 0), 20)
	key_e(true)
	await wait(0.3)
	check(channel._target == dino and channel.get_progress() > 0, "Selvagem saudável e Carnotauro mais próximos não ocultam elegível")
	check(carno.get_node("PromptLabel3D").text.is_empty() and not carno.is_being_domesticated, "Não domesticável próximo não recebe aviso nem canalização")
	var second = spawn_other("res://scenes/enemies/wild_dino.tscn", Vector3(0.9, 0, 0), 20)
	await wait(0.3)
	check(channel._target == dino and channel.get_progress() > 0.2, "Segundo elegível mais próximo não rouba canalização")
	await wait(1.5)
	key_e(false)
	await wait()
	check(dino.is_domesticated and dino.hp == 20 and dino.is_in_group("domesticated") and not dino.is_in_group("wild_dino"), "Conversão mantém indivíduo e HP e troca grupos de hostilidade")
	check(dino.ally_state == 0 and dino.get_node("PromptLabel3D").text.is_empty(), "Aliado inicia seguindo e perde aviso de domesticação")
	full.queue_free()
	carno.queue_free()
	second.queue_free()
	await wait()
	var trigger = app.world.get_node("WaveTestTrigger")
	press_test_spawn()
	check(get_tree().get_nodes_in_group("wild_dino").is_empty(), "T desligado por padrão não cria inimigos")
	trigger.debug_enabled = true
	for i in range(2):
		press_test_spawn()
		await wait()
	check(is_instance_valid(dino) and dino.is_domesticated and get_tree().get_nodes_in_group("wild_dino").size() == 1, "T de depuração preserva aliado e substitui apenas selvagem de teste")

	await reset_case()
	dino.queue_free()
	await wait()
	carno = spawn_other("res://scenes/enemies/carnotauro.tscn", Vector3(0, 0, -1.5), 20)
	key_e(true)
	await wait(2.2)
	check(channel.get_progress() == 0 and not carno.is_domesticated and carno.is_in_group("wild_dino") and carno.get_node("PromptLabel3D").text.is_empty(), "E por mais de 2 s não domestica Carnotauro nem mostra falsa opção")
	key_e(false)

	await reset_case()
	dino.take_damage(60)
	key_e(true)
	await wait(0.4)
	player.global_position += Vector3(5, 0, 0)
	await wait()
	check(channel.get_progress() == 0 and not dino.is_being_domesticated, "Afastar cancela e libera alvo")
	player.global_position = dino.global_position + Vector3(0, 0, 1.5)
	await wait(0.2)
	check(channel.get_progress() > 0 and channel.get_progress() < 0.2, "Reaproximar reinicia progresso do zero")
	app.pause_game()
	key_e(false)
	await wait()
	check(channel.get_progress() == 0 and not dino.is_being_domesticated, "Pausa cancela e soltar E durante pausa não prende alvo")
	app.resume_game()
	await wait(0.2)
	check(channel.get_progress() == 0, "Retomar com E solto não reinicia canalização")
	key_e(true)
	await wait(0.2)
	app.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	key_e(false)
	await wait()
	check(app.screen == "paused" and channel.get_progress() == 0 and not dino.is_being_domesticated, "Perda de foco pausa e cancela domesticação")
	app.resume_game()
	await wait()
	check(channel.get_progress() == 0, "Retorno de foco não conserva E preso")

	await reset_case()
	dino.take_damage(60)
	key_e(true)
	await wait(0.3)
	dino.take_damage(20)
	await wait()
	check(not is_instance_valid(dino) and channel.get_progress() == 0, "Morte por dano externo cancela sem converter ou ressuscitar alvo")
	key_e(false)

	await reset_case()
	dino.take_damage(60)
	key_e(true)
	await wait(0.3)
	dino.queue_free()
	# Mesmo frame: alvo enfileirado para remoção já deve ser inelegível.
	channel._physics_process(2.0)
	check(not dino.is_domesticated and channel.get_progress() == 0, "Remoção pendente cancela antes de emitir conversão no mesmo frame")
	key_e(false)
	await wait()

	await reset_case()
	dino.take_damage(60)
	key_e(true)
	await wait(0.3)
	app.world.get_node("Territory").take_damage(100)
	check(channel.get_progress() == 0 and not dino.is_being_domesticated, "Derrota cancela canalização e libera criatura")
	key_e(false)
	app.show_menu()
	await wait()
	app.queue_free()
	await wait(0.2)
	var report := {"passed": passed, "failed": failed, "engine": Engine.get_version_info(), "display": DisplayServer.get_name(), "note": "Regressão automatizada da Unidade 3; playtest humano pendente."}
	var file := FileAccess.open("res://docs/ac1/evidence/domestication_" + DisplayServer.get_name() + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	print("DOMESTICATION RESULTS: %d passed; %d failed" % [passed.size(), failed.size()])
	get_tree().quit(0 if failed.is_empty() else 1)
