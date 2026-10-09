extends SceneTree

# Spec 017A (Etapa 3) + Spec 018 — gera scenes/visuals/valley_art.tscn: o chao
# do vale inteiro (grama, biomas, trilhas de terra batida), detalhes rentes
# (pedras de borda, tufos, flores), os paredoes facetados em volta do vale, os
# monolitos das entradas noturnas e as montanhas ao fundo. So malhas: nenhum
# corpo fisico, fora de navigation_source, nada alto no chao andavel.
# Pipeline: tools/build_first_map.gd chama generate() depois de gravar
# arena_art.tscn (as arvores e rochas sao lidas de la para o sub-bosque).
# Sozinho: godot --headless --script res://tools/build_valley_art.gd
const Palette := preload("res://scenes/visuals/palette.gd")
const Facets := preload("res://scenes/visuals/facets.gd")
const Layout := preload("res://tools/valley_layout.gd")
const Nature := preload("res://scenes/visuals/nature_meshes.gd")
const OUT := "res://scenes/visuals/valley_art.tscn"
const ART := "res://scenes/visuals/arena_art.tscn"
const GROUND_Y := 0.012 # acima do chao fisico (y = 0), abaixo das pecas rentes
const CELL := 0.5 # m por celula do chao (2 triangulos)
const AREA_MIN := Vector2(-29.0, -29.0)
const AREA_MAX := Vector2(29.0, 33.0)
## Entradas das ondas no paredao: [ponto na borda, meia largura da passagem].
const GAPS := [[Vector2(-24.2, 2.0), 3.6], [Vector2(24.2, 2.0), 3.6], [Vector2(0.0, 28.2), 3.8]]

func _initialize() -> void:
	generate()
	quit()

static func generate() -> void:
	var trees: Array[Vector2] = []
	var art := (load(ART) as PackedScene).instantiate()
	for node in art.get_children():
		if String(node.name).begins_with("Trunk"):
			trees.append(Vector2(node.position.x, node.position.z))
	art.free()
	var root := Node3D.new()
	root.name = "ValleyArt"
	root.set_script(load("res://scenes/visuals/refuge_art.gd")) # brilho noturno por meta "glow"
	var noise := _noises()
	root.add_child(_ground(noise, trees))
	root.add_child(_path_stones(noise))
	root.add_child(_tufts(noise, trees))
	root.add_child(_cliffs())
	root.add_child(_entry_stones())
	root.add_child(_entry_runes())
	root.add_child(_mountains())
	_arch(root)
	for child in root.get_children():
		child.owner = root
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, OUT) == OK)
	root.free()
	print("[018] valley_art.tscn: chao, trilhas, paredoes, entradas e montanhas")

static func _noises() -> Array:
	var big := FastNoiseLite.new()
	big.seed = 18018
	big.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	big.frequency = 0.07
	big.fractal_octaves = 2
	var fine := FastNoiseLite.new()
	fine.seed = 18019
	fine.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fine.frequency = 0.32
	fine.fractal_octaves = 1
	return [big, fine]

static func _hash(p: Vector2) -> float:
	return fposmod(sin(p.x * 12.9898 + p.y * 78.233) * 43758.5453, 1.0)

## Distancia (com sinal) ate a borda da trilha mais proxima; < 0 = dentro.
## Devolve [distancia, e rota noturna?].
static func trail_edge(p: Vector2, wobble: float) -> Array:
	var best := INF
	var night := false
	for t in Layout.PATHS:
		var d: float = Layout.path_distance(p, t.points) - t.width * 0.5 + wobble
		if d < best:
			best = d
			night = t.group == "NightRoutes"
	var fork := (Layout.patch_distance(p, [Layout.FORK, Layout.FORK_SIZE]) - 1.0) * 2.2 + wobble
	if fork < best:
		best = fork
		night = false
	return [best, night]

# --- Chao -----------------------------------------------------------------------
# Cor por VERTICE (bordas suaves entre grama, terra e lajes) e uma variacao
# pequena por triangulo (o facetado continua visivel).
const ROAD_DARK := Color("8a6b46")
const ROAD := Color("a8854f")

