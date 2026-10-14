extends SceneTree

# Visual Overhaul 4.0 — gera scenes/visuals/flora_art.scn: arvores, rochas e
# sub-bosque do vale (scenes/visuals/flora.gd), desenhados nos MESMOS lugares
# dos nos antigos de arena_art.tscn (Trunk*, Rock*: os solidos e a navmesh
# vem deles e nao mudam). Os nos antigos ficam ocultos (build_first_map.gd).
#
# Desempenho (Iris Xe, GL Compatibility): eram 226 MeshInstance3D (42 troncos,
# 84 copas, 16 rochas, 84 "samambaias" conicas), cada um desenhado no passe
# visivel e em ate 4 fatias de sombra. Agora: blocos 3 x 3 com uma malha que
# projeta sombra (arvores e rochas) e outra rente sem sombra (sub-bosque).
#
# Regras (conferidas em tests/visual_overhaul4.gd):
#  - na area andavel, vertice entre 0,3 m e 1,9 m so sobre um solido (tronco,
#    rocha); copas acima de 1,9 m; sub-bosque rente (<= 0,3 m);
#  - nada em trilhas, patio, area de construcao, pontos de defesa, marcos,
#    entradas das ondas, coletaveis e sitios fosseis;
#  - fora da area andavel (entre o Boundary e o paredao) pode ser alto.
# Pipeline: tools/build_first_map.gd chama generate() depois de valley_art.
# Sozinho: godot --headless --script res://tools/build_flora_art.gd

const Flora := preload("res://scenes/visuals/flora.gd")
const Palette := preload("res://scenes/visuals/palette.gd")
const Facets := preload("res://scenes/visuals/facets.gd")
const Layout := preload("res://tools/valley_layout.gd")
const Valley := preload("res://tools/build_valley_art.gd")
const OUT := "res://scenes/visuals/flora_art.scn" # binario: menor e carrega mais rapido
const ART := "res://scenes/visuals/arena_art.tscn"
const WORLD := "res://scenes/world/prototype_area.tscn"
const AREA_MIN := Vector2(-31.0, -31.0)
const AREA_MAX := Vector2(31.0, 35.0)
const CHUNKS := Vector2i(3, 3)

static var _avoid: Array = [] # [ponto, raio]: coletaveis, sitios fosseis, rochas, troncos

func _initialize() -> void:
	generate()
	quit()

static func _chunk(p: Vector2) -> int:
	var size := (AREA_MAX - AREA_MIN) / Vector2(CHUNKS)
	var cx := clampi(int((p.x - AREA_MIN.x) / size.x), 0, CHUNKS.x - 1)
	var cz := clampi(int((p.y - AREA_MIN.y) / size.y), 0, CHUNKS.y - 1)
	return cz * CHUNKS.x + cx

static func walkable(p: Vector2) -> bool:
	return absf(p.x) < Layout.BOUND_X and p.y > Layout.BOUND_SOUTH and p.y < Layout.BOUND_NORTH

## Floresta Oeste: a mancha do bosque e a faixa oeste do vale (0..1).
static func west_wood(p: Vector2) -> float:
	var patch := 1.0 - smoothstep(0.7, 1.15, Layout.patch_distance(p, Layout.WOODLAND))
	return maxf(patch, smoothstep(-13.0, -19.0, p.x) * float(p.y > -10.0))

static func heath(p: Vector2) -> float:
	return 1.0 - smoothstep(0.75, 1.1, Layout.patch_distance(p, Layout.HEATH))

## Especie por lugar: jade emoldura o Refugio; coniferas, araucarias e
## samambaias-arborescentes fecham a Floresta Oeste; araucarias pontuam a
## Regiao Rochosa; copas largas na campina.
static func tree_kind(i: int, p: Vector2) -> int:
	if p.y < -8.0:
		return Flora.Kind.JADE if i % 2 == 0 else (Flora.Kind.ARAUCARIA if i % 3 == 0 else Flora.Kind.BROADLEAF)
	if p.x < -6.0:
		return [Flora.Kind.CONIFER, Flora.Kind.TREE_FERN, Flora.Kind.ARAUCARIA, Flora.Kind.CONIFER, Flora.Kind.TREE_FERN][i % 5]
	if p.x > 6.0 and p.y > 4.0:
		return Flora.Kind.ARAUCARIA if i % 2 == 0 else Flora.Kind.BROADLEAF
	return Flora.Kind.BROADLEAF if i % 3 != 0 else Flora.Kind.JADE

