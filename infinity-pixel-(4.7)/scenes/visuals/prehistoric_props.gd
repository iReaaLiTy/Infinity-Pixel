extends RefCounted

# Visual Overhaul 3.0 — adereços "Expedição Pré-histórica": pegadas fossilizadas,
# ossada de costelas, cranio, totem de dinossauro e rocha com amonite. Malhas
# facetadas com cor por face (material toon da Spec 017A), geradas uma vez e
# compartilhadas (cache). Sem colisao: so arte. Quem posiciona decide onde
# (nunca em cima de caminho andavel com algo acima de 0,3 m).

const Facets := preload("res://scenes/visuals/facets.gd")
const Palette := preload("res://scenes/visuals/palette.gd")
const Forge := preload("res://scenes/visuals/creature_forge.gd")

const BONE := Color("e8dfca")
const BONE_SHADE := Color("b9ab8c")
const BONE_DARK := Color("8a7c62")
const PRINT := Color("7a5a36")
const PRINT_RIM := Color("b48e5c")

static var _meshes := {}
static var _mat: StandardMaterial3D

static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = Palette.toon(0.25, 0.15)
	return _mat

static func _cached(key: String, build: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = build.call()
	return _meshes[key]

static func _node(label: String, mesh: Mesh, pos: Vector3, yaw: float, shadow := true) -> MeshInstance3D:
	var mi := Facets.instance(label, mesh, material(), pos, shadow)
	mi.rotation.y = yaw
	return mi

static func _bone_paint(c: Vector3, n: Vector3) -> Color:
	var col := BONE.lerp(BONE_SHADE, clampf(0.6 - c.y * 0.8, 0.0, 1.0))
	return Facets.facet_shade(col, n)

# ---------------------------------------------------------------------------

## Pegada fossilizada de tres dedos, rente ao chao (0,05 m), ~0,6 m.
static func footprint(pos: Vector3, yaw: float) -> MeshInstance3D:
	var mesh := _cached("print", func():
		var st := Forge.begin()
		var up := Vector3.UP
		var rim := func(_c: Vector3, _n: Vector3) -> Color: return PRINT_RIM
		var deep := func(_c: Vector3, _n: Vector3) -> Color: return PRINT
		# calcanhar (octogono) com borda clara e fundo escuro
		var heel := PackedVector3Array()
		for i in 8:
			var a := TAU * i / 8.0
			heel.append(Vector3(cos(a) * 0.14, 0, 0.12 + sin(a) * 0.12))
		for i in 8:
			Facets.tri(st, Vector3(0, 0, 0.12), heel[i], heel[(i + 1) % 8], up, deep)
		for k in [-1.0, 0.0, 1.0]:
			var dir := Vector3(0, 0, -1).rotated(Vector3.UP, k * 0.5)
			var side := dir.cross(Vector3.UP).normalized()
			var base := Vector3(0, 0, 0.08) + dir * 0.06
			var length := 0.36 if k == 0.0 else 0.28
			Facets.tri(st, base + side * 0.07, base + dir * length, base - side * 0.07, up, deep)
			Facets.tri(st, base + side * 0.1, base + dir * (length + 0.05), base + side * 0.07, up, rim)
			Facets.tri(st, base - side * 0.07, base + dir * (length + 0.05), base - side * 0.1, up, rim)
		return st.commit())
	return _node("FossilPrint", mesh, pos + Vector3(0, 0.05, 0), yaw, false)

## Ossada de costelas meio enterrada (~1 m de altura, ~2,4 m de comprimento).
static func ribcage(pos: Vector3, yaw: float) -> MeshInstance3D:
	var mesh := _cached("ribs", func():
		var st := Forge.begin()
		var paint := func(c: Vector3, n: Vector3) -> Color: return _bone_paint(c, n)
		# coluna (vertebras = aneis grossos) quase no chao
		Forge.tube(st, [Vector3(-1.3, 0.12, 0), Vector3(0, 0.22, 0), Vector3(1.1, 0.15, 0)], [0.09, 0.11, 0.07], paint, 6, false)
		for i in 7:
			var x := -0.95 + i * 0.32
			var h := 0.95 - absf(i - 2.5) * 0.12
			for s in [-1.0, 1.0]:
				var pts := []
				for k in 6:
					var t := k / 5.0
					var a := t * PI * 0.62
					pts.append(Vector3(x + t * 0.12, 0.2 + sin(a) * h, s * (0.12 + sin(a * 0.9) * 0.55 * (1.0 - t * 0.35))))
				Forge.tube(st, pts, [0.05, 0.045, 0.04, 0.035, 0.028, 0.02], paint, 5)
		# vertebras
		for i in 9:
			var v := Vector3(-1.15 + i * 0.27, 0.3, 0)
			Forge.tube(st, [v, v + Vector3(0.02, 0.14, 0)], [0.055, 0.03], paint, 5)
		return st.commit())
	return _node("FossilRibs", mesh, pos, yaw)

## Cranio de teropode caido de lado (~1,1 m), com orbita escura e dentes.
static func skull(pos: Vector3, yaw: float) -> MeshInstance3D:
	var mesh := _cached("skull", func():
		var st := Forge.begin()
		var paint := func(c: Vector3, n: Vector3) -> Color:
			var socket := Vector2(c.x - 0.12, c.y - 0.42).length() < 0.11 and n.z > 0.2
			return Facets.facet_shade(BONE_DARK if socket else BONE.lerp(BONE_SHADE, 0.3), n)
		var rings := [
			Forge.ring_z(0.35, 0.36, 0.2, 0.22, 7), Forge.ring_z(0.2, 0.4, 0.27, 0.26, 7, 0.8),
			Forge.ring_z(-0.05, 0.36, 0.22, 0.2, 7, 0.75), Forge.ring_z(-0.3, 0.3, 0.16, 0.15, 7, 0.75),
			Forge.ring_z(-0.5, 0.25, 0.11, 0.1, 7)]
		Facets.loft(st, rings, Vector3(0, 0.22, -0.6), true, paint)
		Forge.tube(st, [Vector3(0, 0.12, 0.3), Vector3(0, 0.08, -0.1), Vector3(0, 0.12, -0.5)], [0.12, 0.09, 0.05], paint, 6, false, 0.6)
		for i in 5:
			var z := 0.1 - i * 0.13
			for s in [-1.0, 1.0]:
				Forge.tube(st, [Vector3(s * 0.15 * (1.0 - i * 0.12), 0.2, z), Vector3(s * 0.14 * (1.0 - i * 0.12), 0.1, z - 0.02)], [0.025, 0.006], paint, 4)
		return st.commit())
	var mi := _node("FossilSkull", mesh, pos, yaw)
	mi.rotation.z = 0.35 # caido de lado
	return mi

## Totem de madeira com cabeca de dinossauro entalhada e gema jade (~2,3 m).
static func totem(pos: Vector3, yaw: float) -> MeshInstance3D:
	var mesh := _cached("totem", func():
		var st := Forge.begin()
		var wood := func(c: Vector3, n: Vector3) -> Color:
			var band := int(floor(c.y * 4.0)) % 2 == 0
			return Facets.facet_shade((Palette.WOOD if band else Palette.WOOD_DARK), n)
		var jade := func(_c: Vector3, n: Vector3) -> Color: return Facets.facet_shade(Palette.JADE_LIGHT, n)
		var bone := func(c: Vector3, n: Vector3) -> Color: return _bone_paint(c, n)
		Forge.tube(st, [Vector3(0, 0, 0), Vector3(0, 1.0, 0), Vector3(0, 1.75, 0)], [0.16, 0.14, 0.13], wood, 6, false)
		# cabeca entalhada (focinho para frente, -Z)
		var rings := [Forge.ring_z(0.18, 1.86, 0.17, 0.17, 6), Forge.ring_z(-0.02, 1.9, 0.2, 0.19, 6, 0.8),
			Forge.ring_z(-0.25, 1.86, 0.15, 0.13, 6, 0.8), Forge.ring_z(-0.42, 1.82, 0.1, 0.09, 6)]
		Facets.loft(st, rings, Vector3(0, 1.8, -0.5), true, wood)
		for s in [-1.0, 1.0]:
			Forge.tube(st, [Vector3(s * 0.12, 2.0, 0.05), Vector3(s * 0.2, 2.18, 0.15), Vector3(s * 0.22, 2.3, 0.3)], [0.04, 0.03, 0.01], bone, 5)
		# gema jade no peito do totem e dois ossos pendurados
		Forge.tube(st, [Vector3(0, 1.3, -0.2), Vector3(0, 1.42, -0.18)], [0.08, 0.06], jade, 4)
		for s in [-1.0, 1.0]:
			Forge.tube(st, [Vector3(s * 0.15, 1.55, -0.05), Vector3(s * 0.2, 1.25, -0.08)], [0.03, 0.025], bone, 4, false)
		return st.commit())
	return _node("DinoTotem", mesh, pos, yaw)

## Rocha com amonite em relevo numa das faces (~0,7 m).
static func ammonite_rock(pos: Vector3, yaw: float) -> MeshInstance3D:
	var mesh := _cached("ammonite", func():
		var st := Forge.begin()
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		var stone := func(c: Vector3, n: Vector3) -> Color: return Facets.by_height([Palette.CLIFF_LIGHT, Palette.CLIFF, Palette.CLIFF_DARK], n, c.y, 0.0, 0.7, c.x * 3.1 + c.z)
		var rings := [Facets.ring(7, 0.5, 0.0, rng, 0.12), Facets.ring(7, 0.46, 0.35, rng, 0.14, 0.3), Facets.ring(7, 0.3, 0.62, rng, 0.15, 0.1)]
		Facets.loft(st, rings, true, null, stone)
		var shell := func(c: Vector3, n: Vector3) -> Color: return Facets.facet_shade(BONE.lerp(Palette.AMBER, 0.25), n)
		var pts := []
		var radii := []
		for i in 14:
			var t := i / 13.0
			var a := t * TAU * 1.8
			var r := 0.04 + 0.2 * t
			pts.append(Vector3(cos(a) * r, 0.33 + sin(a) * r, -0.47 - 0.02 * t))
			radii.append(0.018 + 0.02 * t)
		Forge.tube(st, pts, radii, shell, 4, false)
		return st.commit())
	return _node("AmmoniteRock", mesh, pos, yaw)

# ---------------------------------------------------------------------------
# Versoes BAIXAS para o vale (Fase F): nada passa de 0,28 m, entao podem ficar
# em area andavel sem sugerir obstaculo (regra dos 0,3 m da Spec 017A). Sem
# colisao. Tudo vai para UMA malha (FossilArt) para custar uma chamada de desenho.
# ---------------------------------------------------------------------------

## Laje com um esqueleto de teropode em relevo (sitio fossil), ~3 x 1,6 m.
static func fossil_slab_mesh() -> Mesh:
	return _cached("slab", func():
		var st := Forge.begin()
		var rng := RandomNumberGenerator.new()
		rng.seed = 31
		var stone := func(c: Vector3, n: Vector3) -> Color: return Facets.by_height([Palette.STONE_LIGHT, Palette.STONE, Palette.STONE_DARK], n, c.y, 0.0, 0.12, c.x + c.z)
		var xf := Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.55)), Vector3.ZERO)
		Facets.loft(st, [Facets.ring(9, 1.55, -0.02, rng, 0.1, 0.0, 0.0, xf), Facets.ring(9, 1.45, 0.1, rng, 0.08, 0.0, 0.0, xf)], true, null, stone)
		var bone := func(c: Vector3, n: Vector3) -> Color: return _bone_paint(c + Vector3(0, 0.4, 0), n)
		# coluna em curva, do cranio a ponta da cauda
		var spine := []
		var radii := []
		for i in 9:
			var t := i / 8.0
			spine.append(Vector3(-1.05 + t * 2.1, 0.13, sin(t * PI * 1.2) * 0.22 - 0.05))
			radii.append(0.045 * (1.0 - t * 0.6))
		Forge.tube(st, spine, radii, bone, 4, false, 0.5)
		# costelas achatadas
		for k in 5:
			var p: Vector3 = spine[2 + k] if k < 5 else spine[6]
			for s in [-1.0, 1.0]:
				Forge.tube(st, [p, p + Vector3(0.06, 0.0, s * 0.3), p + Vector3(0.14, 0.0, s * 0.42)], [0.03, 0.025, 0.012], bone, 4, true, 0.5)
		# cranio achatado e pernas
		var head: Vector3 = spine[0]
		Forge.tube(st, [head + Vector3(0.05, 0, 0), head + Vector3(-0.32, 0, 0.06)], [0.12, 0.05], bone, 5, true, 0.45)
		for s in [-1.0, 1.0]:
			var hip: Vector3 = spine[5]
			Forge.tube(st, [hip, hip + Vector3(0.1, 0, s * 0.3), hip + Vector3(-0.05, 0, s * 0.55)], [0.04, 0.035, 0.02], bone, 4, true, 0.5)
		return st.commit())