static func ground_color(p: Vector2, noise: Array, trees: Array[Vector2]) -> Color:
	var nb: float = noise[0].get_noise_2d(p.x, p.y)
	var nf: float = noise[1].get_noise_2d(p.x, p.y)
	var t := clampf(nb * 0.55 + 0.5 + nf * 0.12, 0.0, 1.0)
	# Grama do vale: o tom medio domina; manchas claras e escuras suaves.
	var col := Palette.GRASS_DARK.lerp(Palette.GRASS_MID, smoothstep(0.1, 0.45, t)).lerp(Palette.GRASS, smoothstep(0.62, 0.95, t) * 0.8)
	# Clareira do encontro (mais ensolarada).
	var glade := 1.0 - smoothstep(0.7, 1.15, Layout.patch_distance(p, Layout.GLADE) + nb * 0.2)
	col = col.lerp(Palette.GRASS, glade * 0.4)
	# Floresta Oeste: chao verde-azulado escuro (a mancha + a faixa oeste do vale).
	var wood := 1.0 - smoothstep(0.65, 1.2, Layout.patch_distance(p, Layout.WOODLAND) + nb * 0.18)
	wood = maxf(wood, smoothstep(-14.0, -20.0, p.x + nb * 2.0) * 0.85)
	var forest := Palette.FOREST_DARK.lerp(Palette.FOREST_FLOOR, smoothstep(0.2, 0.6, t)).lerp(Palette.FOREST_MOSS, smoothstep(0.7, 1.0, t))
	col = col.lerp(forest, wood)
	# Regiao Rochosa: verde-acinzentado com liquens.
	var heath := 1.0 - smoothstep(0.65, 1.15, Layout.patch_distance(p, Layout.HEATH) + nb * 0.18)
	var rocky := Palette.HEATH_DARK.lerp(Palette.HEATH, smoothstep(0.25, 0.75, t))
	rocky = rocky.lerp(Palette.LICHEN, smoothstep(0.35, 0.7, nf) * 0.5)
	col = col.lerp(rocky, heath)
	# Sombra de copa: sub-bosque escuro sob as arvores.
	var canopy := 0.0
	for tree in trees:
		var dt := tree.distance_to(p)
		if dt < 2.6:
			canopy = maxf(canopy, 1.0 - dt / 2.6)
	col = col.lerp(Palette.FOREST_DARK, canopy * 0.45)
	# Area de construcao: chao limpo, terra e grama rala.
	if Layout.in_build_zone(p, -0.1):
		col = Palette.EARTH_MID.lerp(Palette.GRASS_MID, 0.42 + 0.22 * nb + 0.1 * nf)
	# Trilhas: terra batida, borda escura irregular, grama pisada em volta.
	var edge: Array = trail_edge(p, nf * 0.18)
	var d: float = edge[0]
	if d < 0.0:
		var dirt: Color
		if edge[1]: # rota noturna: estrada principal, terra batida mais marcada
			dirt = ROAD_DARK.lerp(ROAD, smoothstep(-0.5, 0.6, nf + nb * 0.5))
		else: # trilha selvagem: mais clara e com grama invadindo
			dirt = ROAD.lerp(Palette.GRASS_MID, 0.22 + 0.18 * smoothstep(0.2, 0.8, nf))
		col = Palette.EARTH_EDGE.darkened(0.08).lerp(dirt, smoothstep(0.0, 0.45, -d))
	elif d < 0.8:
		col = col.darkened(0.16 * (1.0 - d / 0.8))
	# Patio do Refugio: terra escura entre as lajes (as lajes estao em RefugeArt).
	var r := p.distance_to(Layout.REFUGE)
	if not Layout.in_build_zone(p, 0.2):
		col = col.lerp(Palette.EARTH_EDGE.darkened(0.15).lerp(Palette.STONE_DARK, 0.3), 1.0 - smoothstep(5.5, 6.2, r + nf * 0.3))
	# Fora dos limites (pe do paredao): mais escuro.
	var outside := maxf(maxf(absf(p.x) - Layout.BOUND_X, Layout.BOUND_SOUTH - p.y), p.y - Layout.BOUND_NORTH)
	if outside > -0.4:
		col = col.lerp(Palette.CLIFF_DARK.darkened(0.2), clampf((outside + 0.4) / 2.0, 0.0, 0.7))
	return col

