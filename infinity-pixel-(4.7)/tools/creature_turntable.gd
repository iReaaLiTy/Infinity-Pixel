extends Node3D

# Visual Overhaul 3.0: vitrine dos modelos (nao e teste). Dinossauro, Carnotauro
# e Player lado a lado, luz do meio-dia do jogo, tres enquadramentos: lateral,
# tres-quartos e o angulo da camera estrategica. Exige janela.
# Uso: res://tools/creature_turntable.tscn -- --output=<pasta> [--label=<prefixo>]
# 4.0: tambem a silhueta vista de cima ("topo") e uma pose de passada
# ("passo_lateral": perna em balanco, joelho dobrado, ponta da cauda curvada).
var out := "user://turntable/"
var label := "modelo"

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func shot(cam: Camera3D, name: String) -> void:
	cam.make_current()
	await frames(8)
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png("%s%s_%s.png" % [out, label, name])
	print("[TT] " + name)

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=").trim_suffix("/") + "/"
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
	DirAccess.make_dir_recursive_absolute(out)
	var env := Environment.new()
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.58, 0.73, 0.69)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.35
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	sun.light_color = Color(1, 0.93, 0.8)
	sun.light_energy = 0.9
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("5c9a4c")
	ground.material_override = gm
	add_child(ground)
	var posed: Array[Node3D] = []
	var models := [["res://scenes/visuals/dino.tscn", -2.6], ["res://scenes/visuals/carno.tscn", 0.4], ["res://scenes/visuals/guardian.tscn", 2.8]]
	for m in models:
		var v := (load(m[0]) as PackedScene).instantiate() as Node3D
		v.position = Vector3(m[1], 0, 0)
		v.rotation.y = -PI / 2.0 # cabeca para a direita da camera lateral
		add_child(v)
		posed.append(v)
	var cams := {}
	for spec in [["lateral", Vector3(0.2, 1.3, 7.8), Vector3(0.2, 1.0, 0), 42.0],
			["tres_quartos", Vector3(4.6, 2.6, 6.4), Vector3(0.0, 0.9, 0), 42.0],
			["estrategica", Vector3(0.2, 13.0, 9.0), Vector3(0.2, 0.0, 0), 34.0],
			["cabeca", Vector3(-1.2, 1.9, 1.9), Vector3(-1.5, 1.65, 0), 32.0],
			["topo", Vector3(0.2, 14.0, 1.2), Vector3(0.2, 0.0, 0), 30.0]]:
		var c := Camera3D.new()
		add_child(c)
		c.global_position = spec[1]
		c.look_at(spec[2], Vector3.UP)
		c.fov = spec[3]
		cams[spec[0]] = c
	await frames(10)
	for k in cams:
		await shot(cams[k], k)
	# Pose de passada (mesma nas duas versoes; joelho/cauda so onde existem).
	for v in posed:
		if v.has_node("LegL"):
			v.get_node("LegL").rotation.x = 0.45
			v.get_node("LegR").rotation.x = -0.45
		if v.has_method("_bend"):
			v._bend("KneeL", "AnkleL", 0.8)
			v._bend("KneeR", "AnkleR", 0.0)
		if v.has_node("Tail"):
			v.get_node("Tail").rotation.y = 0.18
		if v.has_node("Tail/TailTip"):
			v.get_node("Tail/TailTip").rotation.y = -0.3
	await shot(cams["lateral"], "passo_lateral")
	get_tree().quit()
