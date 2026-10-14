extends SceneTree

# World 6.0 — arte e colisao das quatro regioes do mundo expandido.
# Pipeline: tools/build_first_map.gd -> (refuge, valley, flora e ESTE) ->
# build_collisions.ps1 -> bake_navmesh.gd. Standalone:
#   Godot --headless --path . --script res://tools/build_biome_art.gd
#
# Gera:
#  - scenes/visuals/biome_art.scn: blocos de malha por regiao do mapa (alto =
#    com sombra; rente = sem sombra; brilho = cristais/runas; lava; agua),
#    a cachoeira, o lago, o rio, o vulcao ao fundo e poucas particulas.
#  - scenes/world/biome_collision.tscn: os solidos de TODA peca alta da
#    expansao (arvores, rochas, ruinas, arco, troncos caidos) e os bloqueios da
#    agua funda e da lava. Mesma camada do mundo (1), grupo solid_obstacles; a
#    cena entra no grupo navigation_source (navmesh).
# Regras: nada alto nas trilhas de exploracao, nas rotas das ondas, nos
# marcos e nos monolitos das entradas; copas acima de 1,9 m; abaixo disso, so
# sobre um solido. A lava e a cachoeira sao decorativas (sem dano, sem mecanica).

const Flora := preload("res://scenes/visuals/flora.gd")
const Facets := preload("res://scenes/visuals/facets.gd")
const Palette := preload("res://scenes/visuals/palette.gd")
const Props := preload("res://scenes/visuals/prehistoric_props.gd")
const Biomes := preload("res://scenes/world/world_biomes.gd")
const Layout := preload("res://tools/valley_layout.gd")
const Valley := preload("res://tools/build_valley_art.gd")
const OUT_ART := "res://scenes/visuals/biome_art.scn"
const OUT_COLLISION := "res://scenes/world/biome_collision.tscn"
const AREA_MIN := Vector2(-48.0, -80.0)
const AREA_MAX := Vector2(48.0, 42.0)
const CHUNKS := Vector2i(5, 6)

const BASALT := [Color("4a4644"), Color("35312f"), Color("221f1e")]
const WET_ROCK := [Color("6e7b72"), Color("515d56"), Color("36403b")]
const CHAR := [Color("3a3330"), Color("2a2523"), Color("1b1716")]
const DARK_CRYSTAL := [Color("b9a6ff"), Color("6c5bd1"), Color("3a2c80")]
const REED := [Color("9cbf6d"), Color("6f9a52"), Color("4a7040")]
const ASH_SHRUB := [Color("6a625a"), Color("4e4842"), Color("37322e")]


func _initialize() -> void:
	generate()
	quit()

