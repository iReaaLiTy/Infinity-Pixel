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
	if has_node("Cape"):
		_cape = $Cape # 3.0: a capa ja vem no modelo do explorador
		_build_heading()
	elif has_node("Scarf"):
		_build_cape() # modelo antigo do Player (cachecol sem capa)
	if has_node("Neck") and has_node("Head"):
		_setup_rig()

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

# ---------------------------------------------------------------------------
# Visual Overhaul 3.0 — "rig" dos dinossauros. O modelo e plano (todas as
# partes filhas diretas do Visual, nomes antigos preservados), entao cabeca,
# pescoco e mandibula sao posados por codigo: cada parte guarda a pose de
# repouso e recebe a rotacao do pescoco (pivo na base) e da cabeca (pivo no
# alto do pescoco). So apresentacao: o corpo fisico, o rumo e o instante do
# golpe nao mudam.
# ---------------------------------------------------------------------------
const NECK_PIVOT := Vector3(0, 1.15, -0.38)
const HEAD_PIVOT := Vector3(0, 1.62, -0.66)
const HEAD_PARTS := ["Head", "Muzzle", "Jaw", "Teeth", "Eye", "Pupil", "Crest", "Horn", "Guard"]
const NECK_PARTS := ["Neck", "Collar", "Totem"]
var _rig := false
var _rest := {} # parte -> Transform3D de repouso
var _head_nodes: Array[Node3D] = []
var _neck_nodes: Array[Node3D] = []
var _eyes: Array[Node3D] = []
var _jaw: Node3D
var _jaw_rest: Transform3D
var _seed := 0.0
var _blink := 0.0
var _next_blink := 2.0
var _joy := 0.0 # salto curto ao ser domesticado
## Pose de vitrine (menu): "rest" = cheira o chao e olha em volta, devagar.
var showcase := ""
# 4.0: marcha pela distancia, joelho/tornozelo, cauda em dois segmentos.
var _gait := 0.0
var _pace_smooth := 0.0
var _tail_phase := 0.0
var _last_yaw := 0.0
var _lean := 0.0

## Passada (m por ciclo completo): o pe avanca o mesmo que o corpo anda.
func _stride(amp: float) -> float:
	return 4.0 * 0.95 * sin(amp) if _rig else 2.4

## Perna em balanco: o joelho dobra (levanta o pe) e o tornozelo compensa.
func _bend(knee: String, ankle: String, lift: float) -> void:
	var path := "Leg" + knee.right(1) + "/" + knee
	if not has_node(path):
		return
	var k := get_node(path) as Node3D
	k.rotation.x = -0.75 * lift
	(k.get_node(ankle) as Node3D).rotation.x = 0.6 * lift

func _setup_rig() -> void:
	_rig = true
	_seed = randf() * 50.0
	_next_blink = randf_range(1.5, 4.0)
	_head_nodes.clear()
	_neck_nodes.clear()
	_eyes.clear()
	for child in get_children():
		if child is Node3D:
			_register_part(child)

func _register_part(part: Node3D) -> void:
	var label := String(part.name)
	for prefix in HEAD_PARTS:
		if label.begins_with(prefix):
			_rest[part] = part.transform
			_head_nodes.append(part)
			if label.begins_with("Eye") or label.begins_with("Pupil"):
				_eyes.append(part)
			if label == "Jaw":
				_jaw = part
				_jaw_rest = part.transform
			return
	for prefix in NECK_PARTS:
		if label.begins_with(prefix):
			_rest[part] = part.transform
			_neck_nodes.append(part)
			return

static func _about(pivot: Vector3, basis: Basis) -> Transform3D:
	return Transform3D(Basis.IDENTITY, pivot) * Transform3D(basis, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot)

func _pose(neck_pitch: float, head_pitch: float, head_yaw: float, jaw_open: float, blink: float) -> void:
	var neck := _about(NECK_PIVOT, Basis.from_euler(Vector3(neck_pitch, head_yaw * 0.35, 0)))
	var head := neck * _about(HEAD_PIVOT, Basis.from_euler(Vector3(head_pitch, head_yaw * 0.65, -head_yaw * 0.12)))
	for part in _neck_nodes:
		if is_instance_valid(part):
			part.transform = neck * _rest[part]
	for part in _head_nodes:
		if is_instance_valid(part):
			part.transform = head * _rest[part]
	if is_instance_valid(_jaw):
		_jaw.transform = head * _jaw_rest * Transform3D(Basis(Vector3.RIGHT, -jaw_open), Vector3.ZERO)
	if blink > 0.0:
		for e in _eyes:
			if is_instance_valid(e):
				e.transform.basis = e.transform.basis * Basis.from_scale(Vector3(1, maxf(0.12, 1.0 - blink), 1))

