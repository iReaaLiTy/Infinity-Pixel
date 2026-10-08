extends Node

# Runtime visual evidence through the unchanged gameplay camera, not editor views.
func _ready() -> void:
	if DisplayServer.get_name()=="headless":
		get_tree().quit(1)
		return
	var output := "user://spec012-views/"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(output)
	var app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	app.start_game()
	await get_tree().create_timer(.3).timeout
	var player = app.world.get_node("Player")
	player._invulnerable_left = 999 # showcase fixture only; UI/AI otherwise running
	var views := {
		"01_spawn":Vector3(0,.01,-10), "02_build_zone":Vector3(7,.01,-14),
		"03_exit":Vector3(0,.01,-3), "04_transition":Vector3(0,.01,0), "04b_fork":Vector3(0,.01,7),
		"05_creature_glade":Vector3(-10,.01,10), "06_woodland":Vector3(-11.5,.01,15.5),
		"07_stone_heath":Vector3(13.6,.01,18.5), "08_arch_entry":Vector3(0,.01,23),
		"09_west_route":Vector3(-15,.01,.8), "10_east_route":Vector3(15,.01,.3),
	}
	for label in views:
		player.global_position=views[label]
		await get_tree().create_timer(1.1).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output+label+".png")
	# A separate diagnostic camera supplies a map overview; never stored in gameplay.
	var overview := Camera3D.new()
	app.world.add_child(overview)
	overview.position=Vector3(0,62,22)
	overview.look_at(Vector3(0,0,2))
	overview.projection=Camera3D.PROJECTION_ORTHOGONAL
	overview.size=64
	overview.current=true
	app.hud.visible=false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"11_overview_diagnostic.png")
	print("[MAP012] gameplay captures saved: "+output)
	get_tree().quit.call_deferred()