# --- Contexto -------------------------------------------------------------------
static func _new_ctx() -> Dictionary:
	var ctx := {"tall": [], "low": [], "glow": SurfaceTool.new(), "dark": SurfaceTool.new(), "lava": SurfaceTool.new(),
		"water": SurfaceTool.new(), "solids": [], "avoid": [], "counts": {}, "rng": RandomNumberGenerator.new()}
	for k in CHUNKS.x * CHUNKS.y:
		for list in ["tall", "low"]:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			ctx[list].append(st)
	for key in ["glow", "dark", "lava", "water"]:
		(ctx[key] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
	ctx.rng.seed = 60606
	return ctx

static func _chunk(p: Vector2) -> int:
	var size := (AREA_MAX - AREA_MIN) / Vector2(CHUNKS)
	var cx := clampi(int((p.x - AREA_MIN.x) / size.x), 0, CHUNKS.x - 1)
	var cz := clampi(int((p.y - AREA_MIN.y) / size.y), 0, CHUNKS.y - 1)
	return cz * CHUNKS.x + cx

static func tall(ctx: Dictionary, p: Vector2) -> SurfaceTool:
	return ctx.tall[_chunk(p)]

static func low(ctx: Dictionary, p: Vector2) -> SurfaceTool:
	return ctx.low[_chunk(p)]

static func count(ctx: Dictionary, key: String, n := 1) -> void:
	ctx.counts[key] = int(ctx.counts.get(key, 0)) + n

## Registra um solido: cilindro (r, h) ou caixa (size, yaw) ou prisma convexo.
static func solid_cyl(ctx: Dictionary, label: String, p: Vector2, r: float, h: float) -> void:
	ctx.solids.append({"name": label, "kind": "cyl", "pos": Vector3(p.x, h * 0.5, p.y), "r": r, "h": h})
	ctx.avoid.append([p, r])

static func solid_box(ctx: Dictionary, label: String, center: Vector3, size: Vector3, yaw: float) -> void:
	ctx.solids.append({"name": label, "kind": "box", "pos": center, "size": size, "yaw": yaw})
	ctx.avoid.append([Vector2(center.x, center.z), maxf(size.x, size.z) * 0.6])

static func solid_prism(ctx: Dictionary, label: String, points: PackedVector2Array, h: float) -> void:
	ctx.solids.append({"name": label, "kind": "prism", "points": points, "h": h})

static func clear(ctx: Dictionary, p: Vector2, r: float) -> bool:
	for a in ctx.avoid:
		if p.distance_to(a[0]) < a[1] + r:
			return false
	return true

## Lugar livre para uma peca ALTA: dentro do mundo, fora do vale antigo (com
## pequena margem para as transicoes), fora de trilhas/rotas/agua/lava/marcos.
static func free_spot(ctx: Dictionary, p: Vector2, r: float) -> bool:
	if not Biomes.in_bounds(p, 1.2 + r) or not Biomes.in_expansion(p, 1.5):
		return false
	if Biomes.trail_distance(p) < 1.2 + r or Biomes.water_distance(p) < 0.9 + r or Biomes.lava_distance(p) < 1.3 + r:
		return false
	for t in Layout.PATHS:
		if Layout.path_distance(p, t.points) < t.width * 0.5 + 1.0 + r:
			return false
	for spot in Valley._entry_spots():
		if p.distance_to(spot[0]) < 2.2 + r:
			return false
	if p.distance_to(Layout.REFUGE) < 7.0 + r:
		return false
	return clear(ctx, p, r)

## Lugar para uma peca RENTE (sem solido): so fora das trilhas e da agua.
static func free_low(p: Vector2) -> bool:
	return Biomes.in_bounds(p, 0.6) and Biomes.in_expansion(p, 1.0) and Biomes.trail_distance(p) > 0.2 \
		and Biomes.water_distance(p) > 0.4 and Biomes.lava_distance(p) > 0.6

# --- Gerar -----------------------------------------------------------------------
static func generate() -> void:
	var ctx := _new_ctx()
	_entry_stone_solids(ctx)
	_waterfall(ctx)
	_lake_and_rivers(ctx)
	_landmarks(ctx)
	_scatter(ctx)
	_volcano_peak(ctx)
	_save_art(ctx)
	_save_collision(ctx)
	print("[W6] biome_art.scn: %s" % JSON.stringify(ctx.counts))
	print("[W6] biome_collision.tscn: %d solidos" % ctx.solids.size())

## Os monolitos das entradas das ondas (ValleyArt) estavam fora do vale antigo;
## agora ficam dentro do mundo: ganham solido (nada alto sem colisao).
static func _entry_stone_solids(ctx: Dictionary) -> void:
	var i := 0
	for spot in Valley._entry_spots():
		solid_cyl(ctx, "BiomeEntryStone%d" % i, spot[0], 0.78, 3.8)
		i += 1
	# A torre de vigia (RefugeArt) ficava alem do paredao sul antigo; agora esta
	# dentro do mundo (regiao do vulcao) e ganha solido.
	var tower := Vector2(-7.5, -29.0) # = build_refuge_art.gd WATCHTOWER
	solid_cyl(ctx, "BiomeWatchtower", tower, 1.75, 7.2)

# --- Agua: cachoeira, lago, rio e corrego ------------------------------------------
static func _rock_column(st: SurfaceTool, rng: RandomNumberGenerator, c: Vector3, r: float, h: float, tones: Array, top: Color) -> void:
	var sides := rng.randi_range(5, 7)
	var phase := rng.randf() * TAU
	var paint := func(f: Vector3, n: Vector3) -> Color:
		if n.y > 0.6:
			return Facets.facet_shade(top.lerp(top.darkened(0.2), absf(sin(f.x * 2.7 + f.z))), n)
		return Facets.by_height(tones, n, f.y, c.y, c.y + h, c.x + c.z)
	var rings := []
	for spec in [[-0.3, 1.0, 0.0], [h * 0.5, 0.92, 0.12], [h, 0.82, 0.05]]:
		var ring := Facets.ring(sides, r * spec[1], spec[0], rng, 0.14, phase, spec[2])
		for i in ring.size():
			ring[i] += c
		rings.append(ring)
	Facets.loft(st, rings, true, null, paint)

## Fita de agua caindo: do labio (a) ate a bacia (b), arqueando para fora.
static func _fall_ribbon(st: SurfaceTool, a: Vector3, b: Vector3, width: float, bulge: Vector3) -> void:
	var rows := 14
	var side := Vector3(0, 0, 1) * width * 0.5
	for i in rows:
		var t0 := float(i) / rows
		var t1 := float(i + 1) / rows
		var p0 := a.lerp(b, t0) + bulge * sin(t0 * PI) * (1.0 - t0 * 0.4)
		var p1 := a.lerp(b, t1) + bulge * sin(t1 * PI) * (1.0 - t1 * 0.4)
		p0.y = lerpf(a.y, b.y, t0 * t0)
		p1.y = lerpf(a.y, b.y, t1 * t1)
		var w0 := 1.0 + t0 * 0.35
		var w1 := 1.0 + t1 * 0.35
		var quad := [[p0 - side * w0, Vector2(0, t0)], [p0 + side * w0, Vector2(1, t0)], [p1 + side * w1, Vector2(1, t1)], [p1 - side * w1, Vector2(0, t1)]]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_uv(quad[k][1])
			st.set_normal(Vector3(1, 0.2, 0).normalized())
			st.add_vertex(quad[k][0])

static func _waterfall(ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var moss := Color("5c8a4c")
	var wf: Vector2 = Biomes.WATERFALL
	# Paredao da cachoeira: colunas altas de rocha umida em degraus, com um vao
	# (o canal) no meio por onde a agua cai; fora da area andavel (x < -32).
	for k in 3:
		var depth := 1.8 + k * 2.6
		var z := wf.y - 7.0
		while z < wf.y + 7.5:
			var zc := z + rng.randf_range(-0.3, 0.3)
			var in_channel := absf(zc - wf.y) < 1.6 + k * 0.4
			var h := rng.randf_range(8.0, 10.5) + k * 1.8 - absf(zc - wf.y) * 0.12
			if in_channel:
				h -= 1.2 + (0.0 if k == 0 else 0.6) # o canal fica mais baixo: a agua sai por ele
				if k == 0:
					z += 1.8
					continue # a frente do canal fica aberta (a queda passa)
			_rock_column(st, rng, Vector3(wf.x - depth, 0, zc), rng.randf_range(1.2, 1.7), h, WET_ROCK, moss)
			z += rng.randf_range(1.6, 2.2)
	# Rochas da base, umidas, em volta da bacia (fora do caminho).
	for i in 9:
		var a := lerpf(-1.1, 1.1, i / 8.0)
		var c := Vector2(wf.x + 0.6, wf.y) + Vector2(cos(a), sin(a)) * rng.randf_range(3.0, 3.8)
		var s := rng.randf_range(0.7, 1.2)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s * 0.8, s)), Vector3(c.x, s * 0.3, c.y))
		Flora.rock(st, xf, Flora.Rock.BOULDER, rng, Flora.vary(WET_ROCK, rng, 0.05), "moss")
		if Biomes.in_bounds(c, 0.2):
			solid_cyl(ctx, "BiomeFallRock%d" % i, c, s * 0.55, s * 0.85)
	var cliff := Facets.instance("WaterfallCliff", st.commit(), Palette.toon(0.3, 0.12))
	# Quedas: a principal e duas menores.
	var fall := SurfaceTool.new()
	fall.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lip := Vector3(wf.x - 2.2, 9.6, wf.y)
	_fall_ribbon(fall, lip, Vector3(wf.x + 0.4, 0.12, wf.y), 2.4, Vector3(1.4, 0, 0))
	_fall_ribbon(fall, Vector3(wf.x - 2.0, 7.4, wf.y + 2.6), Vector3(wf.x + 0.1, 0.12, wf.y + 2.9), 0.8, Vector3(0.9, 0, 0))
	_fall_ribbon(fall, Vector3(wf.x - 2.3, 8.3, wf.y - 2.5), Vector3(wf.x + 0.1, 0.12, wf.y - 2.8), 0.9, Vector3(1.0, 0, 0))
	var fall_mat := ShaderMaterial.new()
	fall_mat.shader = load("res://scenes/visuals/waterfall.gdshader")
	var falls := Facets.instance("Waterfall", fall.commit(), fall_mat, Vector3.ZERO, false)
	ctx["waterfall_nodes"] = [cliff, falls]
	# Bacia (agua funda, bloqueada) com espuma, e a nevoa.
	_water_disc(ctx.water, Vector2(wf.x + 0.4, wf.y), Vector2(3.1, 3.4), 18)
	solid_prism(ctx, "BiomeWaterfallPool", _ellipse(Vector2(wf.x + 0.4, wf.y), Vector2(2.9, 3.2), 14), 2.2)
	count(ctx, "waterfall")

