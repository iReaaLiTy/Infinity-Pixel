extends RefCounted

# Spec 018 — malhas facetadas da natureza do vale, em tamanho UNITARIO (cabem
# nas malhas antigas: cilindro r 0,5 x h 1, esfera r 0,5). O gerador do mapa
# troca so a malha e o material dos nos existentes (transform intacto: colisoes,
# navmesh e testes de layout continuam iguais). Os coletaveis usam as mesmas
# familias, com cores proprias para nao se confundirem com a decoracao.
# Malhas sao imutaveis: o cache estatico so evita refazer a mesma malha.

const Palette := preload("res://scenes/visuals/palette.gd")
const Facets := preload("res://scenes/visuals/facets.gd")

## Especies: copa larga redonda, pinheiro em camadas, arvore-jade alta.
enum Kind { BROADLEAF, PINE, JADE }
const LEAVES := {
	Kind.BROADLEAF: [Color("5d9a6a"), Color("447f58"), Color("2f5e48")],
	Kind.PINE: [Color("4a8a72"), Color("336e5c"), Color("234c42")],
	Kind.JADE: [Color("6cb293"), Color("4f9479"), Color("356a59")],
}
## Coletavel: copa mais quente (amarelo-esverdeada), le "da para lenhar".
const HARVEST_LEAVES := [Color("a3b65a"), Color("7f9a45"), Color("587434")]
const ROCK := [Color("a6a99c"), Color("858a7f"), Color("62675f")]
const MOSS := Color("5f8a4e")

static var _cache := {}

static func _commit(key: String, build: Callable) -> ArrayMesh:
	if not _cache.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		build.call(st)
		_cache[key] = st.commit()
	return _cache[key]

## Material compartilhado (cor vem dos vertices).
static var _toon: StandardMaterial3D
static func material() -> StandardMaterial3D:
	if _toon == null:
		_toon = Palette.toon(0.3, 0.14)
	return _toon

## Tronco unitario (cilindro r 0,5, y de -0,5 a 0,5), casca com veios.
static func trunk() -> ArrayMesh:
	return _commit("trunk", func(st: SurfaceTool) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1801
		var paint := func(c: Vector3, n: Vector3) -> Color:
			return Facets.by_height([Palette.WOOD, Palette.WOOD, Palette.WOOD_DARK], n, c.y, -0.5, 0.5, c.x * 3.0)
		Facets.loft(st, [
			Facets.ring(6, 0.5, -0.5, rng, 0.06),
			Facets.ring(6, 0.42, -0.2, rng, 0.06, 0.1),
			Facets.ring(6, 0.38, 0.5, rng, 0.05, 0.2),
		], true, null, paint))

## Copa unitaria (dentro de uma esfera r 0,5). `layer` 0 = baixa, 1 = alta.
static func crown(kind: int, layer: int, tones: Array = []) -> ArrayMesh:
	var cols: Array = tones if not tones.is_empty() else LEAVES[kind]
	var key := "crown_%d_%d_%s" % [kind, layer, str(cols[0])]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1810 + kind * 7 + layer
	var rings := []
	var top := Vector3(0.03, 0.5, 0)
	var bottom = Vector3(0, -0.5, 0)
	if kind == Kind.PINE: # cone em camada: a de cima mais estreita
		rings = [Facets.ring(7, 0.5, -0.42, rng, 0.08), Facets.ring(7, 0.42, -0.3, rng, 0.08, 0.2), Facets.ring(7, 0.2, 0.12, rng, 0.1, 0.4)]
		top = Vector3(0.02, 0.52, 0)
		bottom = true
	elif kind == Kind.JADE: # copa alta e ovalada, facetas grandes
		rings = [Facets.ring(6, 0.3, -0.46, rng, 0.1), Facets.ring(6, 0.5, -0.12, rng, 0.08, 0.5), Facets.ring(6, 0.44, 0.22, rng, 0.08, 1.0)]
		top = Vector3(0, 0.5, 0)
	else: # copa larga e redonda, irregular
		rings = [Facets.ring(8, 0.3, -0.42, rng, 0.12), Facets.ring(8, 0.5, -0.12, rng, 0.1, 0.3),
			Facets.ring(8, 0.46, 0.16, rng, 0.1, 0.6), Facets.ring(8, 0.26, 0.4, rng, 0.12, 0.9)]
	var paint := func(c: Vector3, n: Vector3) -> Color:
		return Facets.by_height(cols, n, c.y, -0.5, 0.45, float(kind * 3 + layer))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	Facets.loft(st, rings, top, bottom, paint)
	_cache[key] = st.commit()
	return _cache[key]

