extends Camera3D

# Spec: docs/specs/007-camera-estrategica.md
# RF-CAM-001 — Camera estrategica elevada (PROVISORIO)
# RF-CAM-002 — Orientacao estavel, sem herdar a rotacao do jogador (PROVISORIO)
#
# Filha do Player so por organizacao de cena: com top_level = true ela ignora o
# transform do pai e apenas persegue a POSICAO do alvo. A rotacao do Player
# (mirar/atacar) nunca chega aqui. A projecao continua em perspectiva; o FOV e
# o proprio `fov` do Camera3D no Inspector.

@export var target_path: NodePath = ^".."
## Distancia da camera ate o ponto de foco, ao longo da linha de visao (m).
@export_range(6.0, 45.0, 0.5, "suffix:m") var distance := 20.0
## Inclinacao para baixo (graus). Altura = distance * sin(pitch).
@export_range(20.0, 85.0, 0.5, "suffix:°") var pitch_degrees := 50.0
## Orientacao fixa no plano horizontal. 0 = camera ao sul (+Z) olhando para o norte (-Z).
@export_range(-180.0, 180.0, 1.0, "suffix:°") var yaw_degrees := 0.0
## Deslocamento do ponto de foco em relacao a origem do alvo (pes do Player).
@export var focus_offset := Vector3(0.0, 1.0, 0.0)
## Rapidez do acompanhamento. Maior = mais colado; 0 = sem suavizacao.
@export_range(0.0, 30.0, 0.1) var follow_smoothing := 8.0

var _target: Node3D
var _focus := Vector3.ZERO

func _ready() -> void:
	top_level = true
	_target = get_node_or_null(target_path) as Node3D
	if _target != null:
		_focus = _target.global_position + focus_offset
	_apply_transform()

func _physics_process(delta: float) -> void:
	# Mesmo passo de fisica do CharacterBody3D, para nao tremer ao segui-lo.
	if is_instance_valid(_target):
		var goal := _target.global_position + focus_offset
		if follow_smoothing <= 0.0:
			_focus = goal
		else:
			_focus = _focus.lerp(goal, 1.0 - exp(-follow_smoothing * delta))
	_apply_transform()

func _apply_transform() -> void:
	var pitch := deg_to_rad(pitch_degrees)
	var yaw := deg_to_rad(yaw_degrees)
	var back := Vector3(sin(yaw), 0.0, cos(yaw))
	var offset := back * cos(pitch) * distance + Vector3.UP * sin(pitch) * distance
	global_transform = Transform3D(Basis.from_euler(Vector3(-pitch, yaw, 0.0)), _focus + offset)

func get_height() -> float:
	return distance * sin(deg_to_rad(pitch_degrees))

func get_horizontal_distance() -> float:
	return distance * cos(deg_to_rad(pitch_degrees))

# RF-CAM-003: converte a entrada WASD (x = direita, z = tras) para o mundo usando
# a frente/direita da camera projetadas no plano horizontal.
func planar_direction(input_dir: Vector3) -> Vector3:
	var forward := -global_basis.z
	forward.y = 0.0
	var right := global_basis.x
	right.y = 0.0
	return (right.normalized() * input_dir.x - forward.normalized() * input_dir.z).normalized()

# RF-CAM-004: ponto do mundo sob o cursor, no plano horizontal de altura `plane_y`.
# Retorna null se o raio nao cruzar o plano (cursor acima do horizonte).
func screen_to_ground(screen_pos: Vector2, plane_y: float) -> Variant:
	var origin := project_ray_origin(screen_pos)
	var normal := project_ray_normal(screen_pos)
	return Plane(Vector3.UP, plane_y).intersects_ray(origin, normal)
