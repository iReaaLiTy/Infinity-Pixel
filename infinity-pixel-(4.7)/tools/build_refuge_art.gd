extends SceneTree

# Spec 017A — gera scenes/visuals/refuge_art.tscn: so malhas, sem fisica.
# Pipeline: tools/build_first_map.gd chama generate() (esconde as malhas antigas
# substituidas e grava esta cena) -> build_collisions -> bake_navmesh. As duas
# ultimas etapas NAO precisam rodar de novo: nada aqui tem colisao.
# Sozinho: godot --headless --script res://tools/build_refuge_art.gd
#
# Etapa 2: cristal. Etapa 3: plataforma facetada em 2 niveis, patio de lajes,
# degraus, braseiros, estandartes, rosacea do posto central, moldura da area de
# construcao e a torre de vigia (fora da area jogavel). Os paredoes e o chao
# estao em tools/build_valley_art.gd. Pontos de defesa: defense_slot.gd.
# Pecas altas so sobre solidos ja existentes (nucleo, tochas, mastros), cada
# uma na propria MeshInstance3D centrada no solido (meta on_solid).
const Palette := preload("res://scenes/visuals/palette.gd")
const Facets := preload("res://scenes/visuals/facets.gd")
const Layout := preload("res://tools/valley_layout.gd")
const OUT := "res://scenes/visuals/refuge_art.tscn"
const REFUGE := Vector3(0, 0, -15)
const RING_TOP := 0.425 # topo do RefugeRing (arena_art), onde o cristal se apoia
# Solidos de arena_collision (FirePost / BannerPole): mesmos centros.
const BRAZIERS := [Vector3(-3.3, 0, -14.3), Vector3(3.3, 0, -14.3)]
const BANNERS := [Vector3(-2, 0, -16), Vector3(2, 0, -16)]
const WATCHTOWER := Vector3(-7.5, 0, -29.0) # alem do paredao sul

func _initialize() -> void:
	generate()
	quit()

static func generate() -> void:
	var root := Node3D.new()
	root.name = "RefugeArt"
	root.set_script(load("res://scenes/visuals/refuge_art.gd"))
	_crystal(root)
	_platform(root)
	_courtyard(root)
	_rosette(root)
	for i in BRAZIERS.size():
		_brazier(root, BRAZIERS[i], i)
	for i in BANNERS.size():
		_banner(root, BANNERS[i], i)
	_build_frame(root)
	_watchtower(root)
	for child in root.get_children():
		child.owner = root
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, OUT) == OK)
	root.free()
	print("[017A] refuge_art.tscn: cristal, plataforma, patio, braseiros, estandartes, area de construcao")