static func _ground(noise: Array, trees: Array[Vector2]) -> MeshInstance3D:
	var nx := int(ceil((AREA_MAX.x - AREA_MIN.x) / CELL))
	var nz := int(ceil((AREA_MAX.y - AREA_MIN.y) / CELL))
	var grid := []
	var colors := []
	for i in nx + 1:
		var column := []
		var tones := []
		for j in nz + 1:
			var p := AREA_MIN + Vector2(i, j) * CELL
			if i > 0 and i < nx and j > 0 and j < nz: # contorno reto, miolo irregular
				p += Vector2(_hash(p) - 0.5, _hash(p + Vector2(7.1, 3.3)) - 0.5) * CELL * 0.55
			column.append(Vector3(p.x, GROUND_Y, p.y))
			tones.append(ground_color(p, noise, trees))
		grid.append(column)
		colors.append(tones)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in nx:
		for j in nz:
			var q := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			var tris := [[0, 1, 2], [0, 2, 3]] if _hash(Vector2(i, j) * 0.37) > 0.5 else [[0, 1, 3], [1, 2, 3]]
			for tri in tris:
				var pts := []
				var cols := []
				for k in tri:
					var g: Vector2i = q[k]
					pts.append(grid[g.x][g.y])
					cols.append(colors[g.x][g.y])
				var c3: Vector3 = (pts[0] + pts[1] + pts[2]) / 3.0
				var v := _hash(Vector2(c3.x, c3.z)) # variacao por triangulo
				var f := 1.0 + 0.07 * (v - 0.5)
				# Frente para cima: o Godot desenha a frente no sentido horario.
				var order := [0, 1, 2] if (pts[1] - pts[0]).cross(pts[2] - pts[0]).y < 0.0 else [0, 2, 1]
				for k in order:
					var col: Color = cols[k]
					st.set_color(Color(col.r * f, col.g * f, col.b * f))
					st.set_normal(Vector3.UP)
					st.add_vertex(pts[k])
	var mi := Facets.instance("Ground", st.commit(), Palette.toon(0.4, 0.0), Vector3.ZERO, false)
	return mi

# --- Pedras rentes nas bordas das rotas noturnas ---------------------------------
static func _path_stones(noise: Array) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 18101
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tones := [Palette.STONE_LIGHT, Palette.STONE, Palette.STONE_DARK]
	for t in Layout.PATHS:
		var pts: Array = t.points
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var dir := (b - a).normalized()
			var side := dir.orthogonal()
			var s := 1.2
			while s < a.distance_to(b) - 0.6:
				for sign_side in [-1.0, 1.0]:
					if rng.randf() < 0.45:
						continue
					var p: Vector2 = a + dir * (s + rng.randf_range(-0.4, 0.4)) + side * sign_side * (t.width * 0.5 + rng.randf_range(0.05, 0.35))
					if p.distance_to(Layout.REFUGE) < 6.4 or Layout.in_build_zone(p, 0.3):
						continue
					if absf(p.x) > Layout.BOUND_X - 0.5 or p.y > Layout.BOUND_NORTH - 0.5:
						continue
					var size := rng.randf_range(0.14, 0.26)
					var paint := func(c: Vector3, n: Vector3) -> Color:
						return Facets.by_height(tones, n, c.y, 0.0, 0.1, c.x + c.z)
					var rings := []
					for spec in [[-0.01, 1.0], [0.06, 0.75]]:
						var ring := Facets.ring(5, size * spec[1], spec[0], rng, 0.22, rng.randf() * TAU)
						for k in ring.size():
							ring[k] += Vector3(p.x, 0, p.y)
						rings.append(ring)
					Facets.loft(st, rings, Vector3(p.x, 0.1, p.y), null, paint)
				s += rng.randf_range(1.0, 1.8)
	return Facets.instance("PathStones", st.commit(), Palette.toon(0.3, 0.0), Vector3.ZERO, false)

