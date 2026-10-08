extends Node3D

# Spec: docs/specs/013b-economia-defesas-fixas.md
# RF-ECO-003 — Ponto fixo de defesa (PROVISORIO)
#
# Plataforma baixa de pedra com marco de cristal. Vazio: so visual (sem
# colisao, nao bloqueia nada). Construido: recebe uma DefenseTower como filha.

const DefenseTower := preload("res://scenes/world/defense_tower.gd")
const RangeRing := preload("res://scenes/world/range_ring.gd")

## Rota que o ponto cobre (so informativo: "Oeste", "Ruina", "Leste").
@export var route := ""

var tower: StaticBody3D
var _marker: Node3D
var preview_ring: MeshInstance3D # RF-CMB-007: raio = DefenseTower.LEVELS[0].range

func _ready() -> void:
	add_to_group("defense_slot")
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("8d9a8f")
	stone.roughness = 1.0
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("4f5e55")
	dark.roughness = 1.0
	_disc(1.15, 1.25, 0.14, Vector3(0, 0.07, 0), dark)
	_disc(0.95, 1.05, 0.1, Vector3(0, 0.17, 0), stone)
	# Pedrinhas na borda + cristal pequeno: "aqui da para construir".
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var pebble := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.16
		s.height = 0.22
		s.radial_segments = 6
		s.rings = 3
		pebble.mesh = s
		pebble.material_override = stone
		pebble.position = Vector3(sin(a) * 1.18, 0.12, cos(a) * 1.18)
		add_child(pebble)
	preview_ring = RangeRing.new()
	preview_ring.name = "PreviewRing"
	add_child(preview_ring)
	preview_ring.set_radius(DefenseTower.LEVELS[0].range)
	_marker = Node3D.new()
	add_child(_marker)
	var gem := PrismMesh.new()
	gem.size = Vector3(0.3, 0.46, 0.3)
	var crystal := MeshInstance3D.new()
	crystal.mesh = gem
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("7fd8b0")
	glow.emission_enabled = true
	glow.emission = Color("7fd8b0")
	glow.emission_energy_multiplier = 0.6
	crystal.material_override = glow
	crystal.position.y = 0.48
	_marker.add_child(crystal)

func _disc(top: float, bottom: float, height: float, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = 9
	c.rings = 1
	mi.mesh = c
	mi.position = pos
	mi.material_override = mat
	add_child(mi)

func is_empty() -> bool:
	return not is_instance_valid(tower)

func _process(delta: float) -> void:
	if is_empty():
		_marker.rotation.y += delta * 0.8 # cristal girando devagar = ponto livre
	# RF-CMB-007: previa do alcance da futura torre L1 (mesmo valor da tabela)
	# so quando o Player esta considerando construir AQUI.
	var focused: bool = is_empty() and get_parent() != null and get_parent().has_method("nearest_slot") \
		and get_parent().nearest_slot() == self
	preview_ring.set_strength(0.6 if focused else 0.0, delta)

# Chamado pelo DefenseSlots, que ja validou dia/pontos.
func build() -> StaticBody3D:
	if not is_empty():
		return null
	tower = DefenseTower.new()
	tower.name = "DefenseTower"
	add_child(tower)
	tower.position.y = 0.2
	_marker.hide()
	print("[DEFESA] Torre construida em %s (rota %s)" % [name, route])
	return tower

# Spec 013C (RF-CMB-008): marca no chao (losango verde-agua) — identifica o ponto
# sem texto. Fica sob a torre quando ela e construida.
func _enter_tree() -> void:
	if has_node("Inlay"):
		return
	var inlay := MeshInstance3D.new()
	inlay.name = "Inlay"
	var box := BoxMesh.new()
	box.size = Vector3(0.95, 0.02, 0.95)
	inlay.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("5fbf98")
	mat.emission_enabled = true
	mat.emission = Color("5fbf98")
	mat.emission_energy_multiplier = 0.35
	inlay.material_override = mat
	inlay.position.y = 0.23
	inlay.rotation.y = PI / 4.0
	add_child(inlay)
	var core := MeshInstance3D.new()
	var inner := BoxMesh.new()
	inner.size = Vector3(0.62, 0.025, 0.62)
	core.mesh = inner
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("8d9a8f")
	core.material_override = stone
	core.position.y = 0.235
	core.rotation.y = PI / 4.0
	add_child(core)