static func _clear(p: Vector2, clearance: float, avoid_scale := 1.0) -> bool:
	if not Valley._free_spot(p, clearance):
		return false
	for a in _avoid:
		if p.distance_to(a[0]) < a[1] * avoid_scale:
			return false
	return true

static func generate() -> void:
	var art := (load(ART) as PackedScene).instantiate()
	var trees := []
	var rocks := []
	for node in art.get_children():
		var label := String(node.name)
		if label.begins_with("Trunk"):
			trees.append([int(label.trim_prefix("Trunk")), node.position, node.scale.y / 0.9])
		elif label.begins_with("Rock"):
			rocks.append([int(label.trim_prefix("Rock")), node.transform])
	art.free()
	trees.sort_custom(func(a, b): return a[0] < b[0])
	rocks.sort_custom(func(a, b): return a[0] < b[0])
	_avoid.clear()
	var world := (load(WORLD) as PackedScene).instantiate()
	for c: Node3D in world.get_node("Collectables").get_children():
		_avoid.append([Vector2(c.position.x, c.position.z), 1.9])
	world.free()
	var Fossils = load("res://scenes/visuals/fossil_art.gd")
	for p in Fossils.PLACES:
		_avoid.append([Vector2(p[1], p[2]), 1.4])
	for t in Fossils.TRAILS:
		for k in 5:
			_avoid.append([(t[0] as Vector2).lerp(t[1], k / 4.0), 0.9])
	for r in rocks:
		var xf: Transform3D = r[1]
		_avoid.append([Vector2(xf.origin.x, xf.origin.z), maxf(xf.basis.get_scale().x, xf.basis.get_scale().z) * 0.5 + 0.25])
	for t in trees:
		_avoid.append([Vector2(t[1].x, t[1].z), 0.75])

	var tall := []
	var low := []
	for k in CHUNKS.x * CHUNKS.y:
		for list in [tall, low]:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			list.append(st)
	var rng := RandomNumberGenerator.new()
	rng.seed = 40404
	# Cristais e glifos numa malha propria que brilha a noite (night_glow).
	var glow := SurfaceTool.new()
	glow.begin(Mesh.PRIMITIVE_TRIANGLES)
	var counts := {"ruins": 0, "outcrops": 0, "spires": 0, "trees": 0, "rocks": 0, "ferns": 0, "shrubs": 0, "logs": 0, "horsetails": 0, "cycads": 0, "crystals": 0, "moss": 0, "edge": 0}

	# --- Arvores (mesmos pes dos troncos antigos) ---
	for t in trees:
		var i: int = t[0]
		var pos: Vector3 = t[1]
		var p := Vector2(pos.x, pos.z)
		var kind := tree_kind(i, p)
		var base := Vector3(pos.x, 0.0, pos.z)
		Flora.tree(tall[_chunk(p)], kind, base, t[2], rng)
		if kind == Flora.Kind.JADE: # pontas de cristal no pe da arvore-jade (rentes)
			for k in 3:
				var a := TAU * k / 3.0 + float(i)
				Flora.crystal(glow, base + Vector3(cos(a) * 0.48, 0.0, sin(a) * 0.48), 0.07, 0.24, Vector3(cos(a), 2.6, sin(a)), rng)
		counts.trees += 1
		# pe da arvore: musgo e samambaias na mata; flores/arbusto na campina
		var wood := west_wood(p)
		if wood > 0.4 and walkable(p):
			Flora.moss_mat(low[_chunk(p)], base, rng.randf_range(0.75, 1.05), rng)
			counts.moss += 1
		for k in (3 if wood > 0.4 else 1):
			var a := rng.randf() * TAU
			var q := p + Vector2(cos(a), sin(a)) * rng.randf_range(0.85, 1.4)
			if walkable(q) and _clear(q, 0.45, 0.6):
				Flora.fern(low[_chunk(q)], Vector3(q.x, 0.0, q.y), rng.randf_range(0.34, 0.44), rng, Flora.vary(Flora.LEAVES[Flora.Kind.CONIFER] if wood > 0.4 else Flora.LEAVES[Flora.Kind.TREE_FERN], rng))
				counts.ferns += 1
		if wood > 0.5 and rng.randf() < 0.45:
			var a := rng.randf() * TAU
			Flora.mushrooms(low[_chunk(p)], base + Vector3(cos(a), 0, sin(a)) * 0.5, rng)

	# --- Rochas: tres familias, cobertura pela regiao ---
	for r in rocks:
		var xf: Transform3D = r[1]
		var p := Vector2(xf.origin.x, xf.origin.z)
		var family := Flora.Rock.BOULDER
		var tones: Array = Flora.ROCK_TONES.bare
		var cover := ""
		if heath(p) > 0.3 or (p.x > 6.0 and p.y > 4.0):
			family = [Flora.Rock.SLAB, Flora.Rock.SPIRE, Flora.Rock.BOULDER][r[0] % 3]
			tones = Flora.ROCK_TONES.heath
			cover = "lichen"
		elif west_wood(p) > 0.3 or p.x < -6.0:
			family = Flora.Rock.BOULDER if r[0] % 2 == 0 else Flora.Rock.SLAB
			tones = Flora.ROCK_TONES.wood
			cover = "moss"
		else:
			family = Flora.Rock.BOULDER if r[0] % 3 != 1 else Flora.Rock.SLAB
		# 8% mais baixa que o no antigo: o topo fica no solido (cilindro 0,9 x).
		var squash := Transform3D(Basis.from_scale(Vector3(0.98, 0.92, 0.98)), Vector3(0, -0.02, 0))
		Flora.rock(tall[_chunk(p)], xf * squash, family, rng, Flora.vary(tones, rng, 0.05), cover)
		counts.rocks += 1
		var s := xf.basis.get_scale()
		var reach := maxf(s.x, s.z) * 0.5
		# Base da rocha: musgo e samambaia na mata; cascalho, liquen e cristais
		# pequenos na Regiao Rochosa (o que da vontade de explorar).
		for k in 4:
			var a := rng.randf() * TAU
			var q := p + Vector2(cos(a), sin(a)) * (reach + rng.randf_range(0.1, 0.45))
			if not walkable(q) or not Valley._free_spot(q, 0.3):
				continue
			var c := Vector3(q.x, 0.0, q.y)
			if cover == "moss":
				if k == 0:
					Flora.moss_mat(low[_chunk(q)], c, rng.randf_range(0.5, 0.7), rng)
					counts.moss += 1
				else:
					Flora.fern(low[_chunk(q)], c, rng.randf_range(0.3, 0.4), rng, Flora.vary(Flora.LEAVES[Flora.Kind.CONIFER], rng))
					counts.ferns += 1
			elif cover == "lichen":
				for g in 4:
					var off := Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35))
					Flora.pebble(low[_chunk(q)], c + off, rng.randf_range(0.06, 0.13), rng, Flora.ROCK_TONES.heath)
				if k % 2 == 1:
					_crystal_cluster(glow, c, rng, 0.26)
					counts.crystals += 1
		# Rochedo grande da Regiao Rochosa: cristais no topo (sobre o solido).
		if cover == "lichen" and s.y >= 1.5:
			var top := xf * Vector3(0, 0.36, 0)
			_crystal_cluster(glow, Vector3(top.x, top.y, top.z), rng, 0.55, minf(s.x, s.z) * 0.18)
			counts.crystals += 1

	# --- Sub-bosque em grupos (areas densas e areas abertas) ---
	_undergrowth(low, glow, rng, counts)
	# --- Ruina do Arco, formacoes da Regiao Rochosa ---
	_ruins(tall, low, glow, rng, counts)
	_outcrops(tall, glow, rng, counts)
	# --- Borda do vale (fora da area andavel): mata alta junto ao paredao ---
	# World 6.0: sem a faixa de mata colada as paredes antigas (o vale agora se
	# abre para as quatro regioes; a BiomeArt faz as transicoes). _edge fica
	# disponivel, mas nao e mais chamado.

	var root := Node3D.new()
	root.name = "FloraArt"
	root.set_script(load("res://scenes/visuals/refuge_art.gd")) # brilho noturno por meta "glow"
	var mat := Palette.toon(0.3, 0.14)
	var low_mat := Palette.toon_double(0.32)
	for k in CHUNKS.x * CHUNKS.y:
		var mesh_tall: ArrayMesh = tall[k].commit()
		if mesh_tall.get_surface_count() > 0:
			root.add_child(Facets.instance("Trees%d" % k, mesh_tall, mat, Vector3.ZERO, true))
		var mesh_low: ArrayMesh = low[k].commit()
		if mesh_low.get_surface_count() > 0:
			root.add_child(Facets.instance("Under%d" % k, mesh_low, low_mat, Vector3.ZERO, false))
	var crystals := Facets.instance("Crystals", glow.commit(), Palette.toon_glow(Palette.CRYSTAL_GLOW, 0.22, 0.35), Vector3.ZERO, false)
	crystals.set_meta("glow", Vector2(0.25, 1.1)) # discretos de dia, acesos a noite
	root.add_child(crystals)
	for child in root.get_children():
		child.owner = root
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, OUT) == OK)
	root.free()
	print("[O4] flora_art.scn: %s" % JSON.stringify(counts))

