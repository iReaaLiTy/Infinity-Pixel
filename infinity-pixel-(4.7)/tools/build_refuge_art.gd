extends SceneTree

# Spec 017A — gera scenes/visuals/refuge_art.tscn: so malhas, sem fisica.
# Pipeline: tools/build_first_map.gd chama generate() (esconde as malhas antigas
# substituidas e grava esta cena) -> build_collisions -> bake_navmesh. As duas
# ultimas etapas NAO precisam rodar de novo: nada aqui tem colisao.
# Sozinho: godot --headless --script res://tools/build_refuge_art.gd
#
# Etapa 2 (prototipo) cobre so: cristal do Refugio e um trecho do paredao sul.
# O ponto de defesa prototipo e montado por defense_slot.gd (style = "jade").
const Palette := preload("res://scenes/visuals/palette.gd")
const Facets := preload("res://scenes/visuals/facets.gd")
const OUT := "res://scenes/visuals/refuge_art.tscn"
const REFUGE := Vector3(0, 0, -15)
const RING_TOP := 0.425 # topo do RefugeRing (arena_art), onde o cristal se apoia
# Paredao sul: trecho que substitui BorderRidgeSouth_2..4 (x de -12 a 12).
# Fica todo ao sul do Boundary3 (z = -24,2): fora da area jogavel.
const WALL_X := Vector2(-12.6, 12.6)
const WALL_FRONT_Z := -25.5

func _initialize() -> void:
	generate()
	quit()

static func generate() -> void:
	var root := Node3D.new()
	root.name = "RefugeArt"
	root.set_script(load("res://scenes/visuals/refuge_art.gd"))
	_crystal(root)
	_south_wall(root)
	for child in root.get_children():
		child.owner = root
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, OUT) == OK)
	root.free()
	print("[017A] refuge_art.tscn: cristal do Refugio + paredao sul (prototipo)")

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

# --- Paredao sul (trecho) ------------------------------------------------------
# Colunas de rocha facetada em 2 fileiras (frente baixa, fundo alto) com o topo
# coberto de vegetacao. Substitui as bolhas lisas BorderRidgeSouth_2..4.
static func _south_wall(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 25017
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tones := [Palette.CLIFF_LIGHT, Palette.CLIFF, Palette.CLIFF_DARK]
	var rows := [
		{"z": WALL_FRONT_Z, "step": 1.85, "r": Vector2(1.0, 1.3), "h": Vector2(2.0, 3.2)},
		{"z": WALL_FRONT_Z - 2.3, "step": 2.3, "r": Vector2(1.3, 1.7), "h": Vector2(3.6, 5.0)},
		{"z": WALL_FRONT_Z - 4.8, "step": 2.9, "r": Vector2(1.6, 2.1), "h": Vector2(5.0, 6.6)},
	]
	for row in rows:
		var x: float = WALL_X.x + rng.randf_range(0.0, 0.6)
		while x <= WALL_X.y:
			var r := rng.randf_range(row.r.x, row.r.y)
			var h := rng.randf_range(row.h.x, row.h.y)
			var c := Vector3(x, 0, row.z + rng.randf_range(-0.35, 0.35))
			var sides := rng.randi_range(5, 7)
			var phase := rng.randf() * TAU
			var shade := rng.randf_range(-0.06, 0.06) # 3 tons + variacao por coluna
			var tilt := Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.1, 0.3))
			var top_y := func(p: Vector3) -> float: return h + tilt.x * (p.x - c.x) + tilt.y * (p.z - c.z)
			var paint := func(f: Vector3, n: Vector3) -> Color:
				var col: Color
				if n.y > 0.55:
					col = Facets.facet_shade(Palette.CLIFF_TOP.lerp(Palette.GRASS_MID, 0.35 * absf(sin(f.x * 3.1))), n)
				elif f.y > top_y.call(f) - 0.22:
					col = Facets.facet_shade(Palette.CLIFF_TOP.darkened(0.25), n) # beirada do musgo
				else:
					col = Facets.by_height(tones, n, f.y, 0.0, h, c.x)
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
			x += row.step * rng.randf_range(0.85, 1.15)
	# Entulho no pe do paredao (ainda ao sul do Boundary3).
	for i in 9:
		var p := Vector3(lerpf(WALL_X.x + 1.0, WALL_X.y - 1.0, i / 8.0) + rng.randf_range(-0.6, 0.6), 0, -24.75 + rng.randf_range(-0.15, 0.15))
		var s := rng.randf_range(0.28, 0.5)
		var paint_rock := func(f: Vector3, n: Vector3) -> Color:
			return Facets.by_height(tones, n, f.y, 0.0, s * 1.4, f.x)
		var rr := []
		for spec in [[-0.05, 1.0], [s * 0.6, 0.9]]:
			var ring := Facets.ring(5, s * spec[1], spec[0], rng, 0.2, rng.randf() * TAU, 0.05)
			for k in ring.size():
				ring[k] += p
			rr.append(ring)
		Facets.loft(st, rr, p + Vector3(rng.randf_range(-0.1, 0.1), s * 1.05, 0), null, paint_rock)
	var wall := Facets.instance("SouthWall", st.commit(), Palette.toon(0.3, 0.1))
	root.add_child(wall)