## Rocha unitaria (dentro de uma esfera r 0,5). `variant` muda forma e topo:
## 0 = musgo, 1 = liquen, 2 = nua.
static func rock(variant: int) -> ArrayMesh:
	return _commit("rock_%d" % variant, func(st: SurfaceTool) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1830 + variant * 11
		var top: Color = [MOSS, Palette.LICHEN, ROCK[0]][variant % 3]
		var paint := func(c: Vector3, n: Vector3) -> Color:
			if n.y > 0.72 and variant % 3 != 2:
				return Facets.facet_shade(top.lerp(ROCK[0], 0.25), n)
			return Facets.by_height(ROCK, n, c.y, -0.45, 0.4, c.x + c.z + variant)
		Facets.loft(st, [
			Facets.ring(7, 0.4, -0.48, rng, 0.12),
			Facets.ring(7, 0.5, -0.15, rng, 0.12, 0.3, 0.05),
			Facets.ring(7, 0.42, 0.2, rng, 0.14, 0.6, 0.06),
			Facets.ring(7, 0.24, 0.42, rng, 0.16, 0.9, 0.03),
		], true, true, paint))

## Pedra coletavel: bloco facetado com cristais de minerio (azul e ambar)
## saindo da rocha. Base no chao (y = 0), ~1,7 x 1,15 x 1,5 m como a antiga.
static func ore_stone() -> ArrayMesh:
	return _commit("ore", func(st: SurfaceTool) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1850
		var dark := [Color("9aa3a8"), Color("78828a"), Color("565e66")]
		var paint := func(c: Vector3, n: Vector3) -> Color:
			return Facets.by_height(dark, n, c.y, 0.0, 1.1, c.x + c.z)
		var xf := Transform3D(Basis.from_scale(Vector3(1.7, 1.0, 1.5)), Vector3.ZERO)
		Facets.loft(st, [
			Facets.ring(7, 0.42, -0.02, rng, 0.1, 0.0, 0.0, xf),
			Facets.ring(7, 0.5, 0.35, rng, 0.1, 0.3, 0.05, xf),
			Facets.ring(7, 0.4, 0.8, rng, 0.12, 0.6, 0.05, xf),
			Facets.ring(7, 0.2, 1.08, rng, 0.14, 0.9, 0.02, xf),
		], true, null, paint)
		for spec in [[Vector3(0.35, 0.7, 0.45), Color("7fa6d6"), 0.5], [Vector3(-0.5, 0.6, 0.25), Palette.AMBER, -0.6],
				[Vector3(0.05, 0.95, -0.35), Color("7fa6d6"), 0.2], [Vector3(-0.15, 0.8, 0.55), Palette.AMBER, -0.2]]:
			var col: Color = spec[1]
			var paint_gem := func(_c: Vector3, n: Vector3) -> Color:
				return Facets.facet_shade(col.lightened(0.1), n) if n.y > 0.3 else col.darkened(0.15)
			var at := Transform3D(Basis(Vector3(0, 0, 1), spec[2]), spec[0])
			Facets.loft(st, [Facets.ring(4, 0.11, -0.1, rng, 0.05, 0.0, 0.0, at), Facets.ring(4, 0.1, 0.12, rng, 0.05, 0.3, 0.0, at)],
				at * Vector3(0, 0.36, 0), null, paint_gem))

## Arvore coletavel: tronco com corte claro de machado (y de 0 a 2,2).
static func harvest_trunk() -> ArrayMesh:
	return _commit("harvest_trunk", func(st: SurfaceTool) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1860
		var paint := func(c: Vector3, n: Vector3) -> Color:
			if c.y > 0.62 and c.y < 0.9 and n.z > 0.5:
				return Color("e2c48f") # corte de machado: madeira clara
			return Facets.by_height([Palette.WOOD, Palette.WOOD, Palette.WOOD_DARK], n, c.y, 0.0, 2.2, c.x * 3.0)
		Facets.loft(st, [
			Facets.ring(6, 0.34, -0.02, rng, 0.05),
			Facets.ring(6, 0.3, 0.62, rng, 0.04, 0.1),
			Facets.ring(6, 0.22, 0.75, rng, 0.0, 0.1),
			Facets.ring(6, 0.3, 0.9, rng, 0.04, 0.1),
			Facets.ring(6, 0.25, 2.2, rng, 0.05, 0.2),
		], true, null, paint))