static func _ellipse(c: Vector2, radii: Vector2, sides: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		var a := TAU * i / sides
		pts.append(c + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts

## Disco de agua (lago, bacia): aneis com alfa da cor = 1 na margem, 0 no meio.
static func _water_disc(st: SurfaceTool, c: Vector2, radii: Vector2, sides: int) -> void:
	var rings := [[1.0, 1.0], [0.82, 0.55], [0.5, 0.15], [0.0, 0.0]]
	for k in rings.size() - 1:
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var r0: float = rings[k][0]
			var r1: float = rings[k + 1][0]
			var e0: float = rings[k][1]
			var e1: float = rings[k + 1][1]
			var wobble := func(a: float, r: float) -> Vector2:
				var w := 1.0 + 0.06 * sin(a * 3.0 + c.x) * r
				return c + Vector2(cos(a) * radii.x * r * w, sin(a) * radii.y * r * w)
			var pts := [[wobble.call(a0, r0), e0], [wobble.call(a1, r0), e0], [wobble.call(a1, r1), e1], [wobble.call(a0, r1), e1]]
			for q in [0, 1, 2, 0, 2, 3]:
				var p: Vector2 = pts[q][0]
				st.set_color(Color(1, 1, 1, pts[q][1]))
				st.set_uv(Vector2(p.x * 0.1, p.y * 0.1))
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(p.x, 0.05, p.y))

## Faixa de agua ao longo de uma polilinha (rio/corrego), UV.y = fluxo.
static func _water_strip(st: SurfaceTool, points: Array, half: float) -> void:
	var dist := 0.0
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var side := (b - a).normalized().orthogonal() * half
		var la := dist
		dist += a.distance_to(b)
		var quad := [[a + side, 1.0, la], [a - side, 1.0, la], [b - side, 1.0, dist], [b + side, 1.0, dist], [a, 0.0, la], [b, 0.0, dist]]
		# duas metades: margem (alfa 1) -> meio (alfa 0)
		for tri in [[0, 4, 5], [0, 5, 3], [4, 1, 2], [4, 2, 5]]:
			for q in tri:
				var p: Vector2 = quad[q][0]
				st.set_color(Color(1, 1, 1, quad[q][1]))
				st.set_uv(Vector2(0.0, quad[q][2] * 0.25))
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(p.x, 0.045, p.y))

static func _lake_and_rivers(ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	_water_disc(ctx.water, Biomes.LAKE_CENTER, Biomes.LAKE_RADII * 1.04, 28)
	solid_prism(ctx, "BiomeLake", _ellipse(Biomes.LAKE_CENTER, Biomes.LAKE_RADII * 0.94, 18), 2.2)
	ctx["river"] = SurfaceTool.new()
	(ctx.river as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
	_water_strip(ctx.river, Biomes.RIVER, Biomes.RIVER_HALF)
	_water_strip(ctx.river, Biomes.STREAM, Biomes.STREAM_HALF)
	# Pedras de travessia (rentes) no rio raso e no corrego.
	for path in [Biomes.RIVER, Biomes.STREAM]:
		for i in path.size() - 1:
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var mid := a.lerp(b, 0.5)
			for k in 3:
				var q := mid + (b - a).normalized().orthogonal() * (k - 1) * 0.7 + Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2))
				Flora.pebble(low(ctx, q), Vector3(q.x, 0.02, q.y), rng.randf_range(0.18, 0.26), rng, WET_ROCK)
	# Ilhas (dentro do bloqueio do lago): rocha, samambaias e uma arvore-jade.
	for spec in [[Vector2(-24.0, -23.2), 1.3], [Vector2(-19.8, -20.6), 0.9]]:
		var c: Vector2 = spec[0]
		var s: float = spec[1]
		var xf := Transform3D(Basis.from_scale(Vector3(s * 2.0, s * 0.7, s * 1.6)), Vector3(c.x, s * 0.15, c.y))
		Flora.rock(tall(ctx, c), xf, Flora.Rock.SLAB, rng, Flora.vary(WET_ROCK, rng, 0.05), "moss")
		for k in 3:
			var a := rng.randf() * TAU
			Flora.fern(low(ctx, c), Vector3(c.x + cos(a) * s * 0.6, s * 0.5, c.y + sin(a) * s * 0.5), 0.4, rng, Flora.vary(Flora.LEAVES[Flora.Kind.TREE_FERN], rng))
		if s > 1.0:
			Flora.tree(tall(ctx, c), Flora.Kind.JADE, Vector3(c.x, s * 0.4, c.y), 3.2, rng)
			Flora.crystal(ctx.glow, Vector3(c.x + 0.5, s * 0.45, c.y), 0.08, 0.3, Vector3(0.3, 1, 0), rng)
	# Juncos e cavalinhas na beira (dentro do bloqueio do lago) e folhas boiando.
	for i in 30:
		var a := TAU * i / 30.0 + rng.randf_range(-0.08, 0.08)
		var r := rng.randf_range(0.8, 0.92)
		var p := Biomes.LAKE_CENTER + Vector2(cos(a) * Biomes.LAKE_RADII.x, sin(a) * Biomes.LAKE_RADII.y) * r
		if i % 3 != 0:
			Flora.horsetail(low(ctx, p), Vector3(p.x, 0.0, p.y), rng.randf_range(0.7, 1.1), rng, REED, rng.randi_range(4, 7))
			count(ctx, "reeds")
		else:
			_lily(low(ctx, p), Vector2(p.x, p.y) + (Biomes.LAKE_CENTER - p).normalized() * 0.9, rng)
			count(ctx, "lily")
	# Margem: pedras molhadas (solidas quando altas) e musgo.
	for i in 16:
		var a := TAU * i / 16.0 + rng.randf_range(-0.1, 0.1)
		var p := Biomes.LAKE_CENTER + Vector2(cos(a) * Biomes.LAKE_RADII.x, sin(a) * Biomes.LAKE_RADII.y) * rng.randf_range(1.08, 1.2)
		if Biomes.trail_distance(p) < 0.8 or not Biomes.in_bounds(p, 1.0):
			continue
		var s := rng.randf_range(0.35, 0.7)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s * 1.3, s * 0.6, s)), Vector3(p.x, s * 0.12, p.y))
		Flora.rock(low(ctx, p) if s * 0.36 < 0.28 else tall(ctx, p), xf, Flora.Rock.BOULDER, rng, Flora.vary(WET_ROCK, rng, 0.05), "moss")
		if s * 0.36 >= 0.28:
			solid_cyl(ctx, "BiomeShoreRock%d" % i, p, s * 0.75, 0.6)
		count(ctx, "shore_rocks")

static func _lily(st: SurfaceTool, c: Vector2, rng: RandomNumberGenerator) -> void:
	var paint := func(_f: Vector3, n: Vector3) -> Color: return Facets.facet_shade(Color("5f9a4f"), n)
	for k in 2:
		var q := c + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4))
		var ring := Facets.ring(7, rng.randf_range(0.18, 0.28), 0.07, rng, 0.08, rng.randf() * TAU)
		for i in ring.size():
			ring[i] += Vector3(q.x, 0, q.y)
		Facets.loft(st, [ring], true, null, paint)