# --- Tufos de grama e flores (rentes: ate 0,15 m) --------------------------------
## Triangulo visto dos dois lados, sempre iluminado como o chao (normal para
## cima): laminas de grama e petalas nao ficam pretas pelo verso.
static func _up_tri(st: SurfaceTool, pts: Array, cols: Array) -> void:
	for order in [[0, 1, 2], [0, 2, 1]]:
		for k in order:
			st.set_normal(Vector3.UP)
			st.set_color(cols[k])
			st.add_vertex(pts[k])

static func _tufts(noise: Array, trees: Array[Vector2]) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 18202
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var placed := 0
	for attempt in 5200:
		var p := Vector2(rng.randf_range(-Layout.BOUND_X + 0.4, Layout.BOUND_X - 0.4), rng.randf_range(Layout.BOUND_SOUTH + 0.4, Layout.BOUND_NORTH - 0.4))
		var nb: float = noise[0].get_noise_2d(p.x, p.y)
		var edge: Array = trail_edge(p, 0.0)
		if edge[0] < 0.25 or p.distance_to(Layout.REFUGE) < 6.6 or Layout.in_build_zone(p, 0.4) \
				or p.distance_to(Layout.DEFENSE_POST) < 1.8:
			continue
		# Mais tufos perto das arvores e nas manchas escuras; campina rala.
		var near_tree := false
		for tree in trees:
			if tree.distance_to(p) < 3.2:
				near_tree = true
				break
		var keep := 0.22 + (0.45 if near_tree else 0.0) + 0.2 * maxf(0.0, -nb)
		if rng.randf() > keep:
			continue
		var base_col: Color = ground_color(p, noise, trees)
		var flower := not near_tree and rng.randf() < 0.16 and Layout.patch_distance(p, Layout.HEATH) > 1.0
		var blades := rng.randi_range(3, 5)
		for k in blades:
			var a := rng.randf() * TAU
			var lean := Vector2(cos(a), sin(a)) * rng.randf_range(0.03, 0.08)
			var h := rng.randf_range(0.09, 0.145)
			var w := rng.randf_range(0.025, 0.04)
			var side := Vector2(-sin(a), cos(a)) * w
			var root := p + Vector2(cos(a), sin(a)) * rng.randf_range(0.0, 0.06)
			_up_tri(st, [Vector3(root.x - side.x, GROUND_Y, root.y - side.y), Vector3(root.x + side.x, GROUND_Y, root.y + side.y),
				Vector3(root.x + lean.x, h, root.y + lean.y)], [base_col, base_col, base_col.lightened(0.18)])
		if flower:
			var fc: Color = Palette.FLOWERS[rng.randi() % Palette.FLOWERS.size()]
			var fy := rng.randf_range(0.1, 0.14)
			var fs := rng.randf_range(0.045, 0.065)
			for q in 2: # 4 petalas em cruz: dois losangos rentes
				var turn := q * PI * 0.5 + rng.randf() * 0.3
				var u := Vector2(cos(turn), sin(turn)) * fs
				var v := Vector2(-u.y, u.x) * 0.45
				for tri_pts in [[u, v], [v, -u], [-u, -v], [-v, u]]:
					_up_tri(st, [Vector3(p.x, fy, p.y), Vector3(p.x + tri_pts[0].x, fy, p.y + tri_pts[0].y),
						Vector3(p.x + tri_pts[1].x, fy, p.y + tri_pts[1].y)], [fc, fc, fc])
		placed += 1
	print("[018] %d tufos" % placed)
	return Facets.instance("Tufts", st.commit(), Palette.toon(0.4, 0.0), Vector3.ZERO, false)

