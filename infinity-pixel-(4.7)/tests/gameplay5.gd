extends Node

const WILD := preload("res://scenes/enemies/wild_dino.tscn")
var passed := []
var failed := []
var app
var world
var player
var elixir
var stock
func check(ok: bool, label: String) -> void:
	(passed if ok else failed).append(label)
	print(("PASS: " if ok else "FAIL: ") + label)
func frames(n := 3) -> void:
	for i in n: await get_tree().physics_frame
## Politica do cursor (app.cursor_hidden) e, com janela, o modo real do sistema.
## O modo sem janela do Godot ignora MOUSE_MODE_HIDDEN, entao so a politica conta.
func cursor_is(hidden: bool) -> bool:
	var headless := DisplayServer.get_name() == "headless"
	var real_ok := headless or Input.mouse_mode == (Input.MOUSE_MODE_HIDDEN if hidden else Input.MOUSE_MODE_VISIBLE)
	return real_ok and (app == null or app.cursor_hidden == hidden)
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func face(direction: Vector3) -> void:
	player.rotation.y = atan2(-direction.x, -direction.z)
func click(behind := true) -> void:
	player.attack_cooldown.stop()
	var camera: Camera3D = player.camera
	var point: Vector3 = player.global_position + player.global_basis.z * (3.0 if behind else -3.0)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = camera.unproject_position(point)
	ev.pressed = true
	get_viewport().push_input(ev, true)
	ev = ev.duplicate()
	ev.pressed = false
	get_viewport().push_input(ev, true)
	await frames(2)
func creature(position: Vector3, ally := false):
	var d = WILD.instantiate()
	world.add_child(d)
	d.global_position = position
	d.set_physics_process(false)
	if ally: d.domesticate()
	return d
func dawn() -> void:
	DayNightManager.start_night()
	world.get_node("WaveManager").cancel_wave()
	DayNightManager.report_wave_victory()
	await frames()
