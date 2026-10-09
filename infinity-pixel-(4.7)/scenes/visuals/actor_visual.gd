extends Node3D

# Spec 019: apresentacao das criaturas. So visual: nada aqui muda velocidade,
# rumo, alvo, dano ou tempo de ataque. Os indicadores (anel de domesticacao,
# marcador de FICAR) ficam no corpo, fora deste no, para nao se misturarem com
# as malhas do modelo.
const CombatFX := preload("res://scenes/visuals/combat_fx.gd")
const JADE := Color("3fbf8f")
const JADE_LIGHT := Color("a8e6cf")
const HIT_WARM := Color("ffe2a8")

var clock := 0.0
var swing := 0.0
var flash_time := 0.0
var ally := false
## Inimigo da onda noturna (Spec 019 antecipada): paleta azul-violeta propria.
var night_threat := false
var _day_materials := {} # malha -> material original (para voltar ao domesticar)
var _flash_mat: StandardMaterial3D # lampejo do golpe (material_overlay, por ator)
var _flashing := false
var _tame_ring: MeshInstance3D
var _tame_fill: MeshInstance3D
var _tame_mat: StandardMaterial3D
var _fill_mat: StandardMaterial3D
var _stay_pin: MeshInstance3D

const Facetize := preload("res://scenes/visuals/facetize.gd")
var _cape: MeshInstance3D

func _ready() -> void:
	# Polimento (playtest 09/10/2026): primitivas lisas -> facetadas, mesmas
	# medidas, nos e materiais (a paleta noturna por instancia continua igual).
	Facetize.apply(self)
	if has_node("Scarf"):
		_build_cape() # so o Player (modelo com cachecol)

## Capa jade curta nas costas do Player: silhueta reconhecivel de longe.
func _build_cape() -> void:
	var scarf := get_node("Scarf") as Node3D
	var top := scarf.position + Vector3(0, -0.02, 0.3) # atras da tunica (fundo r 0,31)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xs := [-0.3, -0.1, 0.1, 0.3]
	var bottom := [-0.72, -0.8, -0.8, -0.72]
	for i in 3:
		var a := Vector3(xs[i], 0, 0)
		var b := Vector3(xs[i + 1], 0, 0)
		var c := Vector3(xs[i + 1] * 1.25, bottom[i + 1], 0.14 + 0.03 * (i % 2))
		var d := Vector3(xs[i] * 1.25, bottom[i], 0.14 + 0.03 * ((i + 1) % 2))
		for tri in [[a, b, c], [a, c, d]]:
			var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
			for v in tri:
				st.set_normal(n)
				st.add_vertex(v)
	_cape = MeshInstance3D.new()
	_cape.name = "Cape"
	_cape.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("2f7d63")
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cape.material_override = m
	_cape.position = top
	add_child(_cape)

func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	if body == null:
		return
	clock += delta
	var actual := body.get_real_velocity()
	var pace := minf(Vector2(actual.x, actual.z).length() / 4.0, 1.0)
	if pace < .025: pace = 0.0
	$LegL.rotation.x = sin(clock * 11.0) * 0.48 * pace
	$LegR.rotation.x = -sin(clock * 11.0) * 0.48 * pace
	swing = maxf(0, swing - delta)
	position.y = abs(sin(clock * 11)) * .04 * pace
	# Golpe + recuo visual curto ao receber dano (sem empurrar o corpo) +
	# inclinacao para tras durante a preparacao do golpe.
	var wind := 0.0
	if _windup_time > 0.0:
		_windup_time = maxf(0.0, _windup_time - delta)
		wind = 1.0 - _windup_time / maxf(_windup_total, 0.001)
		if is_instance_valid(_telegraph):
			_telegraph_mat.albedo_color.a = 0.15 + 0.45 * wind
	elif is_instance_valid(_telegraph) and _telegraph.visible:
		_telegraph.visible = false
	rotation.x = -sin(swing * PI / .32) * .2 + sin(flash_time / .22 * PI) * .1 * float(flash_time > 0.0 and flash_time <= .22) + 0.16 * wind
	# Braços acompanham a passada (o direito so quando nao esta golpeando).
	if has_node("ArmL"):
		$ArmL.rotation.x = -sin(clock * 11.0) * 0.55 * pace
	if has_node("ArmR"):
		$ArmR.rotation.x = -sin(swing * PI / .32) * 1.6 if swing > 0.0 else sin(clock * 11.0) * 0.55 * pace
	# Leve inclinacao a frente correndo; capa balanca com o passo.
	rotation.x -= 0.07 * pace
	if is_instance_valid(_cape):
		_cape.rotation.x = 0.12 + 0.4 * pace + sin(clock * 7.0) * 0.05 * (0.3 + pace)
	if has_node("Tail"):
		$Tail.rotation.y = sin(clock * 3) * (.13 + .07 * (1.0 - pace))
	flash_time = maxf(0, flash_time - delta)
	# Respiracao em repouso: o peito sobe e desce devagar (some ao andar).
	var breathe := sin(clock * 2.3) * 0.022 * (1.0 - pace)
	var pulse := sin(flash_time * 28) * .045
	scale = Vector3(1.0 + pulse, 1.0 + pulse + breathe, 1.0 + pulse)
	if _flashing and flash_time <= 0.0:
		_set_overlay(null)
	elif _flashing:
		_flash_mat.albedo_color.a = 0.3 * minf(flash_time / .22, 1.0)
	if body.has_method("can_be_domesticated"):
		_update_indicators(body, delta)

