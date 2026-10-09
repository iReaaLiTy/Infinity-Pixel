extends Node

# Spec: docs/specs/006-ciclo-dia-noite.md — representacao visual de DIA/NOITE.
# Spec: docs/specs/014-ceu-iluminacao-progressiva.md — RF-CEU-001 a 012 (PROVISORIO)
#
# Controlador visual do ciclo. NAO tem relogio proprio: a cada quadro le
# DayNightManager.clock_hours() (a mesma fonte do relogio da HUD) e converte o
# horario em Sol/Lua (direcao, cor, energia, sombra), luz ambiente, exposicao,
# neblina leve, ceu (shader), estrelas e o brilho noturno das fontes locais
# (refugio, torres, Fogueira, armadilhas). Tudo por interpolacao entre quadros-
# chave por hora — sem estados "dia"/"noite" bruscos.
#
# - So avanca quando DayNightManager.can_play(): pausa, menu e derrota congelam.
# - 05:59 -> 08:00 (novo dia): o relogio salta; o visual percorre 06:00-08:00
#   em ~2,7 s (CATCH_UP_RATE) em vez de piscar.
# - Reiniciar cria um mundo novo: _ready() encaixa direto no horario (08:00).
# - Nao altera regras: so le o tempo e escreve em luz, ambiente e materiais.

@export var light_path: NodePath = ^"../DirectionalLight3D"
@export var world_environment_path: NodePath = ^"../WorldEnvironment"
@export var art_path: NodePath = ^"../ArenaArt"
@export var refuge_path: NodePath = ^"../Territory"

const SKY_SHADER := preload("res://scenes/world/day_night_sky.gdshader")
const GLINT_SHADER := preload("res://scenes/world/night_glints.gdshader")

const SNAP_GAP := 0.35 # h: diferenca maior que isso = salto do relogio -> transicao
const CATCH_UP_RATE := 0.75 # h por segundo de jogo durante a transicao
const SKY_UPDATE_INTERVAL := 0.2 # s entre atualizacoes do shader do ceu
const SUN_TO_MOON := 19.0 # h: a luz direcional passa a ser a Lua (energia ~0)
const MOON_TO_SUN := 5.25 # h: volta a ser o Sol (energia ~0)
const GLINT_COUNT := 120

