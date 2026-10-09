extends Node

# Capturas dos menus (nao e teste): menu principal, configuracoes, pausa,
# controles e derrota, em 1280x720 e 1920x1080. Exige janela.
# Uso: res://tools/menu_capture.tscn -- --output=<pasta>
var out := "user://menu-capture/"
var app

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func shot(label: String) -> void:
	await frames(20)
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png("%s%s_%d.png" % [out, label, get_window().size.x])
	print("[MENU] " + label)

func series(size: Vector2i) -> void:
	get_window().size = size
	app.show_menu()
	await frames(10)
	await shot("50_menu")
	app.show_settings(app._close_overlay)
	await shot("51_configuracoes")
	app.start_game()
	await frames(20)
	app.pause_game()
	await shot("52_pausa")
	app.show_controls(app._show_pause_menu)
	await shot("53_controles")
	app.resume_game()
	DayNightManager.report_defeat()
	await shot("54_derrota")

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await frames(5)
	await series(Vector2i(1280, 720))
	await series(Vector2i(1920, 1080))
	app.show_menu()
	get_tree().quit.call_deferred()