func _ready() -> void:
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await frames()
	check(cursor_is(false), "Cursor: menu principal")
	app.start_game()
	world = app.world
	player = world.get_node("Player")
	elixir = world.get_node("JadeElixir")
	stock = world.get_node("ResourceStock")
	DayNightManager.clock_hold = true
	player._invulnerable_left = INF
	for d in world.get_node("EncounterSpawner").encounters: d.queue_free()
	player.global_position = Vector3(1, 0.1, -3)
	await frames(10)
	check(cursor_is(true), "Cursor: gameplay")
	for kind in ["wood", "stone"]:
		var resource = world.get_node("Collectables/" + ("Tree1" if kind == "wood" else "Stone1"))
		player.global_position = resource.global_position + Vector3(0, 0.1, 1.8)
		face(Vector3.FORWARD)
		await frames()
		var hp: float = resource.hp
		await click()
		check(resource.hp == hp - 15, kind + ": alvo frontal, cursor atrás, -15")
	player.global_position = Vector3(1, 0.1, -3)
	face(Vector3.FORWARD)
	var front = creature(player.global_position + Vector3(0, 0.4, -1.7))
	var back = creature(player.global_position + Vector3(0, 0.4, 1.5))
	var side = creature(player.global_position + Vector3(0.95, 0.4, -1.1))
	await frames(5)
	await click()
	check(front.hp == 65 and back.hp == 80 and side.hp == 80, "Cursor atrás: um alvo mais alinhado, lateral e traseiro intactos")
	var yaw: float = player.last_attack_yaw
	await click(false)
	check(front.hp == 50 and is_equal_approx(player.last_attack_yaw, yaw), "Cursor à frente ou atrás não muda direção; ataque parado")
	front.queue_free(); side.queue_free()
	await frames()
	await click()
	check(back.hp == 80, "Apenas alvo atrás: golpe frontal não o atinge")
	back.queue_free()
	var diagonal := Vector3(1, 0, -1).normalized()
	face(diagonal)
	var d = creature(player.global_position + diagonal * 1.7 + Vector3(0, 0.4, 0))
	await frames()
	await click()
	check(d.hp == 65, "Ataque diagonal")
	DayNightManager.start_night()
	world.get_node("WaveManager").cancel_wave()
	await click()
	check(d.hp == 50, "Ataque noturno preserva dano e orientação")
	# Movimento REAL por WASD: andar para a direita e parar; o golpe sai para a
	# direita (ultima direcao), com o cursor atras.
	var right: Vector3 = player.camera.planar_direction(Vector3(1, 0, 0))
	d.global_position = Vector3(30, -20, 30)
	player.global_position = Vector3(1, 0.1, -3)
	key(KEY_D, true)
	await frames(20)
	key(KEY_D, false)
	await frames(4)
	var moved_to = creature(player.global_position + right * 1.6 + Vector3(0, 0.4, 0))
	await frames()
	await click()
	check(moved_to.hp == 65 and absf(angle_difference(player.last_attack_yaw, atan2(-right.x, -right.z))) < 0.01, "Após andar com D e parar: golpe para a direita, cursor atrás")
	moved_to.queue_free()
	app.toggle_inventory()
	var count: int = player.attack_count
	player.attack_cooldown.stop()
	player._try_attack()
	check(player.attack_count == count and cursor_is(false), "Inventário: cursor visível, ataque bloqueado inclusive direto/buffer")
	app.toggle_inventory()
	check(cursor_is(true), "Fecha inventário: cursor oculto")
	app.pause_game()
	app.sync_cursor()
	player._try_attack()
	check(player.attack_count == count and cursor_is(false), "Pausa: sem ataque, cursor visível")
	app.show_settings(app._show_pause_menu)
	app.sync_cursor()
	check(cursor_is(false), "Configurações: cursor visível")
	app.resume_game(); app.sync_cursor()
	app._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(get_tree().paused and cursor_is(false), "Perda de foco pausa e libera cursor")
	app.resume_game(); app.sync_cursor()
	check(cursor_is(true), "Retomar após foco oculta cursor")
	d.queue_free()
	DayNightManager.report_wave_victory()
	# Potion economy and actual dawn transitions.
	DayNightManager.day_number = 1
	stock.add(&"wood", 200); stock.add(&"stone", 200)
	check(not elixir.craft() and elixir.stored == 0, "Elixir bloqueado Dia 1")
	await dawn()
	check(DayNightManager.day_number == 2 and elixir.craft_reason() == "", "Dia 2 libera fabricação")
	var w: int = stock.get_amount(&"wood")
	var s: int = stock.get_amount(&"stone")
	check(elixir.craft() and elixir.stored == 1 and stock.get_amount(&"wood") == w-40 and stock.get_amount(&"stone") == s-24, "Fabricação custa exatamente 40/24")
	check(not elixir.craft() and elixir.stored == 1, "Limite de uma poção e ausência de duplicação")
	for i in 3: app.toggle_inventory(); app.toggle_inventory()
	check(elixir.stored == 1 and elixir.next_day == 4, "Abrir/fechar inventário preserva estoque/cooldown")
	player.global_position = Vector3(1, 0.1, -3)
	var ally = creature(player.global_position + Vector3(0, 0.4, -2), true)
	var enemy = creature(player.global_position + Vector3(2, 0.4, 0))
	enemy.hp = 10
	check(not elixir.use_on(ally) and elixir.stored == 1, "Vida cheia não consome")
	check(not elixir.use_on(enemy) and not elixir.use_on(player) and not elixir.use_on(null), "Inimigo, Player e alvo ausente não consomem")
	ally.hp = 1
	ally.global_position.x += 8
	check(not elixir.use_on(ally) and elixir.stored == 1, "Aliado distante não consome")
	ally.global_position.x -= 8
	check(elixir.use_on(ally) and ally.hp == 41 and elixir.stored == 0, "Aliado com 1 HP recebe 40; consome exatamente uma")
	await dawn()
	check(DayNightManager.day_number == 3 and not elixir.craft(), "Dia 3: primeiro amanhecer ainda em cooldown")
	await dawn()
	check(DayNightManager.day_number == 4 and elixir.craft(), "Dia 4: segundo amanhecer libera")
	ally.hp = 70
	var farther = creature(player.global_position + Vector3(0, 0.4, 2.6), true)
	farther.hp = 5
	check(elixir.nearest_target() == ally, "Prioriza aliado ferido mais próximo")
	check(elixir.use_nearest() and ally.hp == 80 and farther.hp == 5, "Cura limitada ao HP máximo; só um aliado")
	await dawn(); await dawn()
	stock.amounts[&"wood"] = 39
	stock.amounts[&"stone"] = 23
	check(not elixir.craft() and stock.get_amount(&"wood") == 39 and stock.get_amount(&"stone") == 23, "Recursos insuficientes: gasto atômico zero")
	stock.add(&"wood", 1); stock.add(&"stone", 1)
	check(elixir.craft(), "Não perde oportunidade se não fabricar imediatamente")
	ally.hp = 0
	check(not elixir.use_on(ally) and elixir.stored == 1, "Não ressuscita aliado morto")
	app.toggle_inventory(); app.hud.show_inventory_tab("companions")
	await frames()
	check(app.hud._elixir_status.text.contains("1/1") and app.hud._elixir_craft.disabled, "Inventário mostra estoque e bloqueio reais")
	app.toggle_inventory()
	# Build five traps through the production validator, no test-only construction.
	stock.add(&"wood", 500); stock.add(&"stone", 500)
	var placer = world.get_node("BuildPlacer")
	placer.follow_cursor = false
	var traps := []
	for z in [4, 7, 10, 16, 19]:
		var pos := Vector3(0, 0, z)
		if placer.begin(&"trap"):
			placer.move_ghost_to(pos)
			var trap = placer.confirm()
			if is_instance_valid(trap): traps.append(trap)
	check(traps.size() == 5 and placer.count(&"trap") == 5, "Constrói cinco armadilhas válidas e separadas")
	check(not placer.begin(&"trap"), "Sexta armadilha bloqueada")
	check(placer.validate(&"campfire", Vector3(0, 0, 4)) != "", "Sobreposição com armadilha recusada")
	if not traps.is_empty():
		var trap = traps[0]
		check(trap._area.get_node("CollisionShape3D") == null if false else trap._area.get_child(0).shape.size == Vector3(1.6, 1, 1.6), "Volume de ativação intacto")
	# Estado armado/consumido: uma pedra de carga apaga por ativacao.
	if not traps.is_empty():
		var trap = traps[0]
		var foe = creature(Vector3(40, -20, 40))
		trap._trigger(foe)
		var lit: int = trap._pips.filter(func(m): return m.emission_energy_multiplier > 0.0).size()
		check(trap.charges == 2 and lit == 2 and foe.hp == 65, "Armadilha: -15 e 1 de 3 pedras de carga apagada")
		foe.queue_free()
	# Dica do Elixir (G) com aliado ferido perto e poção guardada.
	ally.hp = 50
	ally.global_position = player.global_position + Vector3(0, 0.4, -2)
	for i in 20: await get_tree().process_frame
	var hint: Label = app.hud.get_node("ElixirHint")
	var view := get_viewport().get_visible_rect()
	check(hint.visible and hint.text.contains("+30") and view.encloses(hint.get_global_rect()), "Dica G visível na tela com a cura real (+30)")
	# Construcao: menu com cursor visivel; posicionando, cursor oculto e a
	# pegada da previa marca o lugar; confirmar constroi e nao ataca.
	app.toggle_build_menu()
	await frames(2)
	check(cursor_is(false) and player.ui_blocked, "Menu de construção: cursor visível, clique não ataca")
	placer.follow_cursor = true
	app._start_placement(&"campfire")
	await frames(2)
	check(placer.is_placing() and cursor_is(true) and placer.ghost.has_node("Footprint"), "Posicionando obra: cursor oculto, pegada da prévia como marcador")
	placer.follow_cursor = false
	placer.move_ghost_to(world.get_node("Territory").global_position + Vector3(7, 0, 0))
	var swings: int = player.attack_count
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	get_viewport().push_input(ev, true)
	await frames(2)
	check(not placer.is_placing() and placer.count(&"campfire") == 1 and player.attack_count == swings, "Clique confirma a fogueira sem atacar")
	app._defeat(); app.sync_cursor()
	check(cursor_is(false), "Derrota: cursor visível")
	app.restart()
	await frames()
	check(app.world.get_node("JadeElixir").stored == 0 and app.world.get_node("JadeElixir").next_day == 2 and DayNightManager.day_number == 1 and get_tree().get_nodes_in_group("spike_trap").is_empty(), "Reinício limpa poção, cooldown, dia e armadilhas")
	app.start_tutorial(); await frames()
	check(cursor_is(true), "Tutorial jogável: cursor oculto")
	# Ataque durante o tutorial: o selvagem do tutorial a frente, cursor atras.
	player = app.world.get_node("Player")
	var tut_target = app.tutorial.target
	tut_target.set_physics_process(false)
	player.global_position = tut_target.global_position + Vector3(0, 0.1, 1.7)
	face(Vector3.FORWARD)
	await frames(3)
	var tut_hp: float = tut_target.hp
	await click()
	check(tut_target.hp == tut_hp - 15.0, "Tutorial: golpe frontal acerta o selvagem com o cursor atrás")
	print("RESULT: %d passed; %d failed" % [passed.size(), failed.size()])
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var f := FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			f.store_string(JSON.stringify({"passed": passed, "failed": failed}, "\t"))
	app.show_menu()
	get_tree().quit(0 if failed.is_empty() else 1)
