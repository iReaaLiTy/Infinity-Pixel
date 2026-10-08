extends SceneTree

# Presentation-only cameras. Loads actual model scenes; no gameplay file edits.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var out := "res://docs/delivery/ac1/evidence/art/"
	DirAccess.make_dir_recursive_absolute(out)
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("173a35")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("cfe4d5")
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-35,0)
	light.light_energy = 0.9
	stage.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.5
	stage.add_child(camera)
	camera.make_current()
	for kind in ["guardian", "dino", "carno"]:
		var model = load("res://scenes/visuals/" + kind + ".tscn").instantiate()
		stage.add_child(model)
		for view in ["frente", "lateral", "costas"]:
			camera.position = Vector3(0,1.1,-5) if view == "frente" else (Vector3(5,1.1,0) if view == "lateral" else Vector3(0,1.1,5))
			camera.look_at(Vector3(0,1.1,0))
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out + kind + "_" + view + ".png")
		stage.remove_child(model)
		model.queue_free()
	await process_frame
	print("AC1 art captures saved")
	quit()