# --- Paredoes em volta do vale ---------------------------------------------------
# Colunas de rocha facetada em 3 fileiras (frente baixa, fundo alto), topo com
# vegetacao. Tudo fora dos Boundary; nas entradas das ondas, so entulho baixo.
static func _cliffs() -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 25017
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x := Layout.BOUND_X
	_cliff_band(st, rng, Vector2(-31, Layout.BOUND_SOUTH), Vector2(31, Layout.BOUND_SOUTH), Vector2(0, -1))
	_cliff_band(st, rng, Vector2(-31, Layout.BOUND_NORTH), Vector2(31, Layout.BOUND_NORTH), Vector2(0, 1))
	_cliff_band(st, rng, Vector2(-x, Layout.BOUND_SOUTH - 1.0), Vector2(-x, Layout.BOUND_NORTH + 1.0), Vector2(-1, 0))
	_cliff_band(st, rng, Vector2(x, Layout.BOUND_SOUTH - 1.0), Vector2(x, Layout.BOUND_NORTH + 1.0), Vector2(1, 0))
	return Facets.instance("Cliffs", st.commit(), Palette.toon(0.3, 0.1))

static func _gap(p: Vector2) -> float:
	## 0 = fora de uma passagem; 1 = no centro dela.
	var g := 0.0
	for gap in GAPS:
		g = maxf(g, 1.0 - p.distance_to(gap[0]) / gap[1])
	return g

static func _cliff_band(st: SurfaceTool, rng: RandomNumberGenerator, a: Vector2, b: Vector2, out: Vector2) -> void:
	var tones := [Palette.CLIFF_LIGHT, Palette.CLIFF, Palette.CLIFF_DARK]
	var dir := (b - a).normalized()
	var length := a.distance_to(b)
	var rows := [
		{"off": 1.75, "step": 1.85, "r": Vector2(1.0, 1.3), "h": Vector2(2.0, 3.2)},
		{"off": 3.6, "step": 2.3, "r": Vector2(1.3, 1.7), "h": Vector2(3.6, 5.0)},
		{"off": 6.1, "step": 2.9, "r": Vector2(1.6, 2.1), "h": Vector2(5.0, 6.6)},
	]
	for k in rows.size():
		var row: Dictionary = rows[k]
		var s := rng.randf_range(0.0, 0.6)
		while s <= length:
			var edge := a + dir * s
			var gap := _gap(edge)
			var r := rng.randf_range(row.r.x, row.r.y)
			var h := rng.randf_range(row.h.x, row.h.y)
			var c2: Vector2 = edge + out * (row.off + rng.randf_range(-0.35, 0.35))
			s += row.step * rng.randf_range(0.85, 1.15)
			if gap > 0.0:
				if k > 0 and gap > 0.25:
					continue # passagem aberta: so a fileira da frente, baixa
				h = lerpf(h, rng.randf_range(0.5, 0.9), smoothstep(0.0, 0.35, gap))
				r *= lerpf(1.0, 0.75, gap)
			elif gap == 0.0 and _gap(edge - dir * 3.0) + _gap(edge + dir * 3.0) > 0.0:
				h *= 1.25 # flancos da passagem mais altos: portal natural
			_column(st, rng, Vector3(c2.x, 0, c2.y), r, h, tones)
	# Entulho no pe do paredao (ainda fora da area andavel).
	var s2 := 0.8
	while s2 < length:
		var p := a + dir * s2 + out * rng.randf_range(0.5, 0.75)
		s2 += rng.randf_range(2.0, 3.6)
		var size := rng.randf_range(0.28, 0.5)
		var paint_rock := func(f: Vector3, n: Vector3) -> Color:
			return Facets.by_height(tones, n, f.y, 0.0, size * 1.4, f.x + f.z)
		var rr := []
		for spec in [[-0.05, 1.0], [size * 0.6, 0.9]]:
			var ring := Facets.ring(5, size * spec[1], spec[0], rng, 0.2, rng.randf() * TAU, 0.05)
			for q in ring.size():
				ring[q] += Vector3(p.x, 0, p.y)
			rr.append(ring)
		Facets.loft(st, rr, Vector3(p.x, 0, p.y) + Vector3(rng.randf_range(-0.1, 0.1), size * 1.05, 0), null, paint_rock)

