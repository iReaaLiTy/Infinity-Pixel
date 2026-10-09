extends Node

# Inventario grande (playtest 09/10/2026). Teclas e cliques REAIS (push_input).
# Uso: Godot [--headless] --path . res://tests/inventory_ui.tscn [-- --report=<arquivo>]
const Recipes := preload("res://scenes/world/build_recipes.gd")
var passed: Array[String] = []
var failed: Array[String] = []
var app
var world: Node3D

func check(ok: bool, label: String) -> void:
	(passed if ok else failed).append(label)
	print(("PASS: " if ok else "FAIL: ") + label)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await get_tree().process_frame
	await frames(2)

func click(at: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		get_viewport().push_input(ev, true)
	await frames(3)

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
	var player = world.get_node("Player")
	player._invulnerable_left = INF
	var hud = app.hud
	var inv: Control = app.inventory_panel

	await key(KEY_I)
	check(inv.visible, "I abre o inventario")
	var view: Rect2 = hud.get_viewport_rect()
	var card: Rect2 = hud._inv_card.get_global_rect()
	check(card.size.x >= view.size.x * 0.70 and card.size.x <= view.size.x * 0.82, "Cartao central com ~70-80%% da largura (%.0f de %.0f)" % [card.size.x, view.size.x])
	check(view.encloses(card) and absf(card.get_center().x - view.get_center().x) < 2.0, "Cartao inteiro dentro da tela e centralizado")
	var clipped := []
	for l: Label in hud._inv_card.find_children("*", "Label", true, false):
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.get_minimum_size().x > l.size.x + 1.0:
			clipped.append(l.text)
	check(clipped.is_empty(), "Nenhum texto cortado no cartao %s" % [clipped])
	check(hud._inv_close.has_focus(), "Ao abrir, o foco do teclado vai para FECHAR")
	var t0: float = DayNightManager.phase_elapsed
	await frames(30)
	check(not get_tree().paused and DayNightManager.phase_elapsed > t0, "Inventario aberto nao pausa (contrato 013D)")
	# Clique no veu (fora do cartao) fecha e NAO ataca.
	var swings: int = player.attack_count
	await click(Vector2(card.position.x - 60.0, view.get_center().y))
	check(not inv.visible and player.attack_count == swings, "Clique fora do cartao fecha sem atacar")
	# Clique dentro do cartao nao fecha nem ataca.
	await key(KEY_I)
	await click(card.position + Vector2(40, card.size.y - 20))
	check(inv.visible and player.attack_count == swings, "Clique dentro do cartao nao fecha nem ataca")
	# ESC fecha (e nao pausa).
	await key(KEY_ESCAPE)
	check(not inv.visible and not get_tree().paused and app.screen == "playing", "ESC fecha o inventario sem pausar")
	check(hud.get_viewport().gui_get_focus_owner() == null, "Fechar solta o foco do teclado")
	# Abre e fecha 20 vezes: sem duplicar nem travar.
	for i in 20:
		await key(KEY_I)
	check(not inv.visible and hud.find_children("InventoryPanel", "", true, false).size() == 1, "20x I: estado coerente, um painel so")
	# Recursos e defesa no inventario.
	var stock = world.get_node("ResourceStock")
	stock.add(&"wood", 12)
	stock.add(&"stone", 4)
	await key(KEY_I)
	var rows: Dictionary = app._recipe_rows[inv]
	check(app.inv_wood_text.text == "12" and app.inv_stone_text.text == "4", "Madeira e Pedra no inventario")
	check(rows[Recipes.CAMPFIRE].wood.text.contains("faltam 8") and rows[Recipes.CAMPFIRE].button.disabled, "Recursos insuficientes: 'faltam' e CONSTRUIR desabilitado")
	check(hud._def_points.text == "40" and hud._def_towers.text.contains("0 de 6"), "Defesa: 40 Pontos, 0 de 6 torres")
	# CONSTRUIR pelo inventario (com recursos) inicia o posicionamento e fecha.
	stock.add(&"wood", 20)
	stock.add(&"stone", 20)
	await frames(2)
	var button: Button = rows[Recipes.CAMPFIRE].button
	await click(button.get_global_rect().get_center())
	var placer = world.get_node("BuildPlacer")
	check(placer.is_placing() and not inv.visible, "CONSTRUIR no inventario inicia a construcao e fecha o painel")
	placer.cancel()
	# Teclado: Enter no botao focado (FECHAR) fecha.
	await key(KEY_I)
	await key(KEY_ENTER)
	check(not inv.visible, "Enter no FECHAR focado fecha o inventario")

	print("INVENTORY RESULTS: %d passed; %d failed" % [passed.size(), failed.size()])
	if report != "":
		var f := FileAccess.open(report, FileAccess.WRITE)
		f.store_string(JSON.stringify({"passed": passed, "failed": failed}, "\t"))
		f.close()
	get_tree().quit(0 if failed.is_empty() else 1)