# --- Marcos: arco natural, canion, ruinas, fosseis, poças de lava --------------------
static func _landmarks(ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var stone := Flora.ROCK_TONES.heath
	# Arco natural de pedra sobre a trilha do canion (leste).
	var arch_c := Vector2(27.0, 8.0)
	for s: float in [-1.0, 1.0]:
		var p := arch_c + Vector2(s * 2.3, 0.0)
		var xf := Transform3D(Basis(Vector3.UP, 0.2 * s) * Basis.from_scale(Vector3(1.4, 4.0, 1.3)), Vector3(p.x, 1.9, p.y))
		Flora.rock(tall(ctx, p), xf, Flora.Rock.SLAB, rng, stone, "lichen")
		solid_cyl(ctx, "BiomeArchPillar%d" % int(s + 1.0), p, 0.85, 3.6)
	var top := Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0) * Basis.from_scale(Vector3(1.3, 6.4, 1.2)), Vector3(arch_c.x, 3.7, arch_c.y))
	Flora.rock(tall(ctx, arch_c), top, Flora.Rock.SLAB, rng, stone, "lichen")
	Flora.crystal(ctx.glow, Vector3(arch_c.x - 0.6, 4.25, arch_c.y), 0.12, 0.5, Vector3(0.2, 1, 0.1), rng)
	count(ctx, "arch")
	# Canion: duas fileiras de agulhas e lajes acompanhando a trilha leste.
	var canyon: Array = [[Vector2(24.2, 12.0), Vector2(25.0, 20.0)], [Vector2(30.6, 12.5), Vector2(30.2, 21.0)]]
	var i := 0
	for line in canyon:
		var a: Vector2 = line[0]
		var b: Vector2 = line[1]
		for k in 5:
			var p := a.lerp(b, k / 4.0) + Vector2(rng.randf_range(-0.3, 0.3), 0)
			if Biomes.trail_distance(p) < 1.6 or not Biomes.in_bounds(p, 0.8):
				continue
			var sz := Vector3(rng.randf_range(1.5, 2.2), rng.randf_range(2.4, 3.6), rng.randf_range(1.4, 2.0))
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(sz), Vector3(p.x, sz.y * 0.42, p.y))
			Flora.rock(tall(ctx, p), xf, Flora.Rock.SPIRE if k % 2 == 0 else Flora.Rock.SLAB, rng, Flora.vary(stone, rng, 0.05), "lichen")
			solid_cyl(ctx, "BiomeCanyon%d" % i, p, maxf(sz.x, sz.z) * 0.55, sz.y * 0.9)
			if k % 2 == 1:
				_crystal_cluster(ctx.glow, Vector3(p.x - 0.9, 0, p.y), rng, 0.3)
			i += 1
	count(ctx, "canyon", i)
	# Ruinas de pedra (leste) e ruinas cobertas de mata (oeste): colunas e blocos.
	for site in [[Vector2(26.0, 25.0), "stone"], [Vector2(-27.5, 17.0), "forest"], [Vector2(-8.0, 30.0), "forest"]]:
		var c: Vector2 = site[0]
		for k in 4:
			var a := TAU * k / 4.0 + rng.randf_range(-0.3, 0.3)
			var p := c + Vector2(cos(a), sin(a)) * rng.randf_range(1.4, 2.4)
			if not free_spot(ctx, p, 0.5):
				continue
			if k % 2 == 0:
				var h := rng.randf_range(0.9, 1.7)
				Flora.column_stump(tall(ctx, p), Vector3(p.x, 0, p.y), 0.42, h, rng)
				solid_cyl(ctx, "BiomeRuinColumn%d" % int(ctx.solids.size()), p, 0.5, h)
			else:
				var size := Vector3(rng.randf_range(0.9, 1.4), 0.55, rng.randf_range(0.6, 0.9))
				var yaw := rng.randf() * TAU
				Flora.fallen_block(tall(ctx, p), Vector3(p.x, 0, p.y), size, yaw, rng)
				solid_box(ctx, "BiomeRuinBlock%d" % int(ctx.solids.size()), Vector3(p.x, 0.3, p.y), size * Vector3(1.1, 1.1, 1.1), yaw)
			if site[1] == "forest":
				Flora.moss_mat(low(ctx, p), Vector3(p.x + 0.5, 0, p.y), 0.6, rng)
		for k in 5:
			var q := c + Vector2(rng.randf_range(-1.6, 1.6), rng.randf_range(-1.6, 1.6))
			if free_low(q):
				Flora.flagstone(low(ctx, q), Vector3(q.x, 0, q.y), rng.randf_range(0.3, 0.45), rng.randf() * TAU, rng)
		count(ctx, "ruins")
	# Fosseis grandes (rentes): costelas e cranios no vulcao e na pedra.
	ctx["props"] = []
	for spec in [[Vector3(9.0, 0, -36.0), 0.6, "ribs"], [Vector3(20.0, 0, -28.5), -1.0, "skull"], [Vector3(29.0, 0, -6.0), 2.2, "skull"], [Vector3(-12.0, 0, -36.5), 0.3, "ribs"]]:
		var p: Vector3 = spec[0]
		if not free_spot(ctx, Vector2(p.x, p.z), 0.8):
			continue
		ctx.props.append(Props.ribcage(p, spec[1]) if spec[2] == "ribs" else Props.skull(p, spec[1]))
		ctx.avoid.append([Vector2(p.x, p.z), 1.4])
		count(ctx, "fossils")
	# Pocas de lava (so visuais): borda de basalto, fendas acesas, bloqueio.
	var j := 0
	for pool in Biomes.LAVA_POOLS:
		var c: Vector2 = pool[0]
		var r: float = pool[1]
		_lava_disc(ctx.lava, c, r * 1.05, 14)
		solid_prism(ctx, "BiomeLavaPool%d" % j, _ellipse(c, Vector2(r + 0.35, r + 0.35), 12), 2.0)
		for k in 9:
			var a := TAU * k / 9.0 + rng.randf_range(-0.15, 0.15)
			var p := c + Vector2(cos(a), sin(a)) * (r + rng.randf_range(0.25, 0.5))
			var s := rng.randf_range(0.25, 0.42)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s * 1.4, s * 0.55, s)), Vector3(p.x, s * 0.1, p.y))
			Flora.rock(low(ctx, p), xf, Flora.Rock.BOULDER, rng, BASALT, "")
		# fendas incandescentes saindo da poca (rentes)
		for k in 3:
			var a := rng.randf() * TAU
			_fissure(ctx.lava, c + Vector2(cos(a), sin(a)) * (r + 0.4), Vector2(cos(a), sin(a)), rng.randf_range(2.2, 3.6), rng)
		j += 1
	count(ctx, "lava_pools", j)