func strike() -> void:
	swing = .32
	_windup_time = 0.0
	if is_instance_valid(_telegraph):
		_telegraph.visible = false

# Balanceamento (playtest 09/10/2026): preparacao do golpe hostil. O corpo
# recua e ergue a cabeca, e um arco ambar-avermelhado no chao mostra a area do
# golpe (alcance ~2 m) enquanto ele carrega. So visual.
var _windup_time := 0.0
var _windup_total := 0.0
var _telegraph: MeshInstance3D
var _telegraph_mat: StandardMaterial3D
func windup(seconds: float) -> void:
	_windup_time = seconds
	_windup_total = seconds
	var body := get_parent() as Node3D
	if body == null:
		return
	if not is_instance_valid(_telegraph):
		_telegraph_mat = CombatFX.fx_material(Color("e0795a"), 0.0)
		_telegraph = _indicator(body, CombatFX.arc_mesh(), _telegraph_mat, "Telegraph")
		_telegraph.scale = Vector3.ONE * 1.45 # arco 1,5 m -> ~2,2 m (alcance + folga)
	_telegraph.visible = true

## Preparou e errou (o alvo recuou): some o aviso, sem golpe.
func whiff() -> void:
	_windup_time = 0.0
	if is_instance_valid(_telegraph):
		_telegraph.visible = false

func flash() -> void:
	flash_time = .22
	# Lampejo claro sobre o modelo (overlay por ator; os materiais nao mudam)
	# e faisca no ponto do golpe.
	if _flash_mat == null:
		_flash_mat = CombatFX.fx_material(Color.WHITE, 0.3)
	_flash_mat.albedo_color = Color(HIT_WARM if not night_threat else Color("c9d0ff"), 0.3)
	_set_overlay(_flash_mat)
	if is_inside_tree():
		CombatFX.hit_spark(self, global_position + Vector3(0, 0.9, 0), HIT_WARM if not night_threat else Color("8f9cf0"))

func _set_overlay(mat: Material) -> void:
	_flashing = mat != null
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = mat

## Eliminacao: lascas na cor da criatura e anel no chao (o corpo some em seguida).
func defeated() -> void:
	if not is_inside_tree():
		return
	var color := Color("6678c8") if night_threat else (Color("69be9b") if ally else Color("c9805a"))
	CombatFX.burst(self, global_position, color)

func set_ally() -> void:
	ally = true
	_restore_day_look() # inimigo noturno domesticado volta a ter cara de aliado
	if has_node("Collar"):
		$Collar.show()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("69be9b")
	material.roughness = .85
	$Crest.material_override = material
	flash_time = .6
	# Conclusao da domesticacao: dois aneis jade e lascas claras.
	if is_inside_tree():
		CombatFX.ring(self, global_position, JADE, 2.6, 0.7)
		CombatFX.ring(self, global_position, JADE_LIGHT, 1.6, 0.45)
		CombatFX.hit_spark(self, global_position + Vector3(0, 1.2, 0), JADE_LIGHT, 8)

