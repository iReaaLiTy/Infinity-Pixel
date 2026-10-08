extends Node
var app: Node
var out := "res://docs/ac1/evidence/"

func wait(t: float = .2) -> void:
	await get_tree().create_timer(t,true,false,true).timeout

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + name + ".png")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	app=load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await wait(.7)
	await shot("01_menu_1280")
	get_window().size=Vector2i(1920,1080)
	await wait(.3)
	await shot("02_menu_1920")
	get_window().size=Vector2i(1280,720)
	app.start_game()
	await wait(.5)
	await shot("03_dia")
	get_window().size=Vector2i(1920,1080)
	await wait(.2)
	await shot("03_dia_1920")
	get_window().size=Vector2i(1280,720)
	# Real rendered arena, perspective / overhead; explicitly separate from playtest.
	app.hud.hide()
	var camera:=Camera3D.new()
	app.world.add_child(camera)
	camera.global_position=Vector3(24,25,30)
	camera.look_at(Vector3(0,0,-2))
	camera.make_current()
	await wait(.2)
	await shot("arena_dia")
	DayNightManager.start_night()
	await wait(1.6)
	await shot("arena_noite")
	app.hud.show()
	camera.global_position=Vector3(5,5,-10)
	camera.look_at(Vector3(0,1,9))
	await wait(.2)
	await shot("07_noite")
	app.show_menu()
	app.ui.hide()
	await wait(.1)
	# Orthographic turnarounds from actual editable model scenes.
	var stage:=Node3D.new()
	add_child(stage)
	var env:=WorldEnvironment.new()
	var e:=Environment.new()
	e.background_mode=Environment.BG_COLOR
	e.background_color=Color("173a35")
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color=Color("cfe4d5")
	e.ambient_light_energy=.5
	e.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.environment=e
	stage.add_child(env)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-35,-35,0)
	light.light_energy=.9
	stage.add_child(light)
	var cam:=Camera3D.new()
	cam.projection=Camera3D.PROJECTION_ORTHOGONAL
	cam.size=2.65
	stage.add_child(cam)
	cam.make_current()
	for kind in ["guardian","dino","carno"]:
		var model=load("res://scenes/visuals/"+kind+".tscn").instantiate()
		stage.add_child(model)
		for view in ["frente","lateral","costas"]:
			cam.position=Vector3(0,1.1,-5) if view=="frente" else (Vector3(5,1.1,0) if view=="lateral" else Vector3(0,1.1,5))
			cam.look_at(Vector3(0,1.1,0))
			await wait(.05)
			await shot(kind+"_"+view)
		if kind=="dino":
			model.set_ally()
			cam.position=Vector3(4,2,-5)
			cam.look_at(Vector3(0,1,0))
			await wait(.05)
			await shot("dino_aliado")
		stage.remove_child(model)
		model.queue_free()
	await wait(.1)
	get_tree().quit()
