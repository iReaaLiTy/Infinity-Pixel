extends Node

# Evidencia visual da HUD (nao e teste): 1920x1080, dia e noite, mesma posicao.
# Uso: -- --output=<pasta> --label=<antes|depois>
func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	var out := "user://hud-views/"
	var label := "atual"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=").trim_suffix("/") + "/"
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1920, 1080)
	var app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await wait(.5)
	app.start_game()
	await get_tree().process_frame
	await get_tree().process_frame
	var player = app.world.get_node("Player")
	player._invulnerable_left = INF
	app.world.get_node("EncounterSpawner").current_encounter.set_physics_process(false)
	await wait(2.0)
	await shot(out + "hud_%s_dia_1920.png" % label)
	DayNightManager.start_night()
	await wait(5.0)
	await shot(out + "hud_%s_noite_1920.png" % label)
	print("[HUD] capturas %s salvas em %s" % [label, out])
	app.show_menu()
	get_tree().quit.call_deferred()
