extends Node

# Evidencia visual da Spec 013D (nao e teste): inventario, menu de construcao,
# fantasma valido/invalido, Fogueira, barra CURANDO, armadilha e ativacao.
# Pela camera real de gameplay. Exige janela. Uso: -- --output=<pasta>
const Recipes := preload("res://scenes/world/build_recipes.gd")
var out := "user://spec013d-views/"

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + label + ".png")

func wait(seconds: float) -> void:
	for i in int(round(seconds * 60.0)):
		await get_tree().physics_frame

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	var app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	app.start_game()
	await get_tree().process_frame
	await get_tree().process_frame
	var world: Node3D = app.world
	var player = world.get_node("Player")
	player.set_process_unhandled_input(false)
	player._invulnerable_left = INF
	for d in world.get_node("EncounterSpawner").encounters: d.set_physics_process(false)
	var stock = world.get_node("ResourceStock")
	var placer = world.get_node("BuildPlacer")
	var bz: Vector3 = world.get_node("WorldRegions/SafeZone/BuildZone").global_position
	player.global_position = bz + Vector3(-2, .1, 3.5)
	await wait(1.5)
	app.toggle_inventory()
	await wait(.3)
	await shot("00_inventario_vazio_insuficiente")
	stock.add(&"wood", 40)
	stock.add(&"stone", 18)
	await wait(.3)
	await shot("01_inventario")
	app.toggle_build_menu()
	await wait(.3)
	await shot("02_menu_construir")
	app._start_placement(Recipes.CAMPFIRE)
	placer.follow_cursor = false
	placer.move_ghost_to(bz + Vector3(1.5, 0, -2))
	await wait(.3)
	await shot("03_fantasma_valido")
	placer.move_ghost_to(bz + Vector3(-1, 0, 7.5)) # gramado aberto, fora da BuildZone
	await wait(.3)
	await shot("04_fantasma_invalido")
	placer.move_ghost_to(bz + Vector3(1.5, 0, -2))
	var fire = placer.confirm()
	await wait(.4)
	await shot("05_fogueira_construida")
	player.current_hp = 55.0
	player.health_changed.emit(55.0, 100.0)
	player.global_position = fire.global_position + Vector3(0, .1, 1.8)
	await wait(.5)
	Input.action_press("heal_interact")
	await wait(1.6)
	await shot("06_curando")
	await wait(1.6)
	Input.action_release("heal_interact")
	await wait(.3)
	await shot("07_curado_recarregando")
	# Armadilha na estrada (campina) e ativacao por um inimigo da onda
	var road := Vector3(0, 0, 2)
	player.global_position = road + Vector3(2.5, .1, 2.5)
	await wait(1.5)
	app._start_placement(Recipes.TRAP)
	placer.follow_cursor = false
	placer.move_ghost_to(road)
	await wait(.3)
	await shot("08_fantasma_armadilha_rota")
	var trap = placer.confirm()
	await wait(.4)
	await shot("09_armadilha_construida")
	DayNightManager.start_night()
	await wait(.3)
	var foe = world.get_node("WaveManager")._active_wave_enemies.keys()[0]
	foe.set_physics_process(false)
	foe.global_position = trap.global_position + Vector3(0, .5, 0)
	await wait(.12)
	await shot("10_armadilha_ativada_noite")
	print("[SPEC013D] capturas salvas em " + out)
	app.show_menu()
	get_tree().quit.call_deferred()
