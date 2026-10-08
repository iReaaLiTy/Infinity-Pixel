extends Node

# Evidencia visual da Spec 015 (nao e teste): estados dos territorios pela
# camera REAL de gameplay. Usa os sistemas reais (guardiao derrotado/
# domesticado, E segurado no marco, BuildPlacer). Exige janela.
# Uso: -- --output=<pasta>
const Recipes := preload("res://scenes/world/build_recipes.gd")
var out := "user://spec015-views/"
var app
var world: Node3D
var tm
var player

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + label + ".png")
	print("[SPEC015] %s  territorios %d/3  %s" % [label, tm.controlled_count(), tm.states])

func wait(seconds: float) -> void:
	for i in int(round(seconds * 60.0)):
		await get_tree().physics_frame

func go(pos: Vector3) -> void:
	player.global_position = pos
	await wait(0.6) # camera alcanca o Player

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	app.start_game()
	await wait(1.0)
	world = app.world
	tm = world.get_node("TerritoryManager")
	player = world.get_node("Player")
	player.set_process_unhandled_input(false)
	player._invulnerable_left = INF
	var placer = world.get_node("BuildPlacer")
	placer.follow_cursor = false
	var stock = world.get_node("ResourceStock")
	stock.add(&"wood", 80)
	stock.add(&"stone", 40)
	var gw = tm.guardians[&"west"]
	var ge = tm.guardians[&"east"]
	for g in [gw, ge]: g.set_physics_process(false)
	gw.global_position = Vector3(-11, .5, 11.5)
	# A. inicio: Oeste selvagem (marco apagado + guardiao), toast de entrada.
	await go(Vector3(-12.5, .1, 9))
	await wait(0.4)
	await shot("01_oeste_selvagem_entrada")
	await go(tm.markers[&"west"].global_position + Vector3(0, .1, 2.0))
	await shot("02_oeste_marco_apagado_guardiao")
	# F (recusa). Fantasma vermelho no Oeste ainda selvagem.
	placer.begin(Recipes.CAMPFIRE)
	placer.move_ghost_to(Vector3(-11, 0, 15.5))
	await wait(0.3)
	await shot("03_construcao_recusada_oeste_selvagem")
	placer.cancel()
	# B. guardiao derrotado -> marco pronto.
	gw.take_damage(gw.MAX_HP)
	await wait(0.8)
	await shot("04_oeste_pronto_marco_dourado")
	# C. segurando E: barra RECUPERANDO, depois conquista.
	Input.action_press("domesticate")
	await wait(1.2)
	await shot("05_oeste_recuperando")
	await wait(0.95)
	await shot("06_oeste_recuperada_anel")
	Input.action_release("domesticate")
	await wait(1.5)
	await shot("07_oeste_controlada_hud_2de3")
	# F. construcao aceita no Oeste recuperado.
	placer.begin(Recipes.CAMPFIRE)
	placer.move_ghost_to(Vector3(-11, 0, 15.5))
	await wait(0.3)
	await shot("08_fantasma_valido_oeste")
	placer.confirm()
	await wait(0.5)
	await shot("09_fogueira_no_oeste")
	# D. Leste: guardiao domesticado -> pronto.
	ge.hp = 20.0
	ge.global_position = Vector3(12.5, .5, 18.5)
	await go(Vector3(12.5, .1, 20.3))
	await shot("10_leste_guardiao")
	Input.action_press("domesticate")
	await wait(2.3)
	Input.action_release("domesticate")
	await go(tm.markers[&"east"].global_position + Vector3(0, .1, 2.0))
	await shot("11_leste_pronto_aliado")
	# E. ambos recuperados.
	Input.action_press("domesticate")
	await wait(2.2)
	Input.action_release("domesticate")
	await wait(0.4)
	await shot("12_leste_recuperada_hud_3de3")
	placer.begin(Recipes.TRAP)
	placer.cancel()
	# Noite: marcos recuperados continuam identificaveis.
	DayNightManager.state = DayNightManager.State.NIGHT
	DayNightManager.phase_elapsed = 11.25
	world.get_node("DayNightVisual").snap()
	DayNightManager.gameplay_enabled = false
	await wait(0.3)
	await shot("13_leste_noite")
	await go(tm.markers[&"west"].global_position + Vector3(0, .1, 2.5))
	await wait(0.3)
	await shot("14_oeste_noite_fogueira")
	print("[SPEC015] capturas salvas em " + out)
	app.show_menu()
	get_tree().quit.call_deferred()
