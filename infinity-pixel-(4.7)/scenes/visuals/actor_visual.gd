extends Node3D

var clock := 0.0
var swing := 0.0
var flash_time := 0.0
var ally := false
## Inimigo da onda noturna (Spec 019 antecipada): paleta azul-violeta propria.
var night_threat := false
var _day_materials := {} # malha -> material original (para voltar ao domesticar)

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
	rotation.x = -sin(swing * PI / .32) * .2
	if has_node("ArmR"):
		$ArmR.rotation.x = -sin(swing * PI / .32) * 1.6
	if has_node("Tail"):
		$Tail.rotation.y = sin(clock * 3) * .13
	flash_time = maxf(0, flash_time - delta)
	scale = Vector3.ONE * (1.0 + sin(flash_time * 28) * .045)

func strike() -> void:
	swing = .32

func flash() -> void:
	flash_time = .22

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
