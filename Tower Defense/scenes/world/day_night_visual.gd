extends Node

# Spec: docs/specs/006-ciclo-dia-noite.md — representacao visual de DIA/NOITE.
# So reage aos sinais do DayNightManager (autoload); nao altera estado nem regras.
# Valores de DIA sao lidos da cena no _ready (luz + Environment) e sempre
# reaplicados a partir desses valores-base, nunca multiplicados em cima do atual.

@export var light_path: NodePath = ^"../DirectionalLight3D"
@export var world_environment_path: NodePath = ^"../WorldEnvironment"

@export_group("Noite")
@export var night_light_energy := 0.55
@export var night_light_color := Color(0.55, 0.65, 1.0)
@export var night_ambient_energy := 0.50
@export var night_ambient_color := Color(0.35, 0.45, 0.8)
@export var night_background_color := Color(0.06, 0.09, 0.18)

@export_group("Transicao")
@export_range(0.0, 5.0, 0.1) var transition_duration := 1.5 # 0 = instantaneo

var _light: DirectionalLight3D
var _env: Environment
var _tween: Tween

# Valores-base de DIA, capturados da cena ao iniciar.
var _day_light_energy: float
var _day_light_color: Color
var _day_ambient_energy: float
var _day_ambient_color: Color
var _day_background_color: Color

func _ready() -> void:
	_light = get_node_or_null(light_path) as DirectionalLight3D
	var world_env := get_node_or_null(world_environment_path) as WorldEnvironment
	if world_env != null:
		_env = world_env.environment
	if _light == null or _env == null:
		push_error("DayNightVisual: DirectionalLight3D ou WorldEnvironment/Environment nao encontrado.")
		return

	_day_light_energy = _light.light_energy
	_day_light_color = _light.light_color
	_day_ambient_energy = _env.ambient_light_energy
	_day_ambient_color = _env.ambient_light_color
	_day_background_color = _env.background_color

	DayNightManager.night_started.connect(_on_night_started)
	DayNightManager.day_started.connect(_on_day_started)
	if DayNightManager.is_night():
		_apply(true, 0.0)

func _on_night_started() -> void:
	print("[VISUAL DIA/NOITE] Aplicando visual de NOITE")
	_apply(true, transition_duration)

func _on_day_started() -> void:
	print("[VISUAL DIA/NOITE] Aplicando visual de DIA")
	_apply(false, transition_duration)

func _apply(night: bool, duration: float) -> void:
	var targets := {
		"light_energy": night_light_energy if night else _day_light_energy,
		"light_color": night_light_color if night else _day_light_color,
	}
	var env_targets := {
		"ambient_light_energy": night_ambient_energy if night else _day_ambient_energy,
		"ambient_light_color": night_ambient_color if night else _day_ambient_color,
		"background_color": night_background_color if night else _day_background_color,
	}

	if _tween != null and _tween.is_valid():
		_tween.kill()

	if duration <= 0.0:
		for prop in targets:
			_light.set(prop, targets[prop])
		for prop in env_targets:
			_env.set(prop, env_targets[prop])
		return

	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	for prop in targets:
		_tween.tween_property(_light, prop, targets[prop], duration)
	for prop in env_targets:
		_tween.tween_property(_env, prop, env_targets[prop], duration)