# Quadros-chave por hora (0-24). Entre eles tudo e interpolado linearmente; o
# ultimo liga com o primeiro (+24 h). Valores de PROTOTIPO (ajustar no playtest).
# light/energy: Sol ou Lua; amb: luz ambiente; top/hor: ceu; fog: neblina;
# stars/moon: 0..1; glow: brilho noturno das fontes locais; exp: exposicao;
# shadow: opacidade da sombra direcional.
const KEYS := [
	{"h": 0.0, "light": Color(0.60, 0.70, 1.0), "energy": 0.32, "amb": Color(0.30, 0.38, 0.64), "amb_e": 0.55, "top": Color(0.02, 0.03, 0.09), "hor": Color(0.06, 0.09, 0.18), "fog": Color(0.07, 0.10, 0.19), "fog_d": 0.004, "stars": 1.0, "moon": 1.0, "glow": 1.0, "exp": 1.12, "shadow": 0.55},
	{"h": 4.5, "light": Color(0.62, 0.70, 0.98), "energy": 0.28, "amb": Color(0.32, 0.38, 0.62), "amb_e": 0.55, "top": Color(0.03, 0.04, 0.11), "hor": Color(0.10, 0.11, 0.22), "fog": Color(0.09, 0.10, 0.20), "fog_d": 0.004, "stars": 0.85, "moon": 0.8, "glow": 1.0, "exp": 1.12, "shadow": 0.55},
	{"h": 5.0, "light": Color(0.70, 0.68, 0.88), "energy": 0.14, "amb": Color(0.42, 0.42, 0.62), "amb_e": 0.52, "top": Color(0.08, 0.10, 0.24), "hor": Color(0.40, 0.32, 0.44), "fog": Color(0.30, 0.30, 0.40), "fog_d": 0.0045, "stars": 0.5, "moon": 0.45, "glow": 0.9, "exp": 1.1, "shadow": 0.5},
	{"h": 5.25, "light": Color(0.95, 0.66, 0.55), "energy": 0.06, "amb": Color(0.52, 0.48, 0.62), "amb_e": 0.5, "top": Color(0.14, 0.20, 0.40), "hor": Color(0.66, 0.46, 0.46), "fog": Color(0.46, 0.42, 0.48), "fog_d": 0.0045, "stars": 0.3, "moon": 0.3, "glow": 0.82, "exp": 1.08, "shadow": 0.5},
	{"h": 5.6, "light": Color(1.0, 0.74, 0.58), "energy": 0.28, "amb": Color(0.62, 0.58, 0.68), "amb_e": 0.46, "top": Color(0.25, 0.36, 0.60), "hor": Color(0.92, 0.66, 0.52), "fog": Color(0.62, 0.56, 0.56), "fog_d": 0.004, "stars": 0.1, "moon": 0.15, "glow": 0.7, "exp": 1.05, "shadow": 0.7},
	{"h": 6.0, "light": Color(1.0, 0.78, 0.58), "energy": 0.46, "amb": Color(0.78, 0.72, 0.70), "amb_e": 0.40, "top": Color(0.36, 0.52, 0.78), "hor": Color(0.96, 0.78, 0.62), "fog": Color(0.74, 0.70, 0.66), "fog_d": 0.0035, "stars": 0.0, "moon": 0.05, "glow": 0.5, "exp": 1.02, "shadow": 0.85},
	{"h": 7.0, "light": Color(1.0, 0.85, 0.66), "energy": 0.68, "amb": Color(0.88, 0.86, 0.82), "amb_e": 0.36, "top": Color(0.40, 0.62, 0.88), "hor": Color(0.80, 0.86, 0.84), "fog": Color(0.75, 0.82, 0.80), "fog_d": 0.003, "stars": 0.0, "moon": 0.0, "glow": 0.15, "exp": 1.0, "shadow": 1.0},
	{"h": 8.0, "light": Color(1.0, 0.89, 0.70), "energy": 0.80, "amb": Color(0.95, 0.95, 0.92), "amb_e": 0.35, "top": Color(0.38, 0.62, 0.92), "hor": Color(0.72, 0.84, 0.86), "fog": Color(0.70, 0.80, 0.80), "fog_d": 0.0025, "stars": 0.0, "moon": 0.0, "glow": 0.0, "exp": 1.0, "shadow": 1.0},
	{"h": 10.5, "light": Color(1.0, 0.94, 0.82), "energy": 0.68, "amb": Color(1.0, 1.0, 0.98), "amb_e": 0.33, "top": Color(0.30, 0.56, 0.92), "hor": Color(0.66, 0.82, 0.90), "fog": Color(0.68, 0.80, 0.84), "fog_d": 0.0025, "stars": 0.0, "moon": 0.0, "glow": 0.0, "exp": 0.98, "shadow": 1.0},
	{"h": 12.0, "light": Color(1.0, 0.96, 0.88), "energy": 0.64, "amb": Color(1.0, 1.0, 1.0), "amb_e": 0.32, "top": Color(0.30, 0.56, 0.92), "hor": Color(0.66, 0.82, 0.90), "fog": Color(0.68, 0.80, 0.84), "fog_d": 0.0025, "stars": 0.0, "moon": 0.0, "glow": 0.0, "exp": 0.97, "shadow": 1.0},
	{"h": 13.5, "light": Color(1.0, 0.95, 0.86), "energy": 0.65, "amb": Color(1.0, 0.99, 0.97), "amb_e": 0.32, "top": Color(0.30, 0.56, 0.92), "hor": Color(0.68, 0.82, 0.88), "fog": Color(0.70, 0.80, 0.82), "fog_d": 0.0025, "stars": 0.0, "moon": 0.0, "glow": 0.0, "exp": 0.97, "shadow": 1.0},
	{"h": 15.5, "light": Color(1.0, 0.90, 0.74), "energy": 0.70, "amb": Color(0.98, 0.94, 0.88), "amb_e": 0.35, "top": Color(0.32, 0.55, 0.88), "hor": Color(0.80, 0.82, 0.80), "fog": Color(0.78, 0.78, 0.74), "fog_d": 0.0028, "stars": 0.0, "moon": 0.0, "glow": 0.0, "exp": 1.0, "shadow": 1.0},
	{"h": 16.5, "light": Color(1.0, 0.84, 0.64), "energy": 0.72, "amb": Color(0.95, 0.88, 0.82), "amb_e": 0.34, "top": Color(0.34, 0.50, 0.82), "hor": Color(0.92, 0.80, 0.66), "fog": Color(0.82, 0.76, 0.68), "fog_d": 0.003, "stars": 0.0, "moon": 0.0, "glow": 0.12, "exp": 1.0, "shadow": 1.0},
	{"h": 17.3, "light": Color(1.0, 0.78, 0.56), "energy": 0.62, "amb": Color(0.88, 0.80, 0.80), "amb_e": 0.34, "top": Color(0.32, 0.40, 0.70), "hor": Color(0.98, 0.68, 0.50), "fog": Color(0.84, 0.70, 0.62), "fog_d": 0.0035, "stars": 0.0, "moon": 0.0, "glow": 0.3, "exp": 1.0, "shadow": 0.95},
	{"h": 18.0, "light": Color(1.0, 0.64, 0.44), "energy": 0.50, "amb": Color(0.72, 0.62, 0.70), "amb_e": 0.36, "top": Color(0.30, 0.32, 0.58), "hor": Color(0.95, 0.62, 0.52), "fog": Color(0.64, 0.52, 0.56), "fog_d": 0.0035, "stars": 0.0, "moon": 0.0, "glow": 0.5, "exp": 1.03, "shadow": 0.85},
	{"h": 18.6, "light": Color(0.70, 0.56, 0.68), "energy": 0.20, "amb": Color(0.46, 0.44, 0.66), "amb_e": 0.44, "top": Color(0.14, 0.16, 0.38), "hor": Color(0.58, 0.40, 0.50), "fog": Color(0.36, 0.32, 0.44), "fog_d": 0.004, "stars": 0.08, "moon": 0.1, "glow": 0.7, "exp": 1.06, "shadow": 0.7},
	{"h": 19.0, "light": Color(0.62, 0.62, 0.85), "energy": 0.06, "amb": Color(0.40, 0.40, 0.62), "amb_e": 0.47, "top": Color(0.08, 0.10, 0.26), "hor": Color(0.32, 0.26, 0.42), "fog": Color(0.22, 0.22, 0.34), "fog_d": 0.004, "stars": 0.3, "moon": 0.35, "glow": 0.82, "exp": 1.08, "shadow": 0.6},
	{"h": 20.0, "light": Color(0.60, 0.70, 1.0), "energy": 0.26, "amb": Color(0.32, 0.38, 0.64), "amb_e": 0.52, "top": Color(0.03, 0.05, 0.14), "hor": Color(0.10, 0.12, 0.24), "fog": Color(0.09, 0.12, 0.22), "fog_d": 0.004, "stars": 0.8, "moon": 0.8, "glow": 0.95, "exp": 1.1, "shadow": 0.55},
	{"h": 21.0, "light": Color(0.60, 0.70, 1.0), "energy": 0.32, "amb": Color(0.30, 0.38, 0.64), "amb_e": 0.55, "top": Color(0.02, 0.035, 0.10), "hor": Color(0.07, 0.10, 0.20), "fog": Color(0.07, 0.10, 0.19), "fog_d": 0.004, "stars": 1.0, "moon": 1.0, "glow": 1.0, "exp": 1.12, "shadow": 0.55},
]