static func _crystal_cluster(st: SurfaceTool, c: Vector3, rng: RandomNumberGenerator, height: float, spread := 0.12) -> void:
	for k in rng.randi_range(3, 4):
		var a := rng.randf() * TAU
		var off := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, spread)
		var h := height * rng.randf_range(0.55, 1.0)
		Flora.crystal(st, c + off, h * 0.22, h, Vector3(cos(a) * 0.45, 1.0, sin(a) * 0.45), rng)

static func _undergrowth(low: Array, glow: SurfaceTool, rng: RandomNumberGenerator, counts: Dictionary) -> void:
	var wood_tones := [Color("4f8a6e"), Color("37684f"), Color("244a3a")] # verde-azulado
	var meadow_tones := [Color("6aa765"), Color("4d8a55"), Color("336345")]
	var heath_tones := [Color("9aa36e"), Color("78845a"), Color("566146")]
	# Floresta Oeste: grupos densos de samambaias, arbustos e cavalinhas.
	var groups := 0
	for attempt in 600:
		if groups >= 46:
			break
		var p := Vector2(rng.randf_range(-24.0, -6.0), rng.randf_range(-6.0, 27.5))
		var wood := west_wood(p)
		if wood < 0.35 or rng.randf() > wood or not _clear(p, 0.7):
			continue
		groups += 1
		var n := rng.randi_range(3, 6)
		for k in n:
			var q := p + Vector2(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.9, 0.9))
			if not walkable(q) or not _clear(q, 0.4, 0.7):
				continue
			var c := Vector3(q.x, 0.0, q.y)
			var roll := rng.randf()
			if roll < 0.55:
				Flora.fern(low[_chunk(q)], c, rng.randf_range(0.34, 0.46), rng, Flora.vary(wood_tones, rng))
				counts.ferns += 1
			elif roll < 0.78:
				Flora.shrub(low[_chunk(q)], c, rng.randf_range(0.28, 0.42), rng.randf_range(0.2, 0.27), rng, Flora.vary(wood_tones, rng))
				counts.shrubs += 1
			else:
				Flora.horsetail(low[_chunk(q)], c, 0.27, rng, [Color("8fbf74"), Color("5f9a55"), Color("3e7044")], rng.randi_range(4, 7))
				counts.horsetails += 1
		if rng.randf() < 0.35:
			Flora.moss_mat(low[_chunk(p)], Vector3(p.x, 0.0, p.y), rng.randf_range(0.6, 1.0), rng, [Color("5f8f58"), Color("4a7a4c"), Color("355c3c")])
			counts.moss += 1
	# Troncos caidos antigos, com musgo (Floresta Oeste).
	var logs := 0
	for attempt in 80:
		if logs >= 8:
			break
		var p := Vector2(rng.randf_range(-23.0, -8.0), rng.randf_range(2.0, 27.0))
		if west_wood(p) < 0.4 or not _clear(p, 1.0):
			continue
		var yaw := rng.randf() * PI
		var length := rng.randf_range(1.3, 2.1)
		var dir := Vector2(cos(yaw), sin(yaw))
		if not (walkable(p + dir * length * 0.5) and walkable(p - dir * length * 0.5) and _clear(p + dir * length * 0.5, 0.6) and _clear(p - dir * length * 0.5, 0.6)):
			continue
		Flora.fallen_log(low[_chunk(p)], Vector3(p.x, 0.0, p.y), yaw, length, rng)
		if rng.randf() < 0.6:
			Flora.mushrooms(low[_chunk(p)], Vector3(p.x, 0.0, p.y) + Vector3(-dir.y, 0, dir.x) * 0.25, rng)
		logs += 1
	counts.logs = logs
	# Campina e bordas: arbustos e samambaias esparsos, em pares (areas abertas).
	for attempt in 260:
		var p := Vector2(rng.randf_range(-23.0, 23.0), rng.randf_range(-23.0, 27.0))
		if west_wood(p) > 0.3 or heath(p) > 0.4 or not _clear(p, 1.0):
			continue
		var edge := maxf(smoothstep(17.0, 23.0, absf(p.x)), smoothstep(-17.0, -23.0, p.y))
		if rng.randf() > 0.08 + 0.5 * edge:
			continue
		var c := Vector3(p.x, 0.0, p.y)
		if rng.randf() < 0.55:
			Flora.shrub(low[_chunk(p)], c, rng.randf_range(0.3, 0.45), rng.randf_range(0.18, 0.26), rng, Flora.vary(meadow_tones, rng))
			counts.shrubs += 1
		else:
			Flora.fern(low[_chunk(p)], c, rng.randf_range(0.32, 0.4), rng, Flora.vary(meadow_tones, rng))
			counts.ferns += 1
	# Regiao Rochosa: cicadaceas baixas e cristais rentes entre as pedras.
	for attempt in 200:
		var p := Vector2(rng.randf_range(4.0, 23.0), rng.randf_range(6.0, 27.5))
		if heath(p) < 0.5 or not _clear(p, 0.8):
			continue
		var c := Vector3(p.x, 0.0, p.y)
		var roll := rng.randf()
		if roll < 0.32:
			Flora.cycad(low[_chunk(p)], c, rng.randf_range(0.42, 0.5), rng)
			counts.cycads += 1
		elif roll < 0.44:
			_crystal_cluster(glow, c, rng, 0.24)
			counts.crystals += 1
		elif roll < 0.56:
			Flora.shrub(low[_chunk(p)], c, rng.randf_range(0.25, 0.35), rng.randf_range(0.15, 0.22), rng, Flora.vary(heath_tones, rng))
			counts.shrubs += 1