# --- Cristal do Refugio --------------------------------------------------------
# Tudo dentro do raio do solido RefugeCore (cilindro r = 0,55 m, h = 2,6 m):
# nada alto fica sobre chao andavel sem colisao (regra 4 da Spec 017A).
static func _crystal(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17017
	# Pedestal de pedra facetado (dentro do solido).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stone_tones := [Palette.STONE_LIGHT, Palette.STONE, Palette.STONE_DARK]
	var paint_stone := func(c: Vector3, n: Vector3) -> Color:
		if n.y > 0.7:
			return Facets.facet_shade(Palette.STONE_LIGHT, n)
		return Facets.by_height(stone_tones, n, c.y, RING_TOP, RING_TOP + 0.4, 3.0)
	Facets.loft(st, [
		Facets.ring(7, 0.53, RING_TOP - 0.05, rng, 0.04, 0.2),
		Facets.ring(7, 0.52, RING_TOP + 0.22, rng, 0.05, 0.2, 0.02),
		Facets.ring(7, 0.42, RING_TOP + 0.32, rng, 0.05, 0.25, 0.01),
	], true, null, paint_stone)
	var pedestal := Facets.instance("CrystalPedestal", st.commit(), Palette.toon(0.3, 0.12), REFUGE)
	pedestal.set_meta("on_solid", true)
	root.add_child(pedestal)
	# Cristal principal + 3 lascas inclinadas: uma malha, um material.
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := RING_TOP + 0.28
	var paint_gem := func(c: Vector3, n: Vector3) -> Color:
		var t := clampf((c.y - base) / 2.6, 0.0, 1.0)
		var col := Palette.JADE_DARK.lerp(Palette.JADE, smoothstep(0.0, 0.5, t)).lerp(Palette.JADE_LIGHT, smoothstep(0.55, 1.0, t))
		# Facetas alternadas claro/escuro: leitura de gema mesmo sem reflexo.
		var side := fposmod(atan2(n.z, n.x) / TAU * 6.0, 2.0)
		return col.lightened(0.1) if side < 1.0 else col.darkened(0.08)
	Facets.loft(st, [
		Facets.ring(6, 0.2, base, rng, 0.04, 0.0),
		Facets.ring(6, 0.37, base + 0.45, rng, 0.05, 0.08),
		Facets.ring(6, 0.34, base + 2.0, rng, 0.04, 0.16),
	], Vector3(0.04, base + 2.85, -0.03), null, paint_gem)
	var heights := [1.25, 0.95, 0.75]
	for k in 3:
		var a := deg_to_rad(40.0 + 120.0 * k)
		var spot := Vector3(cos(a) * 0.27, base - 0.05, sin(a) * 0.27)
		var lean := Basis(Vector3(-sin(a), 0, cos(a)), deg_to_rad(13.0))
		var xf := Transform3D(lean, spot)
		var h: float = heights[k]
		var r := 0.14 - 0.015 * k
		Facets.loft(st, [
			Facets.ring(5, r * 0.8, 0.0, rng, 0.05, a, 0.0, xf),
			Facets.ring(5, r, h * 0.3, rng, 0.05, a + 0.1, 0.0, xf),
			Facets.ring(5, r * 0.85, h * 0.75, rng, 0.05, a + 0.2, 0.0, xf),
		], xf * Vector3(0, h, 0), null, paint_gem)
	var crystal := Facets.instance("Crystal", st.commit(), Palette.toon_glow(Palette.CRYSTAL_GLOW, 0.18, 0.4), REFUGE)
	crystal.set_meta("on_solid", true)
	crystal.set_meta("glow", Vector2(0.2, 0.85))
	root.add_child(crystal)
	# Anel de runas rentes sobre o RefugeRing (0,03 m de altura).
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint_rune := func(_c: Vector3, n: Vector3) -> Color:
		return Palette.JADE_LIGHT if n.y > 0.7 else Palette.JADE_DARK
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		var place := Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 1.45, 0, sin(a) * 1.45))
		var diamond := func(y: float, s: float) -> PackedVector3Array:
			return PackedVector3Array([place * Vector3(0.22 * s, y, 0), place * Vector3(0, y, 0.11 * s), place * Vector3(-0.22 * s, y, 0), place * Vector3(0, y, -0.11 * s)])
		Facets.loft(st, [diamond.call(RING_TOP - 0.01, 1.0), diamond.call(RING_TOP + 0.03, 0.8)], true, null, paint_rune)
	var runes := Facets.instance("Runes", st.commit(), Palette.toon_glow(Palette.CRYSTAL_GLOW, 0.3, 0.0), REFUGE, false)
	runes.set_meta("glow", Vector2(0.15, 1.0))
	root.add_child(runes)


## Malha centrada num solido existente (regra 4 da Spec 017A).
static func _on_solid(mi: MeshInstance3D) -> MeshInstance3D:
	mi.set_meta("on_solid", true)
	return mi

static func _hash(v: Vector2) -> float:
	return fposmod(sin(v.x * 12.9898 + v.y * 78.233) * 43758.5453, 1.0)