var light: DirectionalLight3D
var env: Environment
var sky_material: ShaderMaterial
var glints: MultiMeshInstance3D
var glint_material: ShaderMaterial

## Hora mostrada pelo visual (0-24). Igual a clock_hours(), exceto durante a
## transicao curta depois de um salto do relogio (05:59 -> 08:00).
var shown_hour := 8.0
## Ultima amostra aplicada (chaves de KEYS). Leitura para testes/depuracao.
var current := {}
var sun_dir := Vector3.UP
var moon_dir := Vector3.UP
var night_glow := 0.0
var _twinkle_time := 0.0
var _sky_wait := 0.0
var _refuge_mat: StandardMaterial3D
var _refuge_light: OmniLight3D
var _torches: Array[OmniLight3D] = []

func _ready() -> void:
	add_to_group("day_night_visual")
	light = get_node_or_null(light_path) as DirectionalLight3D
	var world_env := get_node_or_null(world_environment_path) as WorldEnvironment
	if light == null or world_env == null or world_env.environment == null:
		push_error("DayNightVisual: DirectionalLight3D ou WorldEnvironment/Environment nao encontrado.")
		return
	# Copia por mundo: o Environment da cena e compartilhado entre instancias e
	# o ciclo anterior nao pode vazar para o proximo Reiniciar.
	env = world_env.environment.duplicate()
	world_env.environment = env
	_setup_environment()
	_bind_refuge()
	# Metodos (nao lambdas): o Godot desconecta sozinho quando o mundo e liberado.
	DayNightManager.night_started.connect(_on_night_started)
	DayNightManager.day_started.connect(_on_day_started)
	snap()
	_build_glints.call_deferred()