# --- Indicadores no corpo -------------------------------------------------------
# Anel jade sob um selvagem que JA pode ser domesticado (vida <= 30%): discreto,
# pulsando. Durante a canalizacao um segundo anel cresce com o progresso.
# Aliado em FICAR: losango jade sobre a cabeca.
func _update_indicators(body: Node3D, delta: float) -> void:
	var eligible: bool = body.can_be_domesticated()
	if eligible and _tame_ring == null:
		_tame_mat = CombatFX.fx_material(JADE, 0.6)
		_fill_mat = CombatFX.fx_material(JADE_LIGHT, 0.85)
		_tame_ring = _indicator(body, CombatFX.ring_mesh(), _tame_mat, "TameRing")
		_tame_fill = _indicator(body, CombatFX.ring_mesh(), _fill_mat, "TameFill")
	if _tame_ring != null:
		_tame_ring.visible = eligible
		var progress := 0.0
		if eligible:
			var player := get_tree().get_first_node_in_group("player")
			var channel := player.get_node_or_null("DomesticationChannel") if player != null else null
			if channel != null and channel.get("_target") == body:
				progress = channel.get_progress()
			_tame_mat.albedo_color.a = 0.35 + 0.25 * (0.5 + 0.5 * sin(clock * 5.0))
			_tame_ring.scale = Vector3.ONE * 1.15
		_tame_fill.visible = eligible and progress > 0.0
		_tame_fill.scale = Vector3.ONE * maxf(0.05, 1.15 * progress)
	var staying: bool = body.get("is_domesticated") and body.get("ally_state") == 1 # AllyState.STAYING
	if staying and _stay_pin == null:
		var pin_mat := CombatFX.fx_material(JADE_LIGHT, 0.95)
		_stay_pin = _indicator(body, CombatFX.shard_mesh(), pin_mat, "StayPin")
		_stay_pin.scale = Vector3(2.8, 3.4, 2.8)
	if _stay_pin != null:
		_stay_pin.visible = staying
		_stay_pin.position = Vector3(0, 2.75 + 0.08 * sin(clock * 3.0), 0)
		_stay_pin.rotation.y += delta * 1.5

func _indicator(body: Node3D, mesh: Mesh, mat: Material, label: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = label
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.05, 0)
	body.add_child(mi)
	return mi

# --- Inimigo da onda noturna ---------------------------------------------------
# Paleta "ameaca noturna" da direcao Vale de Jade. Marcada pelo WaveManager no
# spawn (tipo de criatura, nao horario): selvagem diurno, guardiao e aliado nunca
# passam por aqui. So troca material_override desta instancia; os materiais do
# modelo (compartilhados por todas as criaturas) nao sao alterados.
const NIGHT_MAIN := Color("18244d")
const NIGHT_SHADOW := Color("25214f")
const NIGHT_PURPLE := Color("332452")
const NIGHT_ACCENT := Color("6678c8")
# A paleta e o tom DESEJADO NA TELA a noite (21:00). O luar azul da Spec 014 pesa
# muito por canal: medido, albedo #18244d sai #081560 (ganho ~0,26 / 0,43 / 1,58
# em R/G/B, luz linear). O albedo e derivado da paleta por esse ganho, senao a
# criatura vira azul eletrico em vez de azul-escuro arroxeado.
const NIGHT_LIGHT_GAIN := Vector3(0.26, 0.43, 1.58)

static func night_albedo(target: Color) -> Color:
	var lin := target.srgb_to_linear()
	return Color(minf(lin.r / NIGHT_LIGHT_GAIN.x, 1.0), minf(lin.g / NIGHT_LIGHT_GAIN.y, 1.0), minf(lin.b / NIGHT_LIGHT_GAIN.z, 1.0)).linear_to_srgb()

## Papel de cada parte do modelo (prefixo do nome). O resto usa o corpo.
const NIGHT_ROLES := {
	"Belly": "purple", "Crest": "accent", "Claw": "accent", "Jaw": "accent",
	"Eye": "eye", "Pupil": "shadow", "Foot": "shadow", "Collar": "shadow",
}
# Materiais da paleta noturna: proprios desta criatura (um por papel), criados
# no spawn; nada fica guardado entre partidas.
var _night_mats := {}

func _night_material(role: String) -> StandardMaterial3D:
	if _night_mats.has(role):
		return _night_mats[role]
	var m := StandardMaterial3D.new()
	m.resource_name = "night_" + role
	m.roughness = 0.9
	var target := NIGHT_MAIN
	match role:
		"purple": target = NIGHT_PURPLE
		"shadow": target = NIGHT_SHADOW
		"accent", "eye": target = NIGHT_ACCENT
	m.set_meta("palette", target)
	m.albedo_color = night_albedo(target)
	match role:
		"eye":
			# Olhos: unico ponto com brilho, fraco (nada de neon). Emissao nao
			# depende da luz: usa a cor da paleta direto.
			m.emission_enabled = true
			m.emission = NIGHT_ACCENT
			m.emission_energy_multiplier = 0.8
	if role != "eye":
		# Borda de luz violeta: separa a silhueta escura do chao a noite.
		m.rim_enabled = true
		m.rim = 0.3
		m.rim_tint = 0.3
	_night_mats[role] = m
	return m

func set_night_threat() -> void:
	if night_threat or ally:
		return
	night_threat = true
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		_day_materials[mi] = mi.material_override
		var role := "main"
		for prefix in NIGHT_ROLES:
			if String(mi.name).begins_with(prefix):
				role = NIGHT_ROLES[prefix]
				break
		mi.material_override = _night_material(role)

func _restore_day_look() -> void:
	if not night_threat:
		return
	night_threat = false
	for mi in _day_materials:
		if is_instance_valid(mi):
			mi.material_override = _day_materials[mi]
	_day_materials.clear()