# --- Plataforma em 2 niveis (mesma pegada da antiga: r 2,5 e r 1,9) ------------
static func _platform(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17030
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tones := [Palette.STONE_LIGHT, Palette.STONE, Palette.STONE_DARK]
	var paint := func(c: Vector3, n: Vector3) -> Color:
		if n.y > 0.7: # lajes em cunha: cada fatia do topo com o seu tom
			var k := _hash(Vector2(snappedf(atan2(c.z, c.x), 0.1), snappedf(c.y, 0.05)))
			return Facets.facet_shade(Palette.STONE_LIGHT.lerp(Palette.STONE, 0.15 + 0.45 * k), n)
		if c.y > 0.33: # friso jade do nivel de cima
			return Facets.facet_shade(Palette.JADE_DARK, n)
		return Facets.by_height(tones, n, c.y, 0.0, 0.42, c.x)
	Facets.loft(st, [
		Facets.ring(8, 2.55, -0.01, rng, 0.015, PI / 8.0),
		Facets.ring(8, 2.5, 0.16, rng, 0.015, PI / 8.0),
		Facets.ring(8, 2.4, 0.22, rng, 0.01, PI / 8.0),
	], true, null, paint)
	Facets.loft(st, [
		Facets.ring(8, 1.95, 0.18, rng, 0.01, 0.0),
		Facets.ring(8, 1.93, 0.33, rng, 0.01, 0.0),
		Facets.ring(8, 1.9, 0.39, rng, 0.0, 0.0),
		Facets.ring(8, 1.84, RING_TOP, rng, 0.0, 0.0),
	], true, null, paint)
	# Degraus rentes na frente (para a camera e a estrada) e atras.
	for a in [PI / 2.0, -PI / 2.0]:
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x)
		var lo := PackedVector3Array()
		var hi := PackedVector3Array()
		for q in [[2.45, -0.8], [3.05, -0.8], [3.05, 0.8], [2.45, 0.8]]:
			var v: Vector3 = dir * q[0] + side * q[1]
			lo.append(v + Vector3(0, -0.01, 0))
			hi.append(v + Vector3(0, 0.11, 0))
		Facets.loft(st, [lo, hi], true, null, paint)
	root.add_child(_on_solid(Facets.instance("Platform", st.commit(), Palette.toon(0.3, 0.1), REFUGE)))

## Laje: setor de anel (r0..r1, a0..a1) com junta de 5 cm, rente ao chao.
static func _slab(st: SurfaceTool, center: Vector3, r0: float, r1: float, a0: float, a1: float, top: float, paint: Callable) -> void:
	var gap := 0.05
	var ga := gap / ((r0 + r1) * 0.5)
	a0 += ga
	a1 -= ga
	r0 += gap
	r1 -= gap
	var am := (a0 + a1) * 0.5
	var lo := PackedVector3Array()
	var hi := PackedVector3Array()
	for q in [Vector2(r0, a0), Vector2(r1, a0), Vector2(r1, am), Vector2(r1, a1), Vector2(r0, a1), Vector2(r0, am)]:
		var v := center + Vector3(cos(q.y) * q.x, 0, sin(q.y) * q.x)
		lo.append(v + Vector3(0, -0.01, 0))
		hi.append(v + Vector3(0, top, 0))
	Facets.loft(st, [lo, hi], true, null, paint)