static func _crystal_cluster(st: SurfaceTool, c: Vector3, rng: RandomNumberGenerator, height: float, tones := Flora.CRYSTAL) -> void:
	for k in rng.randi_range(3, 4):
		var a := rng.randf() * TAU
		var off := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.14)
		var h := height * rng.randf_range(0.55, 1.0)
		Flora.crystal(st, c + off, h * 0.22, h, Vector3(cos(a) * 0.45, 1.0, sin(a) * 0.45), rng, tones)

static func _lava_disc(st: SurfaceTool, c: Vector2, r: float, sides: int) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var w0 := 1.0 + 0.12 * sin(a0 * 3.0 + c.x)
		var w1 := 1.0 + 0.12 * sin(a1 * 3.0 + c.x)
		for p: Vector2 in [c, c + Vector2(cos(a1), sin(a1)) * r * w1, c + Vector2(cos(a0), sin(a0)) * r * w0]:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(p.x, 0.06, p.y))

## Fenda incandescente rente ao chao (ziguezague que afina).
static func _fissure(st: SurfaceTool, start: Vector2, dir: Vector2, length: float, rng: RandomNumberGenerator) -> void:
	var p := start
	var w := 0.16
	var steps := 5
	for i in steps:
		var d := dir.rotated(rng.randf_range(-0.6, 0.6)) * length / steps
		var q := p + d
		var side := d.normalized().orthogonal()
		var w2 := w * 0.7
		for v: Vector2 in [p + side * w, q + side * w2, q - side * w2, p + side * w, q - side * w2, p - side * w]:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(v.x, 0.03, v.y))
		p = q
		w = w2

# --- Espalhar pecas pelas regioes (transicoes pelos pesos) --------------------------
static func _scatter(ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var step := 2.3
	var x := AREA_MIN.x
	while x < AREA_MAX.x:
		var z := Biomes.BOUND_SOUTH
		while z < Biomes.BOUND_NORTH:
			var p := Vector2(x + rng.randf_range(0.2, step - 0.2), z + rng.randf_range(0.2, step - 0.2))
			z += step
			if not Biomes.in_bounds(p, 0.6) or not Biomes.in_expansion(p, 1.5):
				continue
			var w: Dictionary = Biomes.weights(p)
			var region := _pick(w, rng.randf())
			match region:
				Biomes.FOREST: _forest_piece(ctx, p, w)
				Biomes.STONE: _stone_piece(ctx, p, w)
				Biomes.WATER: _water_piece(ctx, p, w)
				Biomes.VOLCANO: _volcano_piece(ctx, p, w)
				_: _meadow_piece(ctx, p)
		x += step

static func _pick(w: Dictionary, roll: float) -> StringName:
	var acc := 0.0
	for id in [Biomes.FOREST, Biomes.STONE, Biomes.WATER, Biomes.VOLCANO, Biomes.MEADOW]:
		acc += float(w[id])
		if roll <= acc:
			return id
	return Biomes.MEADOW

static func _forest_piece(ctx: Dictionary, p: Vector2, w: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var roll := rng.randf()
	var dense := float(w[Biomes.FOREST])
	if roll < 0.34 * dense + 0.06 and free_spot(ctx, p, 0.6):
		var kinds := [Flora.Kind.CONIFER, Flora.Kind.ARAUCARIA, Flora.Kind.BROADLEAF, Flora.Kind.TREE_FERN, Flora.Kind.CONIFER]
		var kind: int = kinds[rng.randi() % kinds.size()]
		var h := rng.randf_range(3.0, 4.2)
		Flora.tree(tall(ctx, p), kind, Vector3(p.x, 0, p.y), h, rng)
		solid_cyl(ctx, "BiomeTree%d" % int(ctx.solids.size()), p, 0.42, 2.4)
		count(ctx, "trees")
		for k in 2: # pe da arvore: samambaias e musgo (rentes)
			var a := rng.randf() * TAU
			var q := p + Vector2(cos(a), sin(a)) * rng.randf_range(0.9, 1.4)
			if free_low(q) and clear(ctx, q, 0.2):
				Flora.fern(low(ctx, q), Vector3(q.x, 0, q.y), rng.randf_range(0.32, 0.42), rng, Flora.vary(Flora.LEAVES[Flora.Kind.CONIFER], rng))
		if rng.randf() < 0.35:
			Flora.mushrooms(low(ctx, p), Vector3(p.x + 0.55, 0, p.y + 0.2), rng)
	elif roll < 0.46 and free_spot(ctx, p, 0.6):
		var s := rng.randf_range(0.9, 1.5)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s * 1.2, s, s)), Vector3(p.x, s * 0.36, p.y))
		Flora.rock(tall(ctx, p), xf, Flora.Rock.BOULDER, rng, Flora.vary(Flora.ROCK_TONES.wood, rng, 0.05), "moss")
		solid_cyl(ctx, "BiomeMossRock%d" % int(ctx.solids.size()), p, s * 0.66, s * 0.85)
		count(ctx, "moss_rocks")
	elif roll < 0.5 and free_spot(ctx, p, 1.4):
		var yaw := rng.randf() * TAU
		var length := rng.randf_range(2.2, 3.2)
		Flora.fallen_log(tall(ctx, p), Vector3(p.x, 0, p.y), yaw, length, rng)
		solid_box(ctx, "BiomeLog%d" % int(ctx.solids.size()), Vector3(p.x, 0.3, p.y), Vector3(length + 0.3, 0.6, 0.8), -yaw)
		count(ctx, "logs")
	elif free_low(p) and clear(ctx, p, 0.3):
		for k in 3:
			var q := p + Vector2(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.7, 0.7))
			if free_low(q):
				Flora.fern(low(ctx, q), Vector3(q.x, 0, q.y), rng.randf_range(0.28, 0.4), rng, Flora.vary([Color("4f8a6e"), Color("37684f"), Color("244a3a")], rng))
		if rng.randf() < 0.4:
			Flora.moss_mat(low(ctx, p), Vector3(p.x, 0, p.y), rng.randf_range(0.5, 0.8), rng)
		if rng.randf() < 0.12:
			_crystal_cluster(ctx.glow, Vector3(p.x, 0, p.y), rng, 0.24)
		count(ctx, "undergrowth")