func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	if body == null:
		if _rig and showcase != "":
			_showcase(delta) # menu: so a pose de vitrine
		return
	clock += delta
	var actual := body.get_real_velocity()
	var speed := Vector2(actual.x, actual.z).length()
	var pace := minf(speed / 4.0, 1.0)
	if pace < .025: pace = 0.0
	# 4.0: o passo segue a DISTANCIA andada (fase += velocidade / passada), nao
	# o relogio: o pe nao desliza no chao e a cadencia acompanha a velocidade.
	# Pernas so se movem com deslocamento real (parado = pose de repouso).
	_pace_smooth = lerpf(_pace_smooth, pace, 1.0 - exp(-delta * 10.0))
	var amp := (0.42 + 0.12 * clampf((speed - 2.0) / 3.0, 0.0, 1.0)) if _rig else 0.6
	_gait = fposmod(_gait + speed * delta / (_stride(amp)) * TAU, TAU)
	var lift_l := maxf(0.0, cos(_gait)) * pace # perna em balanco (indo a frente)
	var lift_r := maxf(0.0, -cos(_gait)) * pace
	$LegL.rotation.x = sin(_gait) * amp * pace
	$LegR.rotation.x = -sin(_gait) * amp * pace
	_bend("KneeL", "AnkleL", lift_l)
	_bend("KneeR", "AnkleR", lift_r)
	swing = maxf(0, swing - delta)
	_joy = maxf(0.0, _joy - delta)
	# Corpo mais alto no meio do apoio (perna vertical), duas vezes por ciclo.
	position.y = (0.5 + 0.5 * cos(2.0 * _gait)) * (.035 if _rig else .04) * pace + sin(minf(_joy / 0.7, 1.0) * PI) * 0.35 * float(_joy > 0.0)
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
	var lunge := sin(swing * PI / .32) if swing > 0.0 else 0.0
	var hurt := sin(flash_time / .22 * PI) * float(flash_time > 0.0 and flash_time <= .22)
	rotation.x = -lunge * (.1 if _rig else .2) + hurt * .1 + 0.16 * wind
	# Braços acompanham a passada (o direito so quando nao esta golpeando).
	if has_node("ArmL"):
		$ArmL.rotation.x = -sin(_gait) * 0.55 * pace
	if has_node("ArmR"):
		# 4.0: golpe rapido (o braco ja sai no instante do clique), segura e volta
		# suave — antes era um seno simetrico que "voltava" tao rapido quanto ia.
		var t := 1.0 - swing / .32
		$ArmR.rotation.x = -1.8 * smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.45, 1.0, t)) if swing > 0.0 else sin(_gait) * 0.55 * pace
	# Leve inclinacao a frente correndo; capa balanca com o passo.
	rotation.x -= 0.07 * pace
	if is_instance_valid(_cape):
		# negativo = a barra sobe para tras (antes o sinal levava a capa para dentro do corpo)
		_cape.rotation.x = -(0.05 + 0.5 * pace + sin(clock * 7.0) * 0.06 * (0.3 + pace))
	if has_node("Tail"):
		# 4.0: fase acumulada (sem salto quando a velocidade muda) e a ponta
		# atrasada em relacao a base: a cauda ondula como chicote.
		_tail_phase += delta * (3.0 + 4.0 * _pace_smooth)
		var tail_amp := .13 + .07 * (1.0 - _pace_smooth)
		$Tail.rotation.y = sin(_tail_phase) * tail_amp
		$Tail.rotation.x = -0.06 * _pace_smooth + 0.05 * sin(clock * 2.3) * (1.0 - _pace_smooth)
		if has_node("Tail/TailTip"):
			$Tail/TailTip.rotation.y = sin(_tail_phase - 0.9) * tail_amp * 1.5
			$Tail/TailTip.rotation.x = 0.04 * sin(clock * 2.3 - 0.8) * (1.0 - _pace_smooth) - 0.05 * _pace_smooth
	# 4.0: inclina para dentro das curvas (pela virada real do corpo).
	var yaw := body.global_rotation.y
	var turn := wrapf(yaw - _last_yaw, -PI, PI) / maxf(delta, 0.001)
	_last_yaw = yaw
	_lean = lerpf(_lean, clampf(-turn * 0.035, -0.1, 0.1) * _pace_smooth, 1.0 - exp(-delta * 6.0))
	rotation.z = _lean + hurt * 0.06 * (1.0 if int(_seed) % 2 == 0 else -1.0) + (0.0 if _rig else 0.035 * sin(_gait) * pace)
	flash_time = maxf(0, flash_time - delta)
	# Respiracao em repouso: o peito sobe e desce devagar (some ao andar).
	var breathe := sin(clock * 2.3) * 0.022 * (1.0 - pace)
	var pulse := sin(flash_time * 28) * .045
	scale = Vector3(1.0 + pulse, 1.0 + pulse + breathe, 1.0 + pulse)
	if _rig:
		_animate_head(delta, pace, wind, lunge, hurt)
	if _flashing and flash_time <= 0.0:
		_set_overlay(null)
	elif _flashing:
		_flash_mat.albedo_color.a = 0.3 * minf(flash_time / .22, 1.0)
	if body.has_method("can_be_domesticated"):
		_update_indicators(body, delta)