static func _column(st: SurfaceTool, rng: RandomNumberGenerator, c: Vector3, r: float, h: float, tones: Array) -> void:
	var sides := rng.randi_range(5, 7)
	var phase := rng.randf() * TAU
	var shade := rng.randf_range(-0.06, 0.06) # 3 tons + variacao por coluna
	var tilt := Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25))
	var top_y := func(p: Vector3) -> float: return h + tilt.x * (p.x - c.x) + tilt.y * (p.z - c.z)
	var paint := func(f: Vector3, n: Vector3) -> Color:
		var col: Color
		if n.y > 0.55:
			col = Facets.facet_shade(Palette.CLIFF_TOP.lerp(Palette.GRASS_MID, 0.35 * absf(sin(f.x * 3.1 + f.z))), n)
		elif f.y > top_y.call(f) - 0.22:
			col = Facets.facet_shade(Palette.CLIFF_TOP.darkened(0.25), n) # beirada do musgo
		else:
			col = Facets.by_height(tones, n, f.y, 0.0, h, c.x + c.z)
		return col.lightened(shade) if shade > 0.0 else col.darkened(-shade)
	var rings := []
	for spec in [[-0.3, 1.0, 0.0], [h * 0.45, 0.95, 0.12], [h - 0.22, 0.84, 0.05], [h, 0.9, 0.0]]:
		var ring := Facets.ring(sides, r * spec[1], spec[0], rng, 0.12, phase, spec[2])
		for i in ring.size():
			ring[i] += c
			if spec[0] >= h - 0.25:
				ring[i].y = top_y.call(ring[i]) - (0.22 if spec[0] < h else 0.0)
		rings.append(ring)
	Facets.loft(st, rings, true, null, paint)

# --- Entradas das ondas noturnas: monolitos escuros com runa azul-violeta -------
# Fora da area andavel, um par em cada passagem. A runa brilha so a noite
# (night_glow): "por aqui vem a ameaca".
static func _entry_spots() -> Array:
	var spots := []
	for gap in GAPS:
		var edge: Vector2 = gap[0]
		var along := Vector2(0, 1) if absf(edge.x) > 1.0 else Vector2(1, 0)
		var out := Vector2(signf(edge.x), 0) if absf(edge.x) > 1.0 else Vector2(0, 1)
		for sgn in [-1.0, 1.0]:
			var p: Vector2 = edge + along * sgn * (gap[1] + 0.2) + out * 1.4
			spots.append([p, out])
	return spots

static func _entry_stones() -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 18303
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tones := [Palette.NIGHT_STONE.lightened(0.18), Palette.NIGHT_STONE, Palette.NIGHT_STONE.darkened(0.3)]
	for spot in _entry_spots():
		var p: Vector2 = spot[0]
		var c := Vector3(p.x, 0, p.y)
		var paint := func(f: Vector3, n: Vector3) -> Color:
			return Facets.by_height(tones, n, f.y, 0.0, 3.4, p.x)
		Facets.loft(st, [
			Facets.ring(5, 0.75, -0.2, rng, 0.08, 0.3),
			Facets.ring(5, 0.62, 1.6, rng, 0.08, 0.35),
			Facets.ring(5, 0.45, 3.0, rng, 0.06, 0.4),
		].map(func(ring: PackedVector3Array) -> PackedVector3Array:
			for i in ring.size():
				ring[i] += c
			return ring), c + Vector3(0.1, 3.7, 0), null, paint)
	return Facets.instance("EntryStones", st.commit(), Palette.toon(0.3, 0.15))

static func _entry_runes() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint := func(_c: Vector3, _n: Vector3) -> Color:
		return Palette.NIGHT_RUNE
	for spot in _entry_spots():
		var p: Vector2 = spot[0]
		var out: Vector2 = spot[1]
		# Face voltada para dentro do vale (para a camera ver a runa).
		var face := Vector3(-out.x, 0, -out.y)
		var center := Vector3(p.x, 1.9, p.y) + face * 0.6
		var right := Vector3(face.z, 0, -face.x)
		var diamond := PackedVector3Array([center + Vector3.UP * 0.42, center + right * 0.2, center - Vector3.UP * 0.42, center - right * 0.2])
		Facets.loft(st, [diamond, PackedVector3Array(Array(diamond).map(func(v: Vector3) -> Vector3: return v + face * 0.06))], true, null, paint)
	var mi := Facets.instance("EntryRunes", st.commit(), Palette.toon_glow(Palette.NIGHT_RUNE, 0.3, 0.0), Vector3.ZERO, false)
	mi.set_meta("glow", Vector2(0.0, 1.6))
	return mi