## Faixa entre o Boundary e o paredao: mata alta (cicadaceas, samambaias-
## arborescentes, cavalinhas) que fecha o vale sem cobrir as entradas.
static func _edge(tall: Array, low: Array, glow: SurfaceTool, rng: RandomNumberGenerator, counts: Dictionary) -> void:
	var bands := [
		[Vector2(-Layout.BOUND_X - 0.35, Layout.BOUND_SOUTH), Vector2(-Layout.BOUND_X - 0.35, Layout.BOUND_NORTH), Vector2(-1, 0)],
		[Vector2(Layout.BOUND_X + 0.35, Layout.BOUND_SOUTH), Vector2(Layout.BOUND_X + 0.35, Layout.BOUND_NORTH), Vector2(1, 0)],
		[Vector2(-Layout.BOUND_X, Layout.BOUND_NORTH + 0.35), Vector2(Layout.BOUND_X, Layout.BOUND_NORTH + 0.35), Vector2(0, 1)],
	]
	for band in bands:
		var a: Vector2 = band[0]
		var b: Vector2 = band[1]
		var out: Vector2 = band[2]
		var s := rng.randf_range(0.0, 1.0)
		var length := a.distance_to(b)
		while s < length:
			var p := a.lerp(b, s / length) + out * rng.randf_range(0.05, 0.9)
			s += rng.randf_range(1.1, 2.2)
			if _near_gap(p, 2.2):
				continue # entradas das ondas sempre abertas e legiveis
			var c := Vector3(p.x, 0.0, p.y)
			var roll := rng.randf()
			if out.x > 0.5 and p.y > 7.0:
				# Borda da Regiao Rochosa: agulhas de pedra com cristais (fora da
				# area andavel), em vez de mata.
				if roll < 0.55:
					var sz := Vector3(rng.randf_range(1.0, 1.4), rng.randf_range(2.0, 3.2), rng.randf_range(0.9, 1.2))
					var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(sz), c + Vector3(0, sz.y * 0.42, 0))
					Flora.rock(tall[_chunk(p)], xf, Flora.Rock.SPIRE, rng, Flora.vary(Flora.ROCK_TONES.heath, rng, 0.05), "lichen")
					if rng.randf() < 0.6:
						_crystal_cluster(glow, c + Vector3(-0.55, 0.0, rng.randf_range(-0.3, 0.3)), rng, rng.randf_range(0.5, 0.9), 0.2)
					counts.spires += 1
				else:
					Flora.cycad(tall[_chunk(p)], c, rng.randf_range(0.8, 1.1), rng)
				counts.edge += 1
				continue
			if roll < 0.3:
				Flora.tree_fern(tall[_chunk(p)], c, rng.randf_range(2.0, 2.5), rng)
			elif roll < 0.62:
				Flora.cycad(tall[_chunk(p)], c, rng.randf_range(0.9, 1.4), rng)
			elif roll < 0.82:
				Flora.horsetail(low[_chunk(p)], c, rng.randf_range(0.8, 1.2), rng, [Color("8fbf74"), Color("5f9a55"), Color("3e7044")], rng.randi_range(6, 9))
			else:
				Flora.fern(low[_chunk(p)], c, rng.randf_range(0.5, 0.7), rng, Flora.vary([Color("5d9a6a"), Color("447f58"), Color("2f5e48")], rng))
			counts.edge += 1