## Cabeca viva: olha em volta parado, balanca ao correr, ergue a cabeca e abre
## a boca na preparacao, da o bote no golpe, encolhe ao apanhar, pisca.
func _animate_head(delta: float, pace: float, wind: float, lunge: float, hurt: float) -> void:
	var calm := 1.0 - pace
	var t := clock + _seed
	var yaw := (sin(t * 0.53) * 0.6 + sin(t * 0.21 + 1.3) * 0.4) * 0.38 * calm * (1.0 - wind)
	var head_pitch := sin(t * 0.37) * 0.07 * calm + sin(clock * 22.0) * 0.05 * pace
	var neck_pitch := -0.16 * pace
	head_pitch += 0.32 * wind + 0.25 * hurt + 0.35 * sin(minf(_joy / 0.7, 1.0) * PI)
	neck_pitch += 0.14 * wind - 0.42 * lunge
	var jaw := 0.42 * wind + 0.5 * clampf((swing - 0.14) / 0.18, 0.0, 1.0) + 0.15 * hurt
	_pose(neck_pitch, head_pitch, yaw, jaw, _blink_amount(delta))

func _blink_amount(delta: float) -> float:
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.14
		_next_blink = randf_range(2.5, 5.0)
	_blink = maxf(0.0, _blink - delta)
	return sin(_blink / 0.14 * PI) if _blink > 0.0 else 0.0

## Vitrine (menu): respira, balanca a cauda, cheira o chao e levanta a cabeca.
func _showcase(delta: float) -> void:
	clock += delta
	var t := clock + _seed
	var sniff := smoothstep(0.55, 0.85, 0.5 + 0.5 * sin(t * 0.33)) if showcase == "rest" else 0.0
	scale = Vector3(1.0, 1.0 + sin(clock * 2.0) * 0.02, 1.0)
	if has_node("Tail"):
		$Tail.rotation.y = sin(clock * 1.7) * 0.16
		$Tail.rotation.x = 0.05 * sin(clock * 1.1)
		if has_node("Tail/TailTip"):
			$Tail/TailTip.rotation.y = sin(clock * 1.7 - 0.9) * 0.24
	var yaw := (sin(t * 0.41) * 0.6 + sin(t * 0.17) * 0.4) * 0.45 * (1.0 - sniff)
	_pose(-0.3 * sniff, -0.5 * sniff + sin(t * 0.29) * 0.06, yaw, 0.12 * sniff * (0.5 + 0.5 * sin(t * 6.0)), _blink_amount(delta))

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
	_leave_remains()