static func _stone_piece(ctx: Dictionary, p: Vector2, w: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var roll := rng.randf()
	var volcanic := float(w[Biomes.VOLCANO]) / maxf(float(w[Biomes.STONE]) + float(w[Biomes.VOLCANO]), 0.001)
	var tones: Array = Flora.ROCK_TONES.heath
	if volcanic > 0.25: # pedra -> vulcao: rochas mais escuras
		tones = [Flora.ROCK_TONES.heath[0].lerp(BASALT[0], volcanic), Flora.ROCK_TONES.heath[1].lerp(BASALT[1], volcanic), Flora.ROCK_TONES.heath[2].lerp(BASALT[2], volcanic)]
	if roll < 0.3 and free_spot(ctx, p, 0.9):
		var big := rng.randf() < 0.45
		var sz := Vector3(rng.randf_range(1.2, 2.0), rng.randf_range(1.2, 2.8) if big else rng.randf_range(0.9, 1.5), rng.randf_range(1.1, 1.8))
		var family: int = [Flora.Rock.SPIRE, Flora.Rock.SLAB, Flora.Rock.BOULDER][rng.randi() % 3]
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(sz), Vector3(p.x, sz.y * 0.4, p.y))
		Flora.rock(tall(ctx, p), xf, family, rng, Flora.vary(tones, rng, 0.05), "lichen" if volcanic < 0.5 else "")
		solid_cyl(ctx, "BiomeStone%d" % int(ctx.solids.size()), p, maxf(sz.x, sz.z) * 0.58, sz.y * 0.9)
		count(ctx, "stone_formations")
		if rng.randf() < 0.4: # minerio: cristais na base da rocha
			_crystal_cluster(ctx.glow, Vector3(p.x + maxf(sz.x, sz.z) * 0.6, 0, p.y), rng, 0.28)
			count(ctx, "ore")
	elif roll < 0.62 and free_low(p) and clear(ctx, p, 0.3):
		for k in 6: # cascalho
			var q := p + Vector2(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.9, 0.9))
			if free_low(q):
				Flora.pebble(low(ctx, q), Vector3(q.x, 0, q.y), rng.randf_range(0.06, 0.14), rng, tones)
		count(ctx, "gravel")
	elif roll < 0.72 and free_low(p) and clear(ctx, p, 0.3):
		Flora.shrub(low(ctx, p), Vector3(p.x, 0, p.y), rng.randf_range(0.22, 0.32), rng.randf_range(0.14, 0.2), rng, Flora.vary([Color("9aa36e"), Color("78845a"), Color("566146")], rng))
		count(ctx, "shrubs")

static func _water_piece(ctx: Dictionary, p: Vector2, w: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var roll := rng.randf()
	var wd := Biomes.water_distance(p)
	if wd < 3.5 and roll < 0.25 and free_spot(ctx, p, 0.5):
		var s := rng.randf_range(0.8, 1.2)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s * 1.3, s * 0.85, s)), Vector3(p.x, s * 0.3, p.y))
		Flora.rock(tall(ctx, p), xf, Flora.Rock.BOULDER, rng, Flora.vary(WET_ROCK, rng, 0.05), "moss")
		solid_cyl(ctx, "BiomeWetRock%d" % int(ctx.solids.size()), p, s * 0.72, s * 0.8)
		count(ctx, "wet_rocks")
	elif roll < 0.4 and free_spot(ctx, p, 0.6) and float(w[Biomes.FOREST]) + float(w[Biomes.WATER]) > 0.5:
		var kind := Flora.Kind.JADE if rng.randf() < 0.4 else Flora.Kind.BROADLEAF
		Flora.tree(tall(ctx, p), kind, Vector3(p.x, 0, p.y), rng.randf_range(3.0, 3.8), rng)
		solid_cyl(ctx, "BiomeShoreTree%d" % int(ctx.solids.size()), p, 0.42, 2.4)
		count(ctx, "trees")
	elif free_low(p) and clear(ctx, p, 0.3):
		var lush := [Color("5d9a6a"), Color("447f58"), Color("2f5e48")]
		for k in 4: # vegetacao umida e densa
			var q := p + Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8))
			if free_low(q):
				Flora.fern(low(ctx, q), Vector3(q.x, 0, q.y), rng.randf_range(0.3, 0.42), rng, Flora.vary(lush, rng))
		if rng.randf() < 0.5:
			Flora.moss_mat(low(ctx, p), Vector3(p.x, 0, p.y), rng.randf_range(0.5, 0.8), rng)
		count(ctx, "wet_growth")

static func _volcano_piece(ctx: Dictionary, p: Vector2, w: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var roll := rng.randf()
	if roll < 0.32 and free_spot(ctx, p, 0.8):
		var sz := Vector3(rng.randf_range(1.0, 1.8), rng.randf_range(1.2, 3.2), rng.randf_range(1.0, 1.6))
		var family: int = Flora.Rock.SPIRE if rng.randf() < 0.55 else Flora.Rock.BOULDER # formacoes agressivas
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3(1, 0, 0), rng.randf_range(-0.15, 0.15)) * Basis.from_scale(sz), Vector3(p.x, sz.y * 0.4, p.y))
		Flora.rock(tall(ctx, p), xf, family, rng, Flora.vary(BASALT, rng, 0.04), "")
		solid_cyl(ctx, "BiomeBasalt%d" % int(ctx.solids.size()), p, maxf(sz.x, sz.z) * 0.6, sz.y * 0.9)
		count(ctx, "basalt")
		if rng.randf() < 0.3: # cristais escuros (violeta)
			_crystal_cluster(ctx.dark, Vector3(p.x + maxf(sz.x, sz.z) * 0.6, 0, p.y), rng, 0.26, DARK_CRYSTAL)
			count(ctx, "dark_crystals")
	elif roll < 0.5 and free_spot(ctx, p, 0.6):
		_burnt_tree(tall(ctx, p), Vector3(p.x, 0, p.y), rng.randf_range(2.8, 3.8), rng)
		solid_cyl(ctx, "BiomeBurntTree%d" % int(ctx.solids.size()), p, 0.36, 2.6)
		count(ctx, "burnt_trees")
	elif roll < 0.6 and free_low(p) and clear(ctx, p, 0.4):
		_fissure(ctx.lava, p, Vector2.RIGHT.rotated(rng.randf() * TAU), rng.randf_range(1.6, 2.8), rng)
		count(ctx, "fissures")
	elif free_low(p) and clear(ctx, p, 0.3):
		for k in 5: # cinzas e escoria
			var q := p + Vector2(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.9, 0.9))
			if free_low(q):
				Flora.pebble(low(ctx, q), Vector3(q.x, 0, q.y), rng.randf_range(0.06, 0.13), rng, BASALT)
		if rng.randf() < 0.25 and float(w[Biomes.VOLCANO]) < 0.7:
			Flora.shrub(low(ctx, p), Vector3(p.x, 0, p.y), 0.22, 0.14, rng, ASH_SHRUB)
		count(ctx, "cinders")

static func _meadow_piece(ctx: Dictionary, p: Vector2) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	if rng.randf() < 0.35 and free_low(p) and clear(ctx, p, 0.3):
		Flora.shrub(low(ctx, p), Vector3(p.x, 0, p.y), rng.randf_range(0.22, 0.3), rng.randf_range(0.14, 0.2), rng, Flora.vary([Color("6aa765"), Color("4d8a55"), Color("336345")], rng))
		count(ctx, "meadow")

