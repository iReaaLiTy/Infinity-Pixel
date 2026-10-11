extends Node3D

# Fundo do menu principal (Visual Overhaul 3.0): diorama 3D do Refugio no fim
# da tarde. So arte, sem gameplay: nada de Player, IA, onda, navegacao ou
# colisoes. Usa a arte real do vale (Spec 017A/018) com a camera enquadrando o
# cristal a direita (a coluna de botoes fica a esquerda), um aliado cheirando o
# chao em primeiro plano, um selvagem ao longe, pegadas e ossadas fosseis,
# fagulhas dos braseiros e poeira de jade. Movimento de camera lento e curto.

const ART := preload("res://scenes/visuals/arena_art.tscn")
const REGIONS := preload("res://scenes/world/world_regions.tscn")
const REFUGE_ART := preload("res://scenes/visuals/refuge_art.tscn") # Spec 017A
const VALLEY_ART := preload("res://scenes/visuals/valley_art.tscn") # Spec 017A/018
const FLORA_ART := preload("res://scenes/visuals/flora_art.scn") # 4.0: arvores, rochas, sub-bosque
const DINO := preload("res://scenes/visuals/dino.tscn")
const Props := preload("res://scenes/visuals/prehistoric_props.gd")

## Camera ao norte do Refugio olhando para ele (sul); cristal no terco direito.
const CAMERA_POS := Vector3(-6.2, 3.1, -3.4)
const LOOK_AT := Vector3(-2.6, 1.55, -13.6)
const SWAY := 0.035 # rad de giro lento em volta do alvo (sem enjoo)
const SWAY_PERIOD := 48.0 # s por ciclo completo

var camera: Camera3D
var _time := 0.0
var _actors: Array[Node3D] = []
var _walker: Node3D

func _ready() -> void:
	var env := Environment.new()
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("4f7f8c")
	sky_mat.sky_horizon_color = Color("d8cba8")
	sky_mat.ground_horizon_color = Color("b9a58c")
	sky_mat.ground_bottom_color = Color("3c5a4c")
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("cfe3d6")
	env.ambient_light_energy = 0.42
	env.fog_enabled = true
	env.fog_light_color = Color("d9c29a")
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.2
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	# Sol baixo e quente (fim de tarde): faces com volume e sombras longas.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, -58, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS # 4.0: metade das passadas de sombra
	sun.light_color = Color(1, 0.84, 0.62)
	sun.light_energy = 1.0
	add_child(sun)
	var art := ART.instantiate()
	if art.has_node("PostLabel"): # removido na 013C; mantido por seguranca
		art.get_node("PostLabel").visible = false
	add_child(art)
	add_child(REGIONS.instantiate())
	add_child(VALLEY_ART.instantiate()) # chao, trilhas e paredoes (os antigos foram ocultados)
	add_child(FLORA_ART.instantiate()) # 4.0: as arvores e rochas antigas de ArenaArt ficam ocultas
	add_child(REFUGE_ART.instantiate()) # cristal, plataforma, braseiros, estandartes
	# Aliado em primeiro plano (cheira o chao e olha em volta) e um selvagem
	# atravessando a trilha ao fundo, devagar.
	var ally := _actor(DINO, Vector3(-1.9, 0, -9.0), -1.75, "rest")
	ally.set_ally()
	ally.flash_time = 0.0
	_walker = _actor(DINO, Vector3(6.5, 0, -22.0), PI / 2.0, "walk")
	# Pegadas fosseis levando ate o aliado e ossada antiga a esquerda (fica
	# atras da coluna escura, da textura sem disputar com os botoes).
	for i in 7:
		var p := Props.footprint(Vector3(-4.4 + i * 0.62, 0, -5.2 - i * 0.48 + (0.14 if i % 2 == 0 else -0.14)), -2.25)
		add_child(p)
	add_child(Props.ribcage(Vector3(-7.4, 0, -10.6), 0.6))
	add_child(Props.skull(Vector3(-6.0, 0, -9.2), -0.9))
	add_child(Props.totem(Vector3(4.6, 0, -11.2), 0.4))
	add_child(Props.ammonite_rock(Vector3(-3.2, 0, -7.0), 1.2))
	# Fagulhas sobre os braseiros e poeira de jade em volta do cristal.
	for x in [-3.3, 3.3]:
		add_child(_embers(Vector3(x, 1.55, -14.3)))
	add_child(_motes(Vector3(0, 1.4, -15.0)))
	# Luz jade do cristal (sem sombra): o cristal e o protagonista do diorama.
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 2.6, -13.4)
	glow.light_color = Color("7fd8b0")
	glow.light_energy = 1.6
	glow.omni_range = 7.0
	add_child(glow)
	camera = Camera3D.new()
	camera.fov = 48.0
	camera.far = 160.0
	add_child(camera)
	camera.current = true
	_place_camera()

func _actor(scene: PackedScene, pos: Vector3, yaw: float, pose: String) -> Node3D:
	var actor := scene.instantiate() as Node3D
	actor.position = pos
	actor.rotation.y = yaw
	add_child(actor)
	actor.showcase = pose
	_actors.append(actor)
	return actor

func _embers(at: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = at
	p.amount = 14
	p.lifetime = 2.2
	p.preprocess = 2.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.18
	p.direction = Vector3.UP
	p.spread = 18.0
	p.gravity = Vector3(0.15, 0.35, 0)
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.9
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	p.mesh = _spark_mesh(0.045)
	p.material_override = _glow_material(Color("ffb35a"))
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 0.8, 0.4, 1))
	fade.set_color(1, Color(1, 0.4, 0.2, 0))
	p.color_ramp = fade
	return p

func _motes(at: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = at
	p.amount = 22
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(3.5, 1.0, 3.5)
	p.direction = Vector3.UP
	p.spread = 40.0
	p.gravity = Vector3(0, 0.05, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.2
	p.mesh = _spark_mesh(0.05)
	p.material_override = _glow_material(Color("a8e6cf"))
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 0.9))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	return p

static func _spark_mesh(size: float) -> Mesh:
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2.0
	m.radial_segments = 4
	m.rings = 2
	return m

static func _glow_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	return m

func _process(delta: float) -> void:
	_time += delta
	_place_camera()
	# O selvagem ao fundo atravessa a trilha devagar e volta (ida e volta longe).
	if is_instance_valid(_walker):
		var x := 6.5 - fposmod(_time * 0.45, 26.0)
		_walker.position.x = x if x > -6.5 else -6.5 - (x + 6.5)
		_walker.rotation.y = PI / 2.0 if x > -6.5 else -PI / 2.0
		# 4.0: cadencia casada com a velocidade (0,45 m/s; passada ~1,5 m): sem patinar
		_walker.get_node("LegL").rotation.x = sin(_time * 1.9) * 0.4
		_walker.get_node("LegR").rotation.x = -sin(_time * 1.9) * 0.4
		_walker.position.y = (0.5 + 0.5 * cos(_time * 3.8)) * 0.03
		_walker._bend("KneeL", "AnkleL", maxf(0.0, cos(_time * 1.9))) # 4.0: joelho levanta o pe
		_walker._bend("KneeR", "AnkleR", maxf(0.0, -cos(_time * 1.9)))

func _place_camera() -> void:
	var a := sin(_time * TAU / SWAY_PERIOD) * SWAY
	var offset := (CAMERA_POS - LOOK_AT).rotated(Vector3.UP, a)
	camera.position = LOOK_AT + offset + Vector3(0, sin(_time * TAU / (SWAY_PERIOD * 1.7)) * 0.08, 0)
	camera.look_at(LOOK_AT, Vector3.UP)