## 3.0: o corpo some no mesmo quadro (regra do jogo); fica uma copia so visual
## que tomba de lado e afunda no chao em ~1,3 s. Sem script, sem fisica.
func _leave_remains() -> void:
	var host := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	var body := get_parent() as Node3D
	if body != null and body.get_parent() != null:
		host = body.get_parent()
	var copy := duplicate(0) as Node3D
	copy.set_script(null)
	for mi: MeshInstance3D in copy.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.material_overlay = null
	for n in copy.get_children():
		if not (n is MeshInstance3D or n.name.begins_with("Leg")):
			copy.remove_child(n)
			n.free()
	host.add_child(copy)
	copy.global_transform = global_transform
	var side := 1.0 if randf() < 0.5 else -1.0
	var t := copy.create_tween().set_trans(Tween.TRANS_QUAD)
	t.tween_property(copy, "rotation:z", side * 1.35, 0.35).set_ease(Tween.EASE_IN)
	t.tween_interval(0.4)
	t.tween_property(copy, "position:y", copy.position.y - 1.4, 0.55).set_ease(Tween.EASE_IN)
	t.tween_callback(copy.queue_free)

func set_ally() -> void:
	# 3.0: a mochila mostra de onde veio o aliado (dado real, lido antes de a
	# paleta e o rotulo de guardiao serem trocados).
	var body := get_parent()
	if body != null:
		var origin := "Selvagem do vale"
		if night_threat:
			origin = "Ex-invasor da noite"
		elif String(body.get("guardian_of") if body.get("guardian_of") != null else "") != "":
			origin = "Ex-guardião · %s" % body.guardian_of
		body.set_meta("ally_origin", origin)
	ally = true
	_restore_day_look() # inimigo noturno domesticado volta a ter cara de aliado
	if has_node("Collar"):
		$Collar.show()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("69be9b")
	material.roughness = .85
	$Crest.material_override = material
	flash_time = .6
	_joy = 0.7 # pulinho e cabecada para cima (so visual)
	_remove_parts("Guard")
	_remove_parts("Totem")
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
	"Teeth": "accent", "Spine": "accent", "Horn": "accent",
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
	_add_spines() # 3.0: silhueta propria (espinhos), alem da paleta
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
	_remove_parts("Spine")

# --- Ornamentos por faccao (Visual Overhaul 3.0) --------------------------------
# A cor nao e a unica leitura: o invasor ganha espinhos; o guardiao, mascara de
# osso e colar de contas com a pedra-runa do territorio; o aliado, coleira e
# crista jade. Malhas em cache (creature_forge.gd); material na superficie da
# malha, nunca no material_override (a regra dos materiais do modelo continua).
const Forge := preload("res://scenes/visuals/creature_forge.gd")

func _ornament(label: String, mesh: Mesh, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = label
	mi.mesh = mesh
	(parent if parent != null else self).add_child(mi)
	if _rig and parent == null:
		_register_part(mi)
	return mi

func _remove_parts(prefix: String) -> void:
	for mi: MeshInstance3D in find_children(prefix + "*", "MeshInstance3D", true, false):
		_head_nodes.erase(mi)
		_neck_nodes.erase(mi)
		_rest.erase(mi)
		mi.get_parent().remove_child(mi)
		mi.queue_free()

func _add_spines() -> void:
	if not _rig or has_node("SpineBack"):
		return
	_ornament("SpineBack", Forge.spine_back_mesh())
	if has_node("Tail"):
		_ornament("SpineTail", Forge.spine_tail_mesh(), $Tail)

## Guardiao territorial: liga/desliga mascara e colar (so visual).
func set_guardian_look(on: bool) -> void:
	if not _rig:
		return
	_remove_parts("Guard")
	_remove_parts("Totem")
	if on and not ally:
		_ornament("GuardMask", Forge.guard_mask_mesh())
		_ornament("TotemBeads", Forge.totem_beads_mesh())

## 3.0: feedback de direcao do Player — chevron jade rente ao chao, a frente do
## modelo (gira com ele). So leitura: a mira e o golpe nao mudam.
var _heading: MeshInstance3D
func _build_heading() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector3(0, 0, -0.34), Vector3(0.26, 0, 0.0), Vector3(0.13, 0, 0.0), Vector3(0, 0, -0.17), Vector3(-0.13, 0, 0.0), Vector3(-0.26, 0, 0.0)]
	for tri in [[0, 2, 1], [0, 3, 2], [0, 5, 4], [0, 4, 3]]:
		for k in tri:
			st.set_normal(Vector3.UP)
			st.add_vertex(pts[k])
	_heading = MeshInstance3D.new()
	_heading.name = "HeadingMark"
	_heading.mesh = st.commit()
	_heading.material_override = CombatFX.fx_material(Color("a8e6cf"), 0.5)
	_heading.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_heading.position = Vector3(0, 0.05, -0.85)
	add_child(_heading)
