extends MeshInstance3D

# World 6.0 — barra de vida grafica sob o rotulo da criatura ("ALIADO · 64/80").
# So apresentacao: le hp / MAX_HP de quem a HUD pedir e anima. O numero do
# rotulo atualiza na hora; a barra desce (dano) ou sobe (cura) suave, com
# rastro claro do dano, piscada no golpe e brilho jade na cura. Cor por faccao.
# Filha do Label3D: aparece e some junto com ele (mesma prioridade da HUD).

const SHADER := preload("res://scenes/visuals/creature_health_bar.gdshader")
const WIDTH := 1.2 # m
const HEIGHT := 0.17 # m (legivel da camera estrategica, ~20 m)

## Cores por faccao (preenchimento).
const TONES := {
	&"ally": Color("69c7a0"),
	&"wild": Color("c9805a"),
	&"guardian": Color("e7ae58"),
	&"invader": Color("5a5fd6"),
}

static var _mesh: QuadMesh

var shown := 1.0 # fracao desenhada (anima ate o alvo)
var ghost := 1.0 # rastro do dano (espera e desce)
var target := 1.0
var _ghost_hold := 0.0
var _heal := 0.0
var _flash := 0.0
var _mat: ShaderMaterial
var faction := &"wild"

static func quad() -> QuadMesh:
	if _mesh == null:
		_mesh = QuadMesh.new()
		_mesh.size = Vector2(WIDTH, HEIGHT)
	return _mesh

func _init() -> void:
	name = "HealthBar"
	mesh = quad()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("size", Vector2(WIDTH, HEIGHT))
	material_override = _mat
	set_process(true)

## Chamado pela HUD a cada quadro em que o rotulo esta visivel.
func show_health(frac: float, kind: StringName, opacity := 1.0) -> void:
	frac = clampf(frac, 0.0, 1.0)
	if kind != faction:
		faction = kind
		_mat.set_shader_parameter("tone", TONES.get(kind, TONES[&"wild"]))
	if frac < target - 0.001: # dano: rastro fica onde estava, golpe pisca
		ghost = maxf(ghost, shown)
		_ghost_hold = 0.35
		_flash = 1.0
	elif frac > target + 0.001: # cura: brilho jade
		_heal = 1.0
	target = frac
	_mat.set_shader_parameter("alpha", opacity)

## Encaixa sem animar (primeira vez que a criatura aparece).
func snap(frac: float) -> void:
	shown = clampf(frac, 0.0, 1.0)
	ghost = shown
	target = shown

func _process(delta: float) -> void:
	# Dano: a barra cai rapido; cura: sobe um pouco mais devagar (le-se o ganho).
	var speed := 2.2 if target < shown else 1.2
	shown = move_toward(shown, target, delta * speed)
	_ghost_hold -= delta
	if _ghost_hold <= 0.0:
		ghost = move_toward(ghost, shown, delta * 0.8)
	ghost = maxf(ghost, shown)
	_heal = move_toward(_heal, 0.0, delta / 0.9)
	_flash = move_toward(_flash, 0.0, delta / 0.18)
	_mat.set_shader_parameter("fill", shown)
	_mat.set_shader_parameter("ghost", ghost)
	_mat.set_shader_parameter("heal", _heal)
	_mat.set_shader_parameter("flash", _flash)