func _on_night_started() -> void:
	print("[VISUAL DIA/NOITE] 18:00 — por do sol em andamento")

func _on_day_started() -> void:
	print("[VISUAL DIA/NOITE] Novo dia — amanhecer -> manha (transicao suave)")

func _setup_environment() -> void:
	sky_material = ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_material
	# A luz ambiente vem das chaves (cor), nao do ceu: radiancia minima.
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# Neblina de profundidade MUITO leve (GL Compatibility suporta; sem volumetria).
	env.fog_enabled = true
	env.fog_light_energy = 1.0
	env.fog_sky_affect = 0.0

## Encaixa o visual no horario atual, sem transicao (inicio/reinicio/testes).
func snap() -> void:
	shown_hour = fposmod(DayNightManager.clock_hours(), 24.0)
	_apply(true)

func _process(delta: float) -> void:
	if env == null or not DayNightManager.can_play():
		return # pausa, menu e derrota congelam Sol, Lua, ceu e estrelas
	_twinkle_time += delta
	var target := fposmod(DayNightManager.clock_hours(), 24.0)
	var gap := wrapped_gap(shown_hour, target)
	if absf(gap) <= SNAP_GAP:
		shown_hour = target
	else:
		shown_hour = fposmod(shown_hour + signf(gap) * minf(absf(gap), CATCH_UP_RATE * delta), 24.0)
	_sky_wait -= delta
	_apply(_sky_wait <= 0.0)

## Diferenca de `from` para `to` no relogio circular, em (-12, 12].
static func wrapped_gap(from: float, to: float) -> float:
	return fposmod(to - from + 12.0, 24.0) - 12.0