## Arvore queimada: tronco de carvao torto e 2-3 galhos secos (acima de 1,9 m).
static func _burnt_tree(st: SurfaceTool, base: Vector3, h: float, rng: RandomNumberGenerator) -> void:
	var lean := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
	var top := base + Vector3(0, h, 0) + lean
	Flora.limb(st, [base, base + Vector3(0, h * 0.5, 0) + lean * 0.4, top], [0.26, 0.2, 0.08], 6, rng, CHAR, true, null, 0.12)
	for k in rng.randi_range(2, 3):
		var y := lerpf(2.0, h * 0.92, rng.randf())
		var start := base.lerp(top, (y - base.y) / h)
		var a := rng.randf() * TAU
		var end := start + Vector3(cos(a) * rng.randf_range(0.8, 1.3), rng.randf_range(0.3, 0.8), sin(a) * rng.randf_range(0.8, 1.3))
		Flora.limb(st, [start, start.lerp(end, 0.5) + Vector3(0, 0.15, 0), end], [0.08, 0.05, 0.02], 4, rng, CHAR, true, null, 0.1)

# --- Vulcao ao fundo (fora da area andavel) ------------------------------------------
## Raio da encosta do vulcao na altura y (mesmo perfil dos aneis acima).
static func _cone_radius(y: float) -> float:
	var prof := [[-2.0, 21.0], [6.0, 16.0], [14.0, 10.5], [22.0, 6.2], [25.5, 5.2]]
	for i in prof.size() - 1:
		if y <= prof[i + 1][0]:
			return lerpf(prof[i][1], prof[i + 1][1], inverse_lerp(prof[i][0], prof[i + 1][0], y))
	return 5.2