# --- Montanhas ao fundo (perspectiva atmosferica) ---------------------------------
static func _mountains() -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 18404
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tones := [Palette.MOUNTAIN_TOP, Palette.MOUNTAIN, Palette.MOUNTAIN.darkened(0.2)]
	for i in 22:
		var a := TAU * i / 22.0
		for peak in 2:
			var dist := 47.0 + peak * 7.0 + rng.randf_range(-2.0, 2.0)
			var aa := a + (0.07 if peak == 1 else 0.0)
			var c := Vector3(sin(aa) * dist, 0, cos(aa) * dist + 2.0)
			var r := rng.randf_range(9.0, 12.5) * (1.15 if peak == 1 else 1.0)
			var h := rng.randf_range(11.0, 17.0) * (1.25 if peak == 1 else 1.0)
			var paint := func(f: Vector3, n: Vector3) -> Color:
				return Facets.by_height(tones, n, f.y, -2.0, h, c.x)
			var rings := []
			for spec in [[-2.0, 1.0], [h * 0.4, 0.62], [h * 0.75, 0.3]]:
				var ring := Facets.ring(7, r * spec[1], spec[0], rng, 0.18, rng.randf() * TAU, 0.6)
				for q in ring.size():
					ring[q] += c
				rings.append(ring)
			Facets.loft(st, rings, c + Vector3(rng.randf_range(-1.5, 1.5), h, rng.randf_range(-1.5, 1.5)), null, paint)
	return Facets.instance("Mountains", st.commit(), Palette.toon(0.4, 0.0), Vector3.ZERO, false)

# --- Ruina do Arco (OldArch): blocos facetados sobre os solidos dos Arch* -------
# Os nos antigos (caixas lisas) ficam ocultos; a colisao vem deles (mesh.size e
# transform) e nao muda. Cada peca nova usa o MESMO transform e cabe na caixa.
static func _arch(root: Node3D) -> void:
	var art := (load(ART) as PackedScene).instantiate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 18505
	var tones := [Palette.STONE_LIGHT, Palette.STONE, Palette.STONE_DARK]
	for node in art.get_children():
		var label := String(node.name)
		if not label.begins_with("Arch") or not node is MeshInstance3D:
			continue
		var size: Vector3 = (node.mesh as BoxMesh).size
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var lintel := size.x > size.y
		var blocks := 1 if lintel else 3
		for b in blocks:
			var y0 := -size.y * 0.5 + size.y * b / blocks + 0.03
			var y1 := -size.y * 0.5 + size.y * (b + 1) / blocks - 0.05
			var inset := 0.08 + 0.05 * rng.randf()
			var shift := Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.04, 0.04))
			var hx := size.x * 0.5 - inset
			var hz := size.z * 0.5 - inset
			var ring := func(y: float, k: float) -> PackedVector3Array:
				var pts := PackedVector3Array()
				for q in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]:
					pts.append(shift + Vector3(q.x * k, y, q.y * k))
				return pts
			var paint := func(c: Vector3, n: Vector3) -> Color:
				if n.y > 0.7:
					return Facets.facet_shade(Nature.MOSS, n) # musgo no topo
				if not lintel and n.z > 0.7 and b == 1:
					return Facets.facet_shade(Palette.JADE_DARK, n) # runa entalhada
				return Facets.by_height(tones, n, c.y, -size.y * 0.5, size.y * 0.5, c.x + float(b))
			Facets.loft(st, [ring.call(y0, 0.97), ring.call(y0 + 0.08, 1.0), ring.call(y1 - 0.08, 1.0), ring.call(y1, 0.95)], true, true, paint)
		var mi := Facets.instance("Ruin" + label, st.commit(), Palette.toon(0.3, 0.12))
		mi.transform = node.transform
		mi.set_meta("on_solid", true)
		root.add_child(mi)
	art.free()