## Amostra interpolada dos quadros-chave para uma hora (0-24).
static func sample(hour: float) -> Dictionary:
	var h := fposmod(hour, 24.0)
	var i := KEYS.size() - 1
	for k in KEYS.size():
		if KEYS[k].h <= h:
			i = k
	var a: Dictionary = KEYS[i]
	var b: Dictionary = KEYS[(i + 1) % KEYS.size()]
	var span: float = fposmod(b.h - a.h, 24.0)
	var t: float = fposmod(h - a.h, 24.0) / span if span > 0.0 else 0.0
	var out := {"h": h}
	for key in a:
		if key == "h":
			continue
		out[key] = a[key].lerp(b[key], t) if a[key] is Color else lerpf(a[key], b[key], t)
	return out

static func is_sun_hour(hour: float) -> bool:
	var h := fposmod(hour, 24.0)
	return h >= MOON_TO_SUN and h < SUN_TO_MOON

## Direcao PARA o Sol: nasce a leste (+X), passa ao sul (+Z, atras da camera,
## sombras para o norte) e se poe a oeste. 30 graus as 08:00, 60 ao meio-dia.
## Spec 017A: o arco e girado SUN_AZIMUTH_OFFSET para o leste. Com o Sol exatamente
## atras da camera ao meio-dia a luz era frontal e o cenario ficava chapado; agora
## ela vem de tras e da direita (~40 graus), e as faces oeste ganham sombra.
## So direcao: horarios, energia, cores, ambiente e relogio nao mudam.
const SUN_AZIMUTH_OFFSET := -0.7
static func sun_direction(hour: float) -> Vector3:
	var s := (fposmod(hour, 24.0) - 6.0) / 12.0
	var elevation := deg_to_rad(maxf(6.0, 60.0 * sin(PI * clampf(s, 0.0, 1.0))))
	var a := PI * clampf(s, -0.1, 1.1) + SUN_AZIMUTH_OFFSET
	return (Vector3(cos(a), 0.0, sin(a)) * cos(elevation) + Vector3.UP * sin(elevation)).normalized()

## Direcao PARA a Lua: nasce ~18:30 a leste, alta perto da 00:00, se poe ~06:00.
## Elevacao minima de 15 graus: sombras longas demais confundiriam a leitura.
static func moon_direction(hour: float) -> Vector3:
	var h := fposmod(hour, 24.0)
	var m := ((h + 24.0 if h < 12.0 else h) - 18.5) / 11.5
	var elevation := deg_to_rad(maxf(15.0, 55.0 * sin(PI * clampf(m, 0.0, 1.0))))
	var a := PI * clampf(m, 0.0, 1.0)
	return (Vector3(cos(a), 0.0, sin(a) * 0.8).normalized() * cos(elevation) + Vector3.UP * sin(elevation)).normalized()

func _apply(update_sky: bool) -> void:
	if env == null:
		return
	current = sample(shown_hour)
	sun_dir = sun_direction(shown_hour)
	moon_dir = moon_direction(shown_hour)
	var sun := is_sun_hour(shown_hour)
	light.light_color = current.light
	light.light_energy = current.energy
	light.shadow_opacity = current.shadow
	light.global_basis = Basis.looking_at(-(sun_dir if sun else moon_dir), Vector3.UP)
	env.ambient_light_color = current.amb
	env.ambient_light_energy = current.amb_e
	env.fog_light_color = current.fog
	env.fog_density = current.fog_d
	env.tonemap_exposure = current.exp
	night_glow = current.glow
	for node in get_tree().get_nodes_in_group("night_glow"):
		node.set_night_glow(night_glow)
	_apply_refuge(night_glow)
	if glint_material != null:
		glint_material.set_shader_parameter("stars", current.stars)
		glint_material.set_shader_parameter("twinkle_time", _twinkle_time)
		glints.visible = current.stars > 0.01
	if update_sky:
		_sky_wait = SKY_UPDATE_INTERVAL
		sky_material.set_shader_parameter("top_color", current.top)
		sky_material.set_shader_parameter("horizon_color", current.hor)
		sky_material.set_shader_parameter("ground_color", current.amb * current.amb_e)
		sky_material.set_shader_parameter("sun_dir", sun_dir)
		sky_material.set_shader_parameter("sun_color", current.light)
		sky_material.set_shader_parameter("sun_alpha", 1.0 if sun else 0.0)
		sky_material.set_shader_parameter("moon_dir", moon_dir)
		sky_material.set_shader_parameter("moon_alpha", current.moon)
		sky_material.set_shader_parameter("stars", current.stars)