# --- Patio de lajes em volta da plataforma -------------------------------------
static func _courtyard(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17040
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(Layout.REFUGE.x, 0, Layout.REFUGE.y)
	for ring in [[2.8, 3.65], [3.7, 4.6], [4.65, 5.55]]:
		var mid: float = (ring[0] + ring[1]) * 0.5
		var count := int(round(TAU * mid / 1.15))
		var phase := rng.randf() * TAU
		for i in count:
			var a0 := phase + TAU * i / count
			var a1 := phase + TAU * (i + 1) / count
			var am := (a0 + a1) * 0.5
			var p := Vector2(center.x + cos(am) * mid, center.z + sin(am) * mid)
			if rng.randf() < 0.07: # laje faltando: terra aparece
				continue
			if ring[0] < 3.0 and (absf(angle_difference(am, PI / 2.0)) < 0.38 or absf(angle_difference(am, -PI / 2.0)) < 0.38):
				continue # degraus
			var blocked := false
			for k in 3:
				var aa: float = lerpf(a0, a1, k / 2.0)
				for rr in ring:
					if Layout.in_build_zone(Vector2(center.x + cos(aa) * rr, center.z + sin(aa) * rr), 0.25):
						blocked = true
			for b in BRAZIERS:
				if Vector2(b.x, b.z).distance_to(p) < 0.45:
					blocked = true
			if blocked:
				continue
			var tone := Palette.STONE_LIGHT.lerp(Palette.STONE, rng.randf_range(0.1, 0.65))
			var paint := func(_c: Vector3, n: Vector3) -> Color:
				return Facets.facet_shade(tone, n) if n.y > 0.7 else Palette.STONE_DARK
			_slab(st, center, ring[0], ring[1], a0, a1, rng.randf_range(0.035, 0.06), paint)
	root.add_child(Facets.instance("Courtyard", st.commit(), Palette.toon(0.3, 0.0), Vector3.ZERO, false))

# --- Rosacea do posto central (marco DefensePost, no meio da estrada) -----------
static func _rosette(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17050
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(Layout.DEFENSE_POST.x, 0, Layout.DEFENSE_POST.y)
	for i in 8:
		var a0 := TAU * i / 8.0 + PI / 8.0
		var tone := Palette.STONE_LIGHT.lerp(Palette.STONE, 0.15 + 0.35 * (i % 2))
		var paint := func(_c: Vector3, n: Vector3) -> Color:
			return Facets.facet_shade(tone, n) if n.y > 0.7 else Palette.STONE_DARK
		_slab(st, center, 0.38, 1.45, a0, a0 + TAU / 8.0, 0.035, paint)
	root.add_child(Facets.instance("Rosette", st.commit(), Palette.toon(0.3, 0.0), Vector3.ZERO, false))
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint_jade := func(_c: Vector3, n: Vector3) -> Color:
		return Palette.JADE if n.y > 0.7 else Palette.JADE_DARK
	var at := Transform3D(Basis(), center)
	Facets.loft(st, [Facets.ring(8, 0.34, -0.01, rng, 0.0, PI / 8.0, 0.0, at),
		Facets.ring(8, 0.3, 0.05, rng, 0.0, PI / 8.0, 0.0, at)], true, null, paint_jade)
	var gem := Facets.instance("RosetteGem", st.commit(), Palette.toon_glow(Palette.CRYSTAL_GLOW, 0.3, 0.0), Vector3.ZERO, false)
	gem.set_meta("glow", Vector2(0.25, 0.9))
	root.add_child(gem)

# --- Braseiros (sobre os solidos FirePost, r 0,14) ------------------------------
static func _brazier(root: Node3D, at: Vector3, index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17060 + index
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tones := [Palette.STONE_LIGHT, Palette.STONE, Palette.STONE_DARK]
	var paint := func(c: Vector3, n: Vector3) -> Color:
		if c.y > 1.12: # bacia de pedra escura com brasas
			if n.y > 0.7:
				return Color("4a2e1e")
			return Facets.facet_shade(Palette.STONE_DARK.darkened(0.15), n)
		if c.y > 0.95: # cinta de madeira
			return Facets.facet_shade(Palette.WOOD_DARK, n)
		return Facets.by_height(tones, n, c.y, 0.0, 1.0, float(index))
	Facets.loft(st, [
		Facets.ring(6, 0.3, -0.02, rng, 0.04, 0.2),
		Facets.ring(6, 0.27, 0.18, rng, 0.04, 0.25),
		Facets.ring(6, 0.21, 0.95, rng, 0.03, 0.3),
		Facets.ring(6, 0.22, 1.12, rng, 0.02, 0.3),
		Facets.ring(6, 0.42, 1.42, rng, 0.03, 0.1),
		Facets.ring(6, 0.38, 1.5, rng, 0.02, 0.1),
	], true, null, paint)
	root.add_child(_on_solid(Facets.instance("Brazier%d" % index, st.commit(), Palette.toon(0.3, 0.12), at)))
	# Chama ambar facetada (brilho sobe a noite).
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint_fire := func(c: Vector3, _n: Vector3) -> Color:
		return Palette.AMBER.lerp(Color("ffd98a"), clampf((c.y - 1.5) / 0.6, 0.0, 1.0))
	for spec in [[Vector3(0, 0, 0), 0.22, 0.8], [Vector3(0.12, 0, 0.07), 0.13, 0.48], [Vector3(-0.11, 0, -0.06), 0.12, 0.42]]:
		var base: Vector3 = spec[0] + Vector3(0, 1.46, 0)
		var xf := Transform3D(Basis(), base)
		Facets.loft(st, [Facets.ring(5, spec[1], 0.0, rng, 0.1, rng.randf() * TAU, 0.0, xf),
			Facets.ring(5, spec[1] * 0.7, spec[2] * 0.4, rng, 0.15, rng.randf() * TAU, 0.0, xf)],
			base + Vector3(rng.randf_range(-0.04, 0.04), spec[2], 0), null, paint_fire)
	var flame := _on_solid(Facets.instance("Flame%d" % index, st.commit(), Palette.toon_glow(Palette.AMBER, 0.4, 0.3), at, false))
	flame.set_meta("glow", Vector2(1.1, 2.4))
	root.add_child(flame)

# --- Estandartes (sobre os solidos BannerPole, r 0,075) -------------------------
# Tecido centrado no mastro (T de estandarte), voltado para a camera (+z).
static func _banner(root: Node3D, at: Vector3, index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17070 + index
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint_wood := func(c: Vector3, n: Vector3) -> Color:
		if c.y > 3.5:
			return Facets.facet_shade(Palette.JADE, n) # ponta de jade
		return Facets.by_height([Palette.WOOD, Palette.WOOD, Palette.WOOD_DARK], n, c.y, 0.0, 1.2, float(index))
	Facets.loft(st, [Facets.ring(6, 0.09, -0.02, rng, 0.0), Facets.ring(6, 0.075, 3.4, rng, 0.0)], true, null, paint_wood)
	Facets.loft(st, [Facets.ring(4, 0.08, 3.4, rng, 0.0), Facets.ring(4, 0.12, 3.55, rng, 0.0)], Vector3(0, 3.85, 0), null, paint_wood)
	# Travessa.
	var lo := PackedVector3Array()
	var hi := PackedVector3Array()
	for q in [Vector2(-0.52, 0.06), Vector2(-0.52, 0.14), Vector2(0.52, 0.14), Vector2(0.52, 0.06)]:
		lo.append(Vector3(q.x, 3.18, q.y))
		hi.append(Vector3(q.x, 3.27, q.y))
	Facets.loft(st, [lo, hi], true, true, paint_wood)
	# Tecido em 4 faixas com leve ondulacao e cauda bifurcada.
	var xs := [-0.44, -0.22, 0.0, 0.22, 0.44]
	var zs := [0.16, 0.2, 0.15, 0.2, 0.16]
	var bottom := [1.55, 1.7, 1.95, 1.7, 1.55]
	var top := 3.17
	for i in 4:
		var col: Color = Palette.JADE if i in [1, 2] else Palette.JADE_DARK
		var paint_cloth := func(_c: Vector3, n: Vector3) -> Color:
			return Facets.facet_shade(col, n)
		var a := Vector3(xs[i], top, zs[i])
		var b := Vector3(xs[i + 1], top, zs[i + 1])
		var c := Vector3(xs[i + 1], bottom[i + 1], zs[i + 1])
		var d := Vector3(xs[i], bottom[i], zs[i])
		Facets.tri(st, a, b, c, Vector3(0, 0, 1), paint_cloth)
		Facets.tri(st, a, c, d, Vector3(0, 0, 1), paint_cloth)
	# Emblema: losango ambar com miolo jade claro, logo a frente do tecido.
	for q in [[0.3, 0.2, 0.22, Palette.AMBER], [0.14, 0.09, 0.225, Palette.JADE_LIGHT]]:
		var e := Vector3(0, 2.55, q[2])
		var up := Vector3(0, q[0], 0)
		var rt := Vector3(q[1], 0, 0)
		var emblem_col: Color = q[3]
		var paint_emblem := func(_c: Vector3, _n: Vector3) -> Color:
			return emblem_col
		Facets.tri(st, e + up, e + rt, e - up, Vector3(0, 0, 1), paint_emblem)
		Facets.tri(st, e + up, e - up, e - rt, Vector3(0, 0, 1), paint_emblem)
	root.add_child(_on_solid(Facets.instance("Banner%d" % index, st.commit(), Palette.toon_double(0.3), at)))

# --- Moldura da area de construcao (BuildZone 8 x 10 m), rente ------------------
static func _build_frame(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17080
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := Layout.BUILD_ZONE_SIZE * 0.5 - Vector2(0.12, 0.12)
	var c := Layout.BUILD_ZONE
	var corners := [c + Vector2(-half.x, -half.y), c + Vector2(half.x, -half.y), c + Vector2(half.x, half.y), c + Vector2(-half.x, half.y)]
	var paint_wood := func(f: Vector3, n: Vector3) -> Color:
		if f.y > 0.11 and n.y > 0.7:
			return Palette.AMBER # ponta das estacas: "aqui se constroi"
		var k := _hash(Vector2(snappedf(f.x, 0.9), snappedf(f.z, 0.9)))
		return Facets.facet_shade(Palette.WOOD.lerp(Palette.WOOD_DARK, 0.2 + 0.5 * k), n)
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var length := a.distance_to(b)
		var dir := (b - a) / length
		# Aberturas: o meio de cada lado; no lado oeste, a passagem do Refugio
		# (z de -16,3 a -12,9, onde fica o braseiro leste).
		var hole := Vector2(length * 0.5 - 0.9, length * 0.5 + 0.9)
		if absf(a.x - b.x) < 0.01 and a.x < c.x:
			var s0 := (-16.3 - a.y) / dir.y
			var s1 := (-12.9 - a.y) / dir.y
			hole = Vector2(minf(s0, s1), maxf(s0, s1))
		for piece: Vector2 in [Vector2(0.0, hole.x), Vector2(hole.y, length)]:
			var s := piece.x
			while s < piece.y - 0.2: # tabuas de ~1,4 m com juntas
				var e := minf(s + rng.randf_range(1.2, 1.6), piece.y)
				var p0 := a + dir * (s + 0.03)
				var p1 := a + dir * (e - 0.03)
				var side := dir.orthogonal() * 0.09
				var lo := PackedVector3Array()
				var hi := PackedVector3Array()
				var h := rng.randf_range(0.08, 0.1)
				for q in [p0 - side, p1 - side, p1 + side, p0 + side]:
					lo.append(Vector3(q.x, -0.01, q.y))
					hi.append(Vector3(q.x, h, q.y))
				Facets.loft(st, [lo, hi], true, null, paint_wood)
				s = e
	# Estacas curtas nos cantos (ate 0,14 m) com ponta ambar.
	for p: Vector2 in corners:
		var xf := Transform3D(Basis(), Vector3(p.x, 0, p.y))
		Facets.loft(st, [Facets.ring(5, 0.1, -0.01, rng, 0.0, 0.0, 0.0, xf), Facets.ring(5, 0.08, 0.12, rng, 0.0, 0.0, 0.0, xf)], Vector3(p.x, 0.14, p.y), null, paint_wood)
	root.add_child(Facets.instance("BuildFrame", st.commit(), Palette.toon(0.3, 0.05), Vector3.ZERO, false))

# --- Torre de vigia jade alem do paredao sul (fora da area jogavel) -------------
static func _watchtower(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17090
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tones := [Palette.STONE_LIGHT, Palette.STONE, Palette.STONE_DARK]
	var paint := func(c: Vector3, n: Vector3) -> Color:
		if c.y > 7.25:
			return Facets.facet_shade(Palette.JADE_DARK.lerp(Palette.JADE, clampf((c.y - 7.3) / 2.0, 0.0, 1.0)), n)
		return Facets.by_height(tones, n, c.y, 0.0, 7.2, 1.0)
	Facets.loft(st, [
		Facets.ring(7, 1.7, -0.5, rng, 0.05),
		Facets.ring(7, 1.35, 6.4, rng, 0.04, 0.05),
		Facets.ring(7, 1.55, 6.9, rng, 0.03, 0.05),
		Facets.ring(7, 1.4, 7.25, rng, 0.02, 0.05),
	], true, null, paint)
	Facets.loft(st, [Facets.ring(7, 1.95, 7.25, rng, 0.03, 0.2), Facets.ring(7, 1.25, 8.1, rng, 0.03, 0.25)], Vector3(0.05, 9.9, 0), null, paint)
	root.add_child(Facets.instance("Watchtower", st.commit(), Palette.toon(0.3, 0.12), WATCHTOWER))
	# Janela ambar voltada para o vale: acende a noite ("alguem vigia").
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint_win := func(_c: Vector3, _n: Vector3) -> Color:
		return Palette.AMBER
	var w := Vector3(0, 5.4, 1.38)
	var front := PackedVector3Array([w + Vector3(0, 0.45, 0), w + Vector3(0.25, 0, 0), w + Vector3(0, -0.45, 0), w + Vector3(-0.25, 0, 0)])
	var back := PackedVector3Array()
	for v in front:
		back.append(v + Vector3(0, 0, 0.05))
	Facets.loft(st, [front, back], true, null, paint_win)
	var window := Facets.instance("WatchtowerWindow", st.commit(), Palette.toon_glow(Palette.AMBER, 0.3, 0.0), WATCHTOWER, false)
	window.set_meta("glow", Vector2(0.15, 1.8))
	root.add_child(window)
