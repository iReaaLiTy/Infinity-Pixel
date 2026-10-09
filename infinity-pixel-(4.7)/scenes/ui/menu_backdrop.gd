extends Node3D

# Fundo do menu principal: o proprio vale do jogo (Spec 012), so com a arte.
# Nenhum script de gameplay roda aqui — sem Player, IA, onda, navegacao ou
# colisoes. Os modelos dos personagens sao os mesmos do jogo (actor_visual.gd
# fica parado fora de um CharacterBody3D) e ganham so um balanco leve.

const ART := preload("res://scenes/visuals/arena_art.tscn")
const REGIONS := preload("res://scenes/world/world_regions.tscn")
const REFUGE_ART := preload("res://scenes/visuals/refuge_art.tscn") # Spec 017A
const VALLEY_ART := preload("res://scenes/visuals/valley_art.tscn") # Spec 017A/018
const GUARDIAN := preload("res://scenes/visuals/guardian.tscn")
const DINO := preload("res://scenes/visuals/dino.tscn")
const CARNO := preload("res://scenes/visuals/carno.tscn")

## Camera atras do refugio olhando o vale para o norte: o refugio e os
## personagens ficam embaixo (livre de UI) e o vale/ruina ao fundo.
const CAMERA_POS := Vector3(7.5, 6.0, -23.0)
const LOOK_AT := Vector3(-2.0, -1.5, 2.0)
const DRIFT := 1.2 # m de deriva lateral, bem sutil
const DRIFT_PERIOD := 40.0 # s por ciclo completo

var camera: Camera3D
var _time := 0.0
var _actors: Array[Node3D] = []

func _ready() -> void:
	var env := Environment.new() # mesmos valores da prototype_area (dia)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.58, 0.73, 0.69)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.35
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -45, 0)
	sun.shadow_enabled = true
	sun.light_color = Color(1, 0.91, 0.72)
	sun.light_energy = 0.8
	add_child(sun)
	var art := ART.instantiate()
	if art.has_node("PostLabel"): # removido na 013C; mantido por seguranca
		art.get_node("PostLabel").visible = false
	add_child(art)
	add_child(REGIONS.instantiate())
	add_child(VALLEY_ART.instantiate()) # chao, trilhas e paredoes (os antigos foram ocultados)
	add_child(REFUGE_ART.instantiate()) # cristal, plataforma, braseiros, estandartes
	# Pequena cena de vida no caminho do refugio: guardiao, aliado e selvagens.
	_actor(GUARDIAN, Vector3(8.1, 0, -12.6), 2.6)
	var ally := _actor(DINO, Vector3(9.0, 0, -10.8), 2.2)
	ally.set_ally()
	_actor(DINO, Vector3(-9.5, 0, -1.5), 2.2)
	_actor(CARNO, Vector3(6.5, 0, 0.5), -2.4)
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.far = 200.0
	add_child(camera)
	camera.current = true
	_place_camera()

func _actor(scene: PackedScene, pos: Vector3, yaw: float) -> Node3D:
	var actor := scene.instantiate() as Node3D
	actor.position = pos
	actor.rotation.y = yaw
	add_child(actor)
	_actors.append(actor)
	return actor

func _process(delta: float) -> void:
	_time += delta
	_place_camera()
	for i in _actors.size():
		_actors[i].position.y = absf(sin(_time * 2.2 + i * 1.7)) * 0.05 # respira

func _place_camera() -> void:
	var drift := sin(_time * TAU / DRIFT_PERIOD) * DRIFT
	camera.position = CAMERA_POS + Vector3(drift, 0, 0)
	camera.look_at(LOOK_AT + Vector3(drift * .5, 0, 0), Vector3.UP)