static func _volcano_peak(ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var c := Biomes.VOLCANO_PEAK
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tones := [Color("6a5d55"), Color("3f3632"), Color("231d1b")]
	var paint := func(f: Vector3, n: Vector3) -> Color:
		var col := Facets.by_height(tones, n, f.y, -2.0, 26.0, f.x)
		if f.y > 20.0 and n.y > 0.3:
			col = col.lerp(Color("8a8079"), 0.5) # cinza no alto
		return col
	var rings := []
	for spec in [[-2.0, 21.0], [6.0, 16.0], [14.0, 10.5], [22.0, 6.2], [25.5, 5.2]]: # base estreita: nao invade a area andavel
		var ring := Facets.ring(16, spec[1], spec[0], rng, 0.07, 0.2, 0.6)
		for i in ring.size():
			ring[i] += c
		rings.append(ring)
	# cratera: a borda volta para dentro e desce
	var inner := Facets.ring(16, 3.4, 23.2, rng, 0.05, 0.2, 0.3)
	for i in inner.size():
		inner[i] += c
	rings.append(inner)
	Facets.loft(st, rings, c + Vector3(0, 22.0, 0), null, paint)
	# Encostas: contrafortes de basalto (silhueta agressiva).
	for k in 9:
		var a := TAU * k / 9.0 + rng.randf_range(-0.2, 0.2)
		var p := c + Vector3(sin(a), 0, cos(a)) * rng.randf_range(13.0, 17.0)
		_rock_column(st, rng, p, rng.randf_range(2.4, 3.6), rng.randf_range(4.0, 8.0), BASALT, Color("57514c"))
	ctx["volcano"] = Facets.instance("Volcano", st.commit(), Palette.toon(0.4, 0.05), Vector3.ZERO, false)
	# Linhas de lava descendo da cratera e o brilho interno.
	for k in 5:
		var a := lerpf(-0.9, 0.9, k / 4.0) + rng.randf_range(-0.1, 0.1) # leque na face voltada para o vale (+z)
		var dir := Vector3(sin(a), 0, cos(a))
		var prev := c + Vector3(0, 25.3, 0) + dir * 5.3
		var w := 0.7
		for s in 8:
			var t := float(s + 1) / 8.0
			var y := lerpf(25.3, 0.4, pow(t, 0.9))
			var r := _cone_radius(y) + 0.2 # rente a encosta
			var nxt := c + dir.rotated(Vector3.UP, sin(t * 6.0 + k) * 0.12) * r + Vector3(0, y, 0)
			var side := (nxt - prev).cross(Vector3.UP).normalized() * w
			for v: Vector3 in [prev + side, nxt + side * 0.8, nxt - side * 0.8, prev + side, nxt - side * 0.8, prev - side]:
				ctx.lava.set_normal(Vector3.UP)
				ctx.lava.add_vertex(v + (v - c).normalized() * 0.15)
			prev = nxt
			w *= 0.9
	_lava_disc(ctx.lava, Vector2(c.x, c.z), 4.0, 12)
	ctx["crater_y"] = 22.6

# --- Salvar --------------------------------------------------------------------------
static func _particles(label: String, at: Vector3, amount: int, life: float, box: Vector3, vel: Vector2, gravity: Vector3, size: float, color: Color, fade_in := 0.25) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = label
	p.position = at
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = vel.x
	p.initial_velocity_max = vel.y
	p.gravity = gravity
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size * 1.3
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	p.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = color
	mat.albedo_texture = _soft_dot()
	p.material_override = mat
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(fade_in, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

## Chao externo (alem do chao do vale, ate as montanhas): malha grossa e
## rente, sem sombra, so para a camera nunca ver o fundo vazio nas bordas.
static func _apron() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noise := FastNoiseLite.new()
	noise.seed = 6061
	noise.frequency = 0.05
	var inner_min: Vector2 = Valley.AREA_MIN + Vector2(0.5, 0.5)
	var inner_max: Vector2 = Valley.AREA_MAX - Vector2(0.5, 0.5)
	var cell := 6.0
	var color_at := func(x: float, z: float) -> Color:
		var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
		var col := Color("3f5a43").lerp(Color("5a6458"), n)
		var ash := smoothstep(-50.0, -64.0, z) * (1.0 - smoothstep(20.0, 40.0, absf(x - Biomes.VOLCANO_PEAK.x)))
		return col.lerp(Color("37322f").lerp(Color("4a433e"), n), ash)
	var x := -108.0
	while x < 108.0:
		var z := -120.0
		while z < 90.0:
			var a := Vector2(x, z)
			var b := Vector2(x + cell, z + cell)
			z += cell
			if a.x >= inner_min.x and b.x <= inner_max.x and a.y >= inner_min.y and b.y <= inner_max.y:
				continue
			var corners := [Vector3(a.x, -0.04, a.y), Vector3(b.x, -0.04, a.y), Vector3(b.x, -0.04, b.y), Vector3(a.x, -0.04, b.y)]
			for k in [0, 1, 2, 0, 2, 3]:
				var v: Vector3 = corners[k]
				st.set_color(color_at.call(v.x, v.z))
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
		x += cell
	return Facets.instance("OuterGround", st.commit(), Palette.toon(0.3, 0.0), Vector3.ZERO, false)

## Textura radial suave (particula redonda, sem quadrado aparente).
static func _soft_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex

static func _save_art(ctx: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "BiomeArt"
	root.set_script(load("res://scenes/visuals/refuge_art.gd")) # brilho noturno por meta "glow"
	var mat := Palette.toon(0.3, 0.14)
	var low_mat := Palette.toon_double(0.32)
	for k in CHUNKS.x * CHUNKS.y:
		var mt: ArrayMesh = ctx.tall[k].commit()
		if mt.get_surface_count() > 0:
			root.add_child(Facets.instance("Tall%d" % k, mt, mat, Vector3.ZERO, true))
		var ml: ArrayMesh = ctx.low[k].commit()
		if ml.get_surface_count() > 0:
			root.add_child(Facets.instance("Low%d" % k, ml, low_mat, Vector3.ZERO, false))
	var crystals := Facets.instance("BiomeCrystals", ctx.glow.commit(), Palette.toon_glow(Palette.CRYSTAL_GLOW, 0.22, 0.35), Vector3.ZERO, false)
	crystals.set_meta("glow", Vector2(0.25, 1.1))
	root.add_child(crystals)
	var dark := Facets.instance("DarkCrystals", ctx.dark.commit(), Palette.toon_glow(Color("6c5bd1"), 0.22, 0.35), Vector3.ZERO, false)
	dark.set_meta("glow", Vector2(0.35, 1.2))
	root.add_child(dark)
	var lava_mat := ShaderMaterial.new()
	lava_mat.shader = load("res://scenes/visuals/lava.gdshader")
	root.add_child(Facets.instance("Lava", ctx.lava.commit(), lava_mat, Vector3.ZERO, false))
	var water_mat := ShaderMaterial.new()
	water_mat.shader = load("res://scenes/visuals/stylized_water.gdshader")
	root.add_child(Facets.instance("LakeWater", ctx.water.commit(), water_mat, Vector3.ZERO, false))
	var river_mat := water_mat.duplicate() as ShaderMaterial
	river_mat.set_shader_parameter("flow_speed", 0.8)
	root.add_child(Facets.instance("RiverWater", ctx.river.commit(), river_mat, Vector3.ZERO, false))
	for n in ctx.waterfall_nodes:
		root.add_child(n)
	root.add_child(ctx.volcano)
	root.add_child(_apron())
	for prop in ctx.props:
		root.add_child(prop)
	# Particulas: poucas e grandes (nevoa, fumaca, fagulhas).
	var wf: Vector2 = Biomes.WATERFALL
	root.add_child(_particles("WaterfallMist", Vector3(wf.x + 0.6, 0.6, wf.y), 22, 3.2, Vector3(1.6, 0.3, 2.2), Vector2(0.4, 0.9), Vector3(0.25, 0.25, 0), 1.6, Color(0.9, 0.97, 0.95, 0.28)))
	var c := Biomes.VOLCANO_PEAK
	root.add_child(_particles("VolcanoSmoke", c + Vector3(0, ctx.crater_y + 1.0, 0), 14, 10.0, Vector3(3.0, 0.5, 3.0), Vector2(1.2, 2.0), Vector3(0.6, 0.35, 0), 7.0, Color(0.33, 0.3, 0.29, 0.38), 0.15))
	var i := 0
	for pool in Biomes.LAVA_POOLS:
		var at: Vector2 = pool[0]
		root.add_child(_particles("LavaEmbers%d" % i, Vector3(at.x, 0.3, at.y), 8, 2.4, Vector3(pool[1] * 0.6, 0.1, pool[1] * 0.6), Vector2(0.6, 1.4), Vector3(0, 0.2, 0), 0.08, Color(1.0, 0.6, 0.25, 0.9), 0.1))
		root.add_child(_particles("LavaSmoke%d" % i, Vector3(at.x, 0.8, at.y), 5, 6.0, Vector3(pool[1] * 0.4, 0.2, pool[1] * 0.4), Vector2(0.4, 0.8), Vector3(0.2, 0.15, 0), 1.6, Color(0.3, 0.27, 0.26, 0.22), 0.2))
		i += 1
	# Brilho da cratera a noite (sem sombra, alcance curto).
	var glow := OmniLight3D.new()
	glow.name = "CraterGlow"
	glow.position = c + Vector3(0, ctx.crater_y + 2.0, 0)
	glow.light_color = Color(1.0, 0.45, 0.18)
	glow.light_energy = 2.2
	glow.omni_range = 18.0
	glow.shadow_enabled = false
	root.add_child(glow)
	for child in root.find_children("*", "", true, false):
		child.owner = root
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, OUT_ART) == OK)
	root.free()

## Prisma convexo (parede vertical ate h) com chapeu em cone mais ingreme que a
## rampa maxima do agente (45 graus): o topo nunca vira ilha na navmesh.
static func _capped(points: PackedVector2Array, h: float) -> ConvexPolygonShape3D:
	var center := Vector2.ZERO
	for p in points:
		center += p
	center /= points.size()
	var reach := 0.0
	for p in points:
		reach = maxf(reach, p.distance_to(center))
	var pts := PackedVector3Array()
	for p in points:
		pts.append(Vector3(p.x, 0.0, p.y))
		pts.append(Vector3(p.x, h, p.y))
	pts.append(Vector3(center.x, h + reach * 1.4, center.y))
	var convex := ConvexPolygonShape3D.new()
	convex.points = pts
	return convex

static func _save_collision(ctx: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "BiomeCollision"
	for s in ctx.solids:
		var body := StaticBody3D.new()
		body.name = s.name
		body.collision_layer = 1
		body.collision_mask = 0
		body.add_to_group("solid_obstacles", true)
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		match s.kind:
			"cyl":
				if s.r > 1.0: # topo largo viraria ilha na navmesh: cilindro com chapeu em cone
					var ring := PackedVector2Array()
					for i in 12:
						ring.append(Vector2(cos(TAU * i / 12.0), sin(TAU * i / 12.0)) * s.r)
					shape.shape = _capped(ring, maxf(s.h, 0.9))
					body.position = Vector3(s.pos.x, 0.0, s.pos.z)
				else:
					var cyl := CylinderShape3D.new()
					cyl.radius = s.r
					cyl.height = maxf(s.h, 0.9)
					shape.shape = cyl
					body.position = Vector3(s.pos.x, cyl.height * 0.5, s.pos.z)
			"box":
				var box := BoxShape3D.new()
				box.size = s.size
				shape.shape = box
				body.position = s.pos
				body.rotation.y = s.yaw
			"prism":
				shape.shape = _capped(s.points, s.h)
		root.add_child(body)
		body.add_child(shape)
	for child in root.find_children("*", "", true, false):
		child.owner = root
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, OUT_COLLISION) == OK)
	root.free()
