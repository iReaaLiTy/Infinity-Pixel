extends Node3D

# Spec: docs/specs/013b-economia-defesas-fixas.md
# RF-ECO-003 — Ponto fixo de defesa (PROVISORIO)
#
# Plataforma baixa de pedra com marco de cristal. Vazio: so visual (sem
# colisao, nao bloqueia nada). Construido: recebe uma DefenseTower como filha.

const DefenseTower := preload("res://scenes/world/defense_tower.gd")
const RangeRing := preload("res://scenes/world/range_ring.gd")
const Palette := preload("res://scenes/visuals/palette.gd")
const Facets := preload("res://scenes/visuals/facets.gd")

## Rota que o ponto cobre (so informativo: "Oeste", "Ruina", "Leste").
@export var route := ""
## Spec 017A (prototipo): "jade" = visual novo facetado/toon; "" = visual atual.
@export var style := ""

var tower: StaticBody3D
var _marker: Node3D
var preview_ring: MeshInstance3D # RF-CMB-007: raio = DefenseTower.LEVELS[0].range
var _glow: Array[MeshInstance3D] = [] # so no estilo jade (meta "glow" = dia, noite)

func _ready() -> void:
	add_to_group("defense_slot")
	if style == "jade":
		_jade_base()
	else:
		_classic_base()
	preview_ring = RangeRing.new()
	preview_ring.name = "PreviewRing"
	add_child(preview_ring)
	preview_ring.set_radius(DefenseTower.LEVELS[0].range)
	_marker = Node3D.new()
	add_child(_marker)
	if style == "jade":
		_marker.add_child(_jade_gem())
		add_to_group("night_glow") # Spec 014: DayNightVisual chama set_night_glow()
		set_night_glow(0.0)
		return
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

func _classic_base() -> void:
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
	if has_node("Inlay") or style == "jade":
		return # jade: o encaixe faz parte de _jade_base()
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

# --- Spec 017A: estilo "jade" (prototipo facetado/toon) ----------------------
# Mesma altura do visual atual (topo a 0,2 m, onde a torre se apoia) e o mesmo
# papel: base de pedra, encaixe jade no centro e cristal girando quando livre.
func _jade_base() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13 # mesmo desenho sempre
	var tones := [Palette.STONE_LIGHT, Palette.STONE, Palette.STONE_DARK]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint := func(c: Vector3, n: Vector3) -> Color:
		if n.y > 0.8:
			return Facets.by_height(tones, n, 1.0, 0.0, 1.0, c.x + c.z) # lajes do topo claras
		return Facets.by_height(tones, n, c.y, -0.02, 0.2, c.x)
	Facets.loft(st, [
		Facets.ring(8, 1.24, -0.02, rng, 0.02, PI / 8.0),
		Facets.ring(8, 1.2, 0.11, rng, 0.03, PI / 8.0, 0.01),
		Facets.ring(8, 1.06, 0.18, rng, 0.03, PI / 8.0, 0.01),
		Facets.ring(8, 0.98, 0.2, rng, 0.02, PI / 8.0),
	], true, null, paint)
	# Pedras rentes na borda (no maximo 0,15 m: chao andavel, sem colisao).
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var p := Vector3(sin(a) * 1.3, 0, cos(a) * 1.3)
		var s := rng.randf_range(0.13, 0.17)
		var rock := []
		for spec in [[-0.02, 1.0], [0.08, 0.8]]:
			var ring := Facets.ring(5, s * spec[1], spec[0], rng, 0.2, rng.randf() * TAU)
			for k in ring.size():
				ring[k] += p
			rock.append(ring)
		Facets.loft(st, rock, p + Vector3(0, 0.14, 0), null, paint)
	var base := Facets.instance("JadeBase", st.commit(), Palette.toon(0.3, 0.12))
	add_child(base)
	# Encaixe jade: losango central + 4 cunhas nas bordas, rentes ao topo.
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint_jade := func(_c: Vector3, n: Vector3) -> Color:
		return Palette.JADE if n.y > 0.8 else Palette.JADE_DARK
	var diamond := func(y: float, s: float, at: Vector3, turn: float) -> PackedVector3Array:
		var b := Basis(Vector3.UP, turn)
		return PackedVector3Array([at + b * Vector3(s, y, 0), at + b * Vector3(0, y, s * 0.62), at + b * Vector3(-s, y, 0), at + b * Vector3(0, y, -s * 0.62)])
	Facets.loft(st, [diamond.call(0.19, 0.5, Vector3.ZERO, PI / 4.0), diamond.call(0.225, 0.44, Vector3.ZERO, PI / 4.0)], true, null, paint_jade)
	for i in 4:
		var a := TAU * i / 4.0
		var at := Vector3(cos(a) * 0.86, 0, sin(a) * 0.86)
		Facets.loft(st, [diamond.call(0.17, 0.16, at, -a), diamond.call(0.215, 0.12, at, -a)], true, null, paint_jade)
	var inlay := Facets.instance("Inlay", st.commit(), Palette.toon_glow(Palette.CRYSTAL_GLOW, 0.3, 0.0), Vector3.ZERO, false)
	inlay.set_meta("glow", Vector2(0.4, 1.0))
	add_child(inlay)
	_glow.append(inlay)

func _jade_gem() -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint := func(c: Vector3, n: Vector3) -> Color:
		var col := Palette.JADE_DARK.lerp(Palette.JADE_LIGHT, clampf((c.y - 0.27) / 0.5, 0.0, 1.0))
		return col.lightened(0.1) if fposmod(atan2(n.z, n.x) / TAU * 6.0, 2.0) < 1.0 else col.darkened(0.08)
	Facets.loft(st, [
		Facets.ring(6, 0.05, 0.27, rng, 0.0),
		Facets.ring(6, 0.15, 0.42, rng, 0.05, 0.1),
		Facets.ring(6, 0.13, 0.6, rng, 0.05, 0.2),
	], Vector3(0, 0.8, 0), null, paint)
	var gem := Facets.instance("Gem", st.commit(), Palette.toon_glow(Palette.CRYSTAL_GLOW, 0.18, 0.4))
	gem.set_meta("glow", Vector2(0.25, 1.1))
	_glow.append(gem)
	return gem

func set_night_glow(f: float) -> void:
	for mi in _glow:
		var energy: Vector2 = mi.get_meta("glow")
		(mi.material_override as StandardMaterial3D).emission_energy_multiplier = lerpf(energy.x, energy.y, f)