static func _near_gap(p: Vector2, margin: float) -> bool:
	for gap in Valley.GAPS:
		if p.distance_to(gap[0]) < gap[1] + margin:
			return true
	return false

## Ruina do Arco: glifos jade nos pilares e na verga (nas faces, dentro da
## caixa do solido), cristais crescendo sobre a verga, piso antigo de lajes sob
## o arco e um anel de colunas quebradas (rentes) marcando a praca antiga.
static func _ruins(tall: Array, low: Array, glow: SurfaceTool, rng: RandomNumberGenerator, counts: Dictionary) -> void:
	var art := (load(ART) as PackedScene).instantiate()
	var center := Vector2(0.0, 16.0)
	for node in art.get_children():
		var label := String(node.name)
		if not label.begins_with("Arch") or not node is MeshInstance3D:
			continue
		var xf: Transform3D = node.transform
		var size: Vector3 = (node.mesh as BoxMesh).size
		var lintel := size.x > size.y
		# Faces norte e sul (as que a camera ve), 6 cm para dentro da caixa.
		for side in [-1.0, 1.0]:
			var n := (xf.basis * Vector3(0, 0, side)).normalized()
			var right := (xf.basis * Vector3(1, 0, 0)).normalized()
			var up := (xf.basis * Vector3(0, 1, 0)).normalized()
			if lintel:
				for k in 5:
					var lx := lerpf(-size.x * 0.36, size.x * 0.36, k / 4.0)
					var at := xf * Vector3(lx, 0.0, side * (size.z * 0.5 - 0.075))
					Flora.glyph(glow, at, right, up, n, 0.36, "crystal" if k % 2 == 0 else "spiral")
			else:
				var at := xf * Vector3(0, 0.15, side * (size.z * 0.5 - 0.075))
				Flora.glyph(glow, at, right, up, n, 0.62, "track" if side > 0.0 else "spiral")
				var at2 := xf * Vector3(0, -1.2, side * (size.z * 0.5 - 0.075))
				Flora.glyph(glow, at2, right, up, n, 0.4, "crystal")
		if lintel: # cristais brotando do topo da verga (sobre o solido)
			for lx in [size.x * 0.3, -size.x * 0.22]:
				var top := xf * Vector3(lx, size.y * 0.5 - 0.1, 0.0)
				_crystal_cluster(glow, top, rng, 0.6, 0.18)
	art.free()
	# Piso antigo sob o arco (rente, sobre a estrada) e entulho dos lados.
	for i in 18:
		var p := center + Vector2(rng.randf_range(-2.6, 2.6), rng.randf_range(-1.4, 1.4))
		Flora.flagstone(low[_chunk(p)], Vector3(p.x, 0.0, p.y), rng.randf_range(0.32, 0.5), rng.randf() * TAU, rng)
	# Anel de colunas quebradas: a praca de uma civilizacao antiga.
	for k in 14:
		var a := TAU * k / 14.0 + 0.1
		var p := center + Vector2(cos(a), sin(a)) * 5.4
		if absf(p.x) < 2.9 or not walkable(p) or not _clear(p, 0.6, 0.6):
			continue
		Flora.column_stump(tall[_chunk(p)], Vector3(p.x, 0.0, p.y), rng.randf_range(0.28, 0.36), rng.randf_range(0.16, 0.28), rng)
		counts.ruins += 1
	for k in 6:
		var a := rng.randf() * TAU
		var p := center + Vector2(cos(a), sin(a)) * rng.randf_range(3.2, 6.5)
		if absf(p.x) < 2.8 or not walkable(p) or not _clear(p, 0.6, 0.6):
			continue
		Flora.fallen_block(tall[_chunk(p)], Vector3(p.x, 0.0, p.y), Vector3(rng.randf_range(0.6, 0.9), rng.randf_range(0.18, 0.26), rng.randf_range(0.4, 0.55)), rng.randf() * PI, rng)
		counts.ruins += 1

## Regiao Rochosa: lajes baixas aflorando (rentes, com liquen e cristais).
static func _outcrops(tall: Array, glow: SurfaceTool, rng: RandomNumberGenerator, counts: Dictionary) -> void:
	var placed := 0
	for attempt in 120:
		if placed >= 7:
			break
		var p := Vector2(rng.randf_range(6.0, 23.0), rng.randf_range(8.0, 27.5))
		if heath(p) < 0.55 or not _clear(p, 1.1):
			continue
		var yaw := rng.randf() * PI
		var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(rng.randf_range(1.2, 1.7), 0.3, rng.randf_range(0.9, 1.2))), Vector3(p.x, 0.1, p.y))
		Flora.rock(tall[_chunk(p)], xf, Flora.Rock.SLAB, rng, Flora.vary(Flora.ROCK_TONES.heath, rng, 0.05), "lichen")
		if rng.randf() < 0.5:
			_crystal_cluster(glow, Vector3(p.x, 0.0, p.y) + Vector3(rng.randf_range(-0.3, 0.3), 0, 0.55), rng, 0.24)
		placed += 1
	counts.outcrops = placed
