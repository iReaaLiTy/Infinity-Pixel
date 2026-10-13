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
func face(direction: Vector3) -> void:
	player._attack_face_time = 0.0
	player.rotation.y = atan2(-direction.x, -direction.z)
	player._facing_yaw = player.rotation.y
	player.visual.rotation.y = 0.0
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
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Cursor: menu principal")
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
	check(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN, "Cursor: gameplay")
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
	app.toggle_inventory()
	var count: int = player.attack_count
	player.attack_cooldown.stop()
	player._try_attack()
	check(player.attack_count == count and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Inventário: cursor visível, ataque bloqueado inclusive direto/buffer")
	app.toggle_inventory()
	check(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN, "Fecha inventário: cursor oculto")
	app.pause_game()
	app.sync_cursor()
	player._try_attack()
	check(player.attack_count == count and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Pausa: sem ataque, cursor visível")
	app.show_settings(app._show_pause_menu)
	app.sync_cursor()
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Configurações: cursor visível")
	app.resume_game(); app.sync_cursor()
	app._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Perda de foco pausa e libera cursor")
	app.resume_game(); app.sync_cursor()
	check(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN, "Retomar após foco oculta cursor")
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
	app._defeat(); app.sync_cursor()
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Derrota: cursor visível")
	app.restart()
	await frames()
	check(app.world.get_node("JadeElixir").stored == 0 and app.world.get_node("JadeElixir").next_day == 2 and DayNightManager.day_number == 1 and get_tree().get_nodes_in_group("spike_trap").is_empty(), "Reinício limpa poção, cooldown, dia e armadilhas")
	app.start_tutorial(); await frames()
	check(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN, "Tutorial jogável: cursor oculto")
	print("RESULT: %d passed; %d failed" % [passed.size(), failed.size()])
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var f := FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			f.store_string(JSON.stringify({"passed": passed, "failed": failed}, "\t"))
	app.show_menu()
	get_tree().quit(0 if failed.is_empty() else 1)