## Costelas meio enterradas (arco baixo, 0,26 m), em par.
static func low_ribs_mesh() -> Mesh:
	return _cached("low_ribs", func():
		var st := Forge.begin()
		var bone := func(c: Vector3, n: Vector3) -> Color: return _bone_paint(c + Vector3(0, 0.35, 0), n)
		for i in 4:
			var x := -0.4 + i * 0.27
			var pts := []
			for k in 6:
				var t := k / 5.0
				pts.append(Vector3(x + t * 0.08, -0.04 + sin(t * PI) * (0.26 - absf(i - 1.5) * 0.03), (t - 0.5) * 0.9))
			Forge.tube(st, pts, [0.04, 0.038, 0.035, 0.035, 0.038, 0.04], bone, 5, false)
		return st.commit())

## Pedra chata com amonite em relevo (0,15 m).
static func ammonite_slab_mesh() -> Mesh:
	return _cached("ammonite_slab", func():
		var st := Forge.begin()
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var stone := func(c: Vector3, n: Vector3) -> Color: return Facets.by_height([Palette.CLIFF_LIGHT, Palette.CLIFF, Palette.CLIFF_DARK], n, c.y, 0.0, 0.12, c.x * 2.0 + c.z)
		Facets.loft(st, [Facets.ring(7, 0.42, -0.02, rng, 0.12), Facets.ring(7, 0.36, 0.1, rng, 0.1, 0.2)], true, null, stone)
		var shell := func(c: Vector3, n: Vector3) -> Color: return Facets.facet_shade(BONE.lerp(Palette.AMBER, 0.25), n)
		var pts := []
		var radii := []
		for i in 14:
			var t := i / 13.0
			var a := t * TAU * 1.8
			var r := 0.03 + 0.2 * t
			pts.append(Vector3(cos(a) * r, 0.12, sin(a) * r))
			radii.append(0.014 + 0.016 * t)
		Forge.tube(st, pts, radii, shell, 4, false, 0.6)
		return st.commit())

static func footprint_mesh() -> Mesh:
	return footprint(Vector3.ZERO, 0.0).mesh