# --- Refugio (RF-CEU-008): "minha base esta ali" -----------------------------
# A arte do vale (arena_art.tscn, gerada) tem o nucleo e as tochas do refugio.
# O material quente e compartilhado com o fundo do menu: aqui ele e duplicado
# por mundo, para a noite nunca vazar para o menu.
func _bind_refuge() -> void:
	var art := get_node_or_null(art_path)
	if art != null:
		for n in ["Glow-1", "Glow1"]:
			var torch := art.get_node_or_null(n) as OmniLight3D
			if torch != null:
				_torches.append(torch)
		for n in ["RefugeCore", "RefugeCap", "Flame-1", "Flame1"]:
			var mi := art.get_node_or_null(n) as MeshInstance3D
			if mi != null and mi.material_override is StandardMaterial3D:
				if _refuge_mat == null:
					_refuge_mat = mi.material_override.duplicate()
				mi.material_override = _refuge_mat
	var refuge := get_node_or_null(refuge_path) as Node3D
	if refuge != null:
		_refuge_light = OmniLight3D.new()
		_refuge_light.name = "RefugeNightLight"
		_refuge_light.light_color = Color(1.0, 0.82, 0.58)
		_refuge_light.omni_range = 10.0
		_refuge_light.shadow_enabled = false
		_refuge_light.position = Vector3(0, 3.4, 0)
		refuge.add_child(_refuge_light)

func _apply_refuge(glow: float) -> void:
	for torch in _torches:
		torch.light_energy = lerpf(1.0, 1.6, glow)
	if _refuge_mat != null:
		_refuge_mat.emission_energy_multiplier = lerpf(1.5, 2.6, glow)
	if _refuge_light != null:
		_refuge_light.light_energy = 1.3 * glow
		_refuge_light.visible = glow > 0.01

# --- Estrelas no chao (RF-CEU-007) --------------------------------------------
# A camera estrategica nunca ve o ceu (medido: 0% na Spec 014). Alem das
# estrelas do shader do ceu, pontinhos que cintilam no gramado aparecem aos
# poucos ao anoitecer: 1 MultiMesh, sem luzes, sem sombra, sem colisao.
func _build_glints() -> void:
	await get_tree().physics_frame
	if not is_inside_tree() or light == null:
		return
	var space := light.get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = 14014 # sempre os mesmos pontos
	var points: Array[Vector3] = []
	for attempt in GLINT_COUNT * 4:
		if points.size() >= GLINT_COUNT:
			break
		var x := rng.randf_range(-23.0, 23.0)
		var z := rng.randf_range(-22.0, 27.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 25, z), Vector3(x, -2, z), 1))
		if hit.is_empty() or hit.position.y > 0.3:
			continue # so no chao aberto (nada em copas, troncos ou rochas)
		points.append(hit.position + Vector3(0, 0.06, 0))
	var mesh := SphereMesh.new()
	mesh.radius = 0.045
	mesh.height = 0.09
	mesh.radial_segments = 4
	mesh.rings = 2
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = points.size()
	for i in points.size():
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * rng.randf_range(0.7, 1.3)), points[i]))
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf() * 0.85, 0.0, 0.0))
	glint_material = ShaderMaterial.new()
	glint_material.shader = GLINT_SHADER
	glints = MultiMeshInstance3D.new()
	glints.name = "NightGlints"
	glints.multimesh = mm
	glints.material_override = glint_material
	glints.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light.get_parent().add_child(glints)
	_apply(false)
