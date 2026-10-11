extends RefCounted

# Visual Overhaul 4.0 — flora e rochas do vale, em coordenadas de MUNDO. Cada
# funcao acrescenta triangulos facetados (cor por vertice) a um SurfaceTool:
# tools/build_flora_art.gd junta tudo em poucos blocos por regiao (uma malha
# por bloco, um material), em vez de um no por tronco, copa, rocha e samambaia.
#
# Especies (identidade pre-historica, silhuetas distintas vistas de cima):
#  - ARAUCARIA: tronco reto e alto, galhos em verticilos com tufos — estrela
#    em camadas. Floresta Oeste e bordas.
#  - CONIFER: saias pendentes empilhadas, verde-azulado. Floresta Oeste.
#  - BROADLEAF: tronco que bifurca e copa de lobos irregulares. Campina.
#  - JADE: lobos em gota apontando para cima, tons jade. Molduram o Refugio.
#  - TREE_FERN: samambaia-arborescente, frondes arqueadas. Floresta Oeste.
# Regra do vale: na area andavel, nada entre 0,3 m e 1,9 m fora do solido de
# um tronco ou rocha — as copas comecam acima de 1,9 m, o sub-bosque e rente.

const Palette := preload("res://scenes/visuals/palette.gd")
const Facets := preload("res://scenes/visuals/facets.gd")

enum Kind { BROADLEAF, CONIFER, JADE, ARAUCARIA, TREE_FERN }

## Altura minima das copas na area andavel (acima de criaturas e do Player).
const CANOPY_FLOOR := 1.9

const BARK := [Color("8f6a48"), Color("6e4f36"), Color("4a3424")]
const BARK_FERN := [Color("7a5a3e"), Color("5a4030"), Color("3a2a20")]
const LEAVES := {
	Kind.BROADLEAF: [Color("6aa765"), Color("4d8a55"), Color("336345")],
	Kind.CONIFER: [Color("4f8f7c"), Color("37705f"), Color("244c43")],
	Kind.JADE: [Color("7cc4a0"), Color("57a283"), Color("3a765f")],
	Kind.ARAUCARIA: [Color("5d9a72"), Color("427b5c"), Color("2b5545")],
	Kind.TREE_FERN: [Color("78b06a"), Color("5a9156"), Color("3d6b44")],
}
const MOSS := [Color("6f9a52"), Color("557f45"), Color("3d6338")]
const CRYSTAL := [Color("b8f0d6"), Color("6fcfa6"), Color("2f8f6c")]

# --- Utilidades -----------------------------------------------------------------

## Base com o eixo Y ao longo de `dir` (para aneis de galhos e frondes).
static func along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)

## Tom com variacao por individuo (claro/escuro e um leve desvio de matiz).
static func vary(tones: Array, rng: RandomNumberGenerator, amount := 0.07) -> Array:
	var k := rng.randf_range(-amount, amount)
	var hue := rng.randf_range(-0.012, 0.012)
	var out := []
	for c: Color in tones:
		var v := Color.from_hsv(fposmod(c.h + hue, 1.0), c.s, clampf(c.v * (1.0 + k), 0.0, 1.0))
		out.append(v)
	return out

## Galho/tronco curvo: pontos e raios; aneis alinhados a tangente.
static func limb(st: SurfaceTool, pts: Array, radii: Array, sides: int, rng: RandomNumberGenerator, tones: Array, tip = true, base = null, jitter := 0.08) -> void:
	var rings := []
	var phase := rng.randf() * TAU
	var y0: float = pts[0].y
	var y1: float = pts[pts.size() - 1].y
	for i in pts.size():
		var a: Vector3 = pts[maxi(0, i - 1)]
		var b: Vector3 = pts[mini(pts.size() - 1, i + 1)]
		var xf := Transform3D(along(b - a), pts[i])
		rings.append(Facets.ring(sides, radii[i], 0.0, rng, jitter, phase, 0.0, xf))
	var paint := func(c: Vector3, n: Vector3) -> Color:
		return Facets.by_height(tones, n, c.y, minf(y0, y1) - 0.2, maxf(y0, y1) + 0.4, c.x * 3.1 + c.z)
	Facets.loft(st, rings, tip, base, paint)

## Lobo de folhagem: bolha facetada (6-7 lados), base mais escura.
static func lobe(st: SurfaceTool, c: Vector3, r: float, h: float, rng: RandomNumberGenerator, tones: Array, sides := 7, point_up := 0.0) -> void:
	var rings := []
	var phase := rng.randf() * TAU
	for spec in [[-0.5, 0.5], [-0.15, 1.0], [0.22, 0.86 - point_up * 0.3]]:
		var ring := Facets.ring(sides, r * spec[1], h * spec[0], rng, 0.16, phase + spec[0], h * 0.04)
		for i in ring.size():
			ring[i] += c
		rings.append(ring)
	var top := c + Vector3(rng.randf_range(-0.05, 0.05) * r, h * (0.5 + point_up * 0.45), rng.randf_range(-0.05, 0.05) * r)
	var bottom := c + Vector3(0, -h * 0.62, 0)
	var y0 := c.y - h * 0.6
	var y1 := c.y + h * 0.55
	var paint := func(f: Vector3, n: Vector3) -> Color:
		# topo ao sol mais claro; a barriga do lobo escura (oclusao falsa)
		var col := Facets.by_height(tones, n, f.y, y0, y1, f.x * 1.7 + f.z * 0.9)
		return col.darkened(0.12) if n.y < -0.35 else col
	Facets.loft(st, rings, top, bottom, paint)

## Raizes que abracam a base do tronco (rentes: ate 0,26 m).
static func roots(st: SurfaceTool, base: Vector3, trunk_r: float, rng: RandomNumberGenerator, tones: Array, count := 5) -> void:
	var phase := rng.randf() * TAU
	for k in count:
		var a := phase + TAU * k / count + rng.randf_range(-0.25, 0.25)
		var dir := Vector3(cos(a), 0, sin(a))
		var reach := rng.randf_range(0.42, 0.68)
		var pts := [base + dir * (trunk_r * 0.55) + Vector3(0, 0.2, 0), base + dir * (trunk_r + reach * 0.45) + Vector3(0, 0.1, 0), base + dir * (trunk_r + reach) + Vector3(0, -0.02, 0)]
		limb(st, pts, [trunk_r * 0.42, trunk_r * 0.3, 0.035], 4, rng, tones, true, null)

## Tapete de musgo rente (anel irregular plano, 2-4 cm acima do chao).
static func moss_mat(st: SurfaceTool, c: Vector3, r: float, rng: RandomNumberGenerator, tones := MOSS) -> void:
	var ring := Facets.ring(8, r, 0.0, rng, 0.3, rng.randf() * TAU)
	var edge := PackedVector3Array()
	for v in ring:
		edge.append(c + v + Vector3(0, 0.012, 0))
	var mid := c + Vector3(0, 0.04, 0)
	var col: Color = tones[1]
	for i in edge.size():
		var j := (i + 1) % edge.size()
		var shade := 0.94 + 0.12 * fposmod(sin(float(i) * 7.3 + c.x) * 43.1, 1.0)
		var paint := func(_f: Vector3, n: Vector3) -> Color:
			return Facets.facet_shade(Color(col.r * shade, col.g * shade, col.b * shade), n)
		Facets.tri(st, edge[i], edge[j], mid, Vector3.UP, paint)

# --- Arvores --------------------------------------------------------------------
# `base` = pe do tronco no chao; `h` = altura do no antigo (2,8-3,7: as copas
# continuam na mesma faixa de altura, sem mudar a camera).

static func tree(st: SurfaceTool, kind: int, base: Vector3, h: float, rng: RandomNumberGenerator) -> void:
	match kind:
		Kind.CONIFER: conifer(st, base, h, rng)
		Kind.JADE: broadleaf(st, base, h, rng, true)
		Kind.ARAUCARIA: araucaria(st, base, h, rng)
		Kind.TREE_FERN: tree_fern(st, base, h, rng)
		_: broadleaf(st, base, h, rng, false)

static func _lean(rng: RandomNumberGenerator, amount: float) -> Vector3:
	var a := rng.randf() * TAU
	return Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.3, 1.0) * amount

## Campina (e Refugio com `jade`): tronco bifurcado, copa de 5-7 lobos.
static func broadleaf(st: SurfaceTool, base: Vector3, h: float, rng: RandomNumberGenerator, jade: bool) -> void:
	var bark := vary(BARK, rng, 0.05)
	var leaves := vary(LEAVES[Kind.JADE if jade else Kind.BROADLEAF], rng)
	# O tronco cabe no solido (capsula r 0,25): inclinacao pequena e galhos so
	# acima de 1,9 m.
	var lean := _lean(rng, 0.05)
	var fork := base + Vector3(0, maxf(h * 0.58, CANOPY_FLOOR + 0.05), 0) + lean
	limb(st, [base + Vector3(0, -0.05, 0), base + Vector3(0, 0.45, 0) + lean * 0.2, base + Vector3(0, fork.y * 0.6, 0) + lean * 0.5, fork], [0.25, 0.205, 0.19, 0.17], 7, rng, bark, true, null, 0.04)
	roots(st, base, 0.24, rng, bark, 5)
	var crown := base + Vector3(0, h * 0.86 + 0.25, 0) + lean * 1.4
	var limbs := rng.randi_range(2, 3)
	var spin := rng.randf() * TAU
	for k in limbs:
		var a := spin + TAU * k / limbs
		var out := Vector3(cos(a), 0, sin(a))
		var end := crown + out * 0.62 + Vector3(0, rng.randf_range(-0.15, 0.2), 0)
		limb(st, [fork, fork.lerp(end, 0.5) + Vector3(0, 0.25, 0), end], [0.15, 0.1, 0.06], 5, rng, bark, true, null)
	# Copa: um lobo alto no centro e uma coroa de lobos em volta (irregular).
	var big := rng.randf_range(1.0, 1.15)
	lobe(st, crown + Vector3(0, 0.45, 0), 0.95 * big, 1.25 * big, rng, leaves, 7, 0.35 if jade else 0.0)
	var count := rng.randi_range(5, 6)
	for k in count:
		var a := spin + 0.4 + TAU * k / count + rng.randf_range(-0.2, 0.2)
		var d := rng.randf_range(0.82, 1.08) * big
		var c := crown + Vector3(cos(a) * d, rng.randf_range(-0.12, 0.25), sin(a) * d)
		var r := rng.randf_range(0.6, 0.78) * big
		var hh := r * rng.randf_range(1.05, 1.3) * (1.25 if jade else 1.0)
		c.y = maxf(c.y, CANOPY_FLOOR + hh * 0.62 + 0.02) # barriga do lobo acima de 1,9 m
		lobe(st, c, r, hh, rng, leaves, 6, 0.55 if jade else 0.0)
	# (os cristais no pe da arvore-jade saem na malha que brilha: build_flora_art.gd)

## Floresta Oeste: saias pendentes empilhadas, verde-azulado.
static func conifer(st: SurfaceTool, base: Vector3, h: float, rng: RandomNumberGenerator) -> void:
	var bark := vary(BARK, rng, 0.05)
	var leaves := vary(LEAVES[Kind.CONIFER], rng)
	var lean := _lean(rng, 0.06)
	var top := base + Vector3(0, h + 0.9, 0) + lean
	limb(st, [base + Vector3(0, -0.05, 0), base + Vector3(0, 0.45, 0), base + Vector3(0, h * 0.5, 0) + lean * 0.5, top], [0.24, 0.2, 0.17, 0.05], 6, rng, bark, true, null, 0.04)
	roots(st, base, 0.22, rng, bark, 4)
	var tiers := 4
	var lowest := CANOPY_FLOOR + 0.25 # a borda da saia cai ate ~0,17 m
	for t in tiers:
		var k := float(t) / (tiers - 1)
		var y := lerpf(lowest, h + 0.35, k)
		var radius := lerpf(1.45, 0.55, k) * rng.randf_range(0.92, 1.08)
		var c := base + Vector3(0, y, 0) + lean * (y / (h + 0.9))
		_skirt(st, c, radius, lerpf(0.75, 0.6, k), rng, leaves)
	lobe(st, top + Vector3(0, -0.15, 0), 0.22, 0.6, rng, leaves, 5, 1.0)

## Saia de conifera: cone baixo de borda serrilhada que cai nas pontas.
static func _skirt(st: SurfaceTool, c: Vector3, r: float, h: float, rng: RandomNumberGenerator, tones: Array) -> void:
	var sides := 9
	var phase := rng.randf() * TAU
	var rim := PackedVector3Array()
	var mid := PackedVector3Array()
	for i in sides * 2:
		var a := phase + PI * i / sides
		var rr := r * (1.0 if i % 2 == 0 else 0.74) * rng.randf_range(0.93, 1.05)
		var drop := (0.12 if i % 2 == 0 else 0.0) + rng.randf_range(0.0, 0.05)
		rim.append(c + Vector3(cos(a) * rr, -drop, sin(a) * rr))
		mid.append(c + Vector3(cos(a) * rr * 0.55, h * 0.42, sin(a) * rr * 0.55))
	var tip := c + Vector3(0, h, 0)
	var under := c + Vector3(0, -0.02, 0)
	var y0 := c.y - 0.15
	var y1 := c.y + h
	var paint := func(f: Vector3, n: Vector3) -> Color:
		var col := Facets.by_height(tones, n, f.y, y0, y1, f.x + f.z * 1.3)
		return col.darkened(0.18) if n.y < 0.0 else col
	Facets.loft(st, [rim, mid], tip, under, paint)

## Araucaria: tronco alto e reto, verticilos de galhos com tufos nas pontas.
static func araucaria(st: SurfaceTool, base: Vector3, h: float, rng: RandomNumberGenerator) -> void:
	var bark := vary([Color("8a6b52"), Color("6b513d"), Color("463428")], rng, 0.05)
	var leaves := vary(LEAVES[Kind.ARAUCARIA], rng)
	var lean := _lean(rng, 0.05)
	var height := h + 0.75
	var top := base + Vector3(0, height, 0) + lean
	limb(st, [base + Vector3(0, -0.05, 0), base + Vector3(0, 0.45, 0), base + Vector3(0, height * 0.5, 0) + lean * 0.5, top], [0.25, 0.2, 0.17, 0.07], 6, rng, bark, true, null, 0.04)
	roots(st, base, 0.22, rng, bark, 5)
	var whorls := [[0.0, 1.35, 5], [0.42, 1.05, 5], [0.8, 0.66, 4]]
	var spin := rng.randf() * TAU
	for w in whorls.size():
		var spec: Array = whorls[w]
		var y := lerpf(CANOPY_FLOOR + 0.35, height - 0.25, spec[0])
		var trunk_at := base + Vector3(0, y, 0) + lean * (y / height)
		var n: int = spec[2]
		for k in n:
			var a := spin + w * 0.55 + TAU * k / n + rng.randf_range(-0.15, 0.15)
			var out := Vector3(cos(a), 0, sin(a))
			var reach: float = spec[1] * rng.randf_range(0.9, 1.08)
			var end := trunk_at + out * reach + Vector3(0, 0.22, 0)
			limb(st, [trunk_at, trunk_at + out * reach * 0.5 + Vector3(0, 0.02, 0), end], [0.07, 0.05, 0.03], 4, rng, bark, true, null)
			# tufo alongado na ponta, levemente erguido
			var tuft := end + out * 0.12 + Vector3(0, 0.08, 0)
			_spindle(st, tuft - out * 0.42, tuft + out * 0.3 + Vector3(0, 0.12, 0), 0.24, rng, leaves)
	lobe(st, top + Vector3(0, 0.05, 0), 0.42, 0.7, rng, leaves, 6, 0.6)

## Tufo alongado (fuso facetado) entre dois pontos.
static func _spindle(st: SurfaceTool, a: Vector3, b: Vector3, r: float, rng: RandomNumberGenerator, tones: Array) -> void:
	var basis := along(b - a)
	var length := a.distance_to(b)
	var rings := []
	var phase := rng.randf() * TAU
	for spec in [[0.18, 0.7], [0.5, 1.0], [0.8, 0.75]]:
		rings.append(Facets.ring(6, r * spec[1], length * spec[0], rng, 0.15, phase, 0.0, Transform3D(basis, a)))
	var y0 := minf(a.y, b.y) - r
	var y1 := maxf(a.y, b.y) + r
	var paint := func(f: Vector3, n: Vector3) -> Color:
		var col := Facets.by_height(tones, n, f.y, y0, y1, f.x * 2.3 + f.z)
		return col.darkened(0.15) if n.y < -0.3 else col
	Facets.loft(st, rings, b, a, paint)

## Samambaia-arborescente: tronco fibroso e frondes arqueadas.
static func tree_fern(st: SurfaceTool, base: Vector3, h: float, rng: RandomNumberGenerator) -> void:
	var bark := vary(BARK_FERN, rng, 0.05)
	var leaves := vary(LEAVES[Kind.TREE_FERN], rng)
	var lean := _lean(rng, 0.06)
	var height := h * 0.92 + 0.35
	var top := base + Vector3(0, height, 0) + lean
	var mid := base + Vector3(0, height * 0.5, 0) + lean * 0.3
	limb(st, [base + Vector3(0, -0.05, 0), base + Vector3(0, 0.4, 0), mid, top], [0.24, 0.19, 0.16, 0.2], 6, rng, bark, true, null, 0.04)
	# aneis de cicatrizes no tronco (textura da especie)
	for k in 3:
		var y := lerpf(0.5, height - 0.3, (k + 1) / 4.0)
		var c := base + Vector3(0, y, 0) + lean * (y / height)
		Facets.loft(st, [Facets.ring(6, 0.185, -0.04, rng, 0.03, 0.0, 0.0, Transform3D(Basis.IDENTITY, c)),
			Facets.ring(6, 0.185, 0.04, rng, 0.03, 0.0, 0.0, Transform3D(Basis.IDENTITY, c))], null, null,
			func(_f: Vector3, n: Vector3) -> Color: return Facets.facet_shade(bark[2], n))
	var count := rng.randi_range(9, 11)
	var spin := rng.randf() * TAU
	for k in count:
		var a := spin + TAU * k / count + rng.randf_range(-0.12, 0.12)
		var rise := rng.randf_range(0.25, 0.5)
		var length := rng.randf_range(1.35, 1.65)
		frond(st, top + Vector3(0, 0.05, 0), Vector3(cos(a), rise, sin(a)), length, 0.24, maxf(top.y - CANOPY_FLOOR - 0.05, 0.4), rng, leaves, 4, true)
	# broto enrolado no alto
	lobe(st, top + Vector3(0, 0.12, 0), 0.14, 0.26, rng, leaves, 5, 0.6)

## Fronde: tira arqueada com foliolos serrilhados (duas faces). `sag` = quanto
## a ponta pode cair abaixo da origem.
static func frond(st: SurfaceTool, origin: Vector3, dir: Vector3, length: float, width: float, sag: float, rng: RandomNumberGenerator, tones: Array, segs := 4, both_faces := false) -> void:
	var d := Vector3(dir.x, 0, dir.z).normalized()
	var side := Vector3(-d.z, 0, d.x)
	var spine := []
	for i in segs + 1:
		var t := float(i) / segs
		var up := dir.y * length * t - (dir.y * length + sag) * t * t
		spine.append(origin + d * length * t + Vector3(0, up, 0))
	var faces := [Vector3.UP, Vector3.DOWN] if both_faces else [Vector3.UP]
	for i in segs:
		var a: Vector3 = spine[i]
		var b: Vector3 = spine[i + 1]
		var t := float(i) / segs
		var w := width * sin(PI * clampf(t + 0.5 / segs, 0.0, 1.0)) * 1.15
		var tooth := a.lerp(b, 0.62) + Vector3(0, -0.02, 0)
		var col: Color = (tones[0] as Color).lerp(tones[2], t * 0.55 + rng.randf() * 0.08)
		var paint := func(_f: Vector3, n: Vector3) -> Color:
			return Facets.facet_shade(col, n if n.y >= 0.0 else -n)
		# foliolo em dente de serra dos dois lados da nervura
		for s in [-1.0, 1.0]:
			for out in faces:
				Facets.tri(st, a, tooth + side * s * w, b, out, paint)

# --- Sub-bosque (rente: ate 0,3 m na area andavel) -----------------------------

## Samambaia rasteira: roseta de 5-7 frondes curtas.
static func fern(st: SurfaceTool, c: Vector3, size: float, rng: RandomNumberGenerator, tones: Array) -> void:
	var count := rng.randi_range(5, 7)
	var spin := rng.randf() * TAU
	for k in count:
		var a := spin + TAU * k / count + rng.randf_range(-0.2, 0.2)
		frond(st, c + Vector3(0, 0.02, 0), Vector3(cos(a), 2.0, sin(a)), size * rng.randf_range(0.8, 1.1), size * 0.26, 0.02, rng, tones, 3)

## Cavalinha (Equisetum): hastes segmentadas finas. `tall` so fora da area andavel.
static func horsetail(st: SurfaceTool, c: Vector3, height: float, rng: RandomNumberGenerator, tones: Array, stems := 5) -> void:
	for k in stems:
		var off := Vector3(rng.randf_range(-0.14, 0.14), 0, rng.randf_range(-0.14, 0.14))
		var tilt := Vector3(rng.randf_range(-0.08, 0.08), 1.0, rng.randf_range(-0.08, 0.08)).normalized()
		var hh := height * rng.randf_range(0.7, 1.0)
		var a := c + off
		var b := a + tilt * hh
		limb(st, [a, a.lerp(b, 0.5), b], [0.03, 0.026, 0.012], 4, rng, tones, true, null)

## Cicadacea: tronco curto de escamas e coroa de folhas longas e rigidas.
static func cycad(st: SurfaceTool, c: Vector3, height: float, rng: RandomNumberGenerator) -> void:
	var bark := vary([Color("9a7a52"), Color("75593b"), Color("4f3b28")], rng, 0.05)
	var leaves := vary([Color("8bbf6e"), Color("5f9a55"), Color("3e7044")], rng)
	var top := c + Vector3(0, height * 0.45, 0)
	limb(st, [c + Vector3(0, -0.03, 0), c + Vector3(0, height * 0.22, 0), top], [height * 0.16, height * 0.18, height * 0.12], 6, rng, bark, true, null)
	var count := rng.randi_range(8, 10)
	var spin := rng.randf() * TAU
	for k in count:
		var a := spin + TAU * k / count
		frond(st, top, Vector3(cos(a), 0.75, sin(a)), height * 0.85, height * 0.15, height * 0.15, rng, leaves, 3)

## Arbusto baixo de folhas (dois ou tres lobos achatados).
static func shrub(st: SurfaceTool, c: Vector3, r: float, h: float, rng: RandomNumberGenerator, tones: Array) -> void:
	var n := rng.randi_range(2, 3)
	for k in n:
		var a := rng.randf() * TAU
		var p := c + Vector3(cos(a), 0, sin(a)) * r * 0.45 * float(k > 0)
		var rr := r * (1.0 if k == 0 else 0.7)
		var hh := h * (1.0 if k == 0 else 0.8)
		lobe(st, p + Vector3(0, hh * 0.55, 0), rr, hh, rng, tones, 6)

## Tronco caido com musgo por cima e pontas quebradas (rente: topo ~0,26 m).
static func fallen_log(st: SurfaceTool, c: Vector3, yaw: float, length: float, rng: RandomNumberGenerator) -> void:
	var dir := Vector3(cos(yaw), 0, sin(yaw))
	var a := c - dir * length * 0.5 + Vector3(0, 0.11, 0)
	var b := c + dir * length * 0.5 + Vector3(0, 0.12, 0)
	var bark := vary(BARK, rng, 0.06)
	var rings := []
	var basis := along(b - a)
	var phase := rng.randf() * TAU
	for t in [0.0, 0.33, 0.66, 1.0]:
		rings.append(Facets.ring(6, 0.13 * (1.0 - 0.15 * t), 0.0, rng, 0.08, phase, 0.0, Transform3D(basis, a.lerp(b, t))))
	var paint := func(f: Vector3, n: Vector3) -> Color:
		if absf(n.dot(dir)) > 0.75:
			return Color("c9a77a") # corte do tronco
		if n.y > 0.55:
			return Facets.facet_shade(MOSS[1], n) # musgo no dorso
		return Facets.by_height(bark, n, f.y, 0.0, 0.26, f.x * 4.0 + f.z)
	Facets.loft(st, rings, true, true, paint)
	# galho quebrado saindo do tronco
	var mid := a.lerp(b, rng.randf_range(0.35, 0.65))
	var side := Vector3(-dir.z, 0, dir.x) * (1.0 if rng.randf() < 0.5 else -1.0)
	limb(st, [mid, mid + side * 0.32 + Vector3(0, 0.06, 0)], [0.05, 0.025], 4, rng, bark, true, null)

## Cogumelos pequenos (grupo de 3-5).
static func mushrooms(st: SurfaceTool, c: Vector3, rng: RandomNumberGenerator) -> void:
	var cap := [Color("e8d2a6"), Color("c98f5a"), Color("8f5a3a")]
	for k in rng.randi_range(3, 5):
		var p := c + Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
		var h := rng.randf_range(0.05, 0.11)
		limb(st, [p, p + Vector3(0, h, 0)], [0.012, 0.01], 4, rng, [Color("efe6d0"), Color("d8ccb2"), Color("b8ab90")], null, null)
		lobe(st, p + Vector3(0, h + 0.012, 0), rng.randf_range(0.03, 0.05), 0.04, rng, cap, 6)

# --- Rochas (tres familias, variacoes controladas) -------------------------------

enum Rock { BOULDER, SLAB, SPIRE }
const ROCK_TONES := {
	"bare": [Color("a8a99c"), Color("878a7f"), Color("62665d")],
	"heath": [Color("a3ab9a"), Color("838c7d"), Color("5d675b")], # cinza-esverdeado
	"wood": [Color("8f9a8a"), Color("6f7a6d"), Color("4f5a4f")],
}

## Rocha dentro do volume do no antigo (esfera unitaria r 0,5 sob `xf`).
## Familias: BOULDER arredondada, SLAB em camadas (estratos, topo plano),
## SPIRE em colunas. `cover`: "moss", "lichen" ou "".
static func rock(st: SurfaceTool, xf: Transform3D, family: int, rng: RandomNumberGenerator, tones: Array, cover: String) -> void:
	var rings := []
	var sides := 7
	var phase := rng.randf() * TAU
	var specs: Array
	match family:
		Rock.SLAB:
			sides = 6
			specs = [[-0.48, 0.44, 0.0], [-0.2, 0.5, 0.04], [-0.12, 0.44, 0.04], [0.12, 0.47, 0.05], [0.2, 0.4, 0.04], [0.36, 0.42, 0.03]]
		Rock.SPIRE:
			sides = 5
			specs = [[-0.48, 0.46, 0.0], [-0.1, 0.42, 0.05], [0.25, 0.3, 0.06]]
		_:
			specs = [[-0.48, 0.4, 0.0], [-0.15, 0.5, 0.05], [0.18, 0.43, 0.06], [0.4, 0.25, 0.03]]
	for spec in specs:
		var ring := Facets.ring(sides, spec[1], spec[0], rng, 0.13, phase, spec[2])
		var out := PackedVector3Array()
		for v in ring:
			out.append(xf * v)
		rings.append(out)
	var top_y := (xf * Vector3(0, 0.5, 0)).y
	var bot_y := (xf * Vector3(0, -0.5, 0)).y
	var top_tip = true if family == Rock.SLAB else xf * Vector3(rng.randf_range(-0.06, 0.06), 0.5 if family == Rock.SPIRE else 0.47, rng.randf_range(-0.06, 0.06))
	var cover_col: Color = MOSS[1] if cover == "moss" else (Palette.LICHEN if cover == "lichen" else Color.BLACK)
	var paint := func(f: Vector3, n: Vector3) -> Color:
		if cover != "" and n.y > 0.62:
			var k := fposmod(sin(f.x * 4.1 + f.z * 2.7) * 91.7, 1.0)
			if cover == "moss" or k > 0.35: # liquen em manchas; musgo cobre o topo
				return Facets.facet_shade(cover_col.lerp(tones[0], 0.2 * k), n)
		var col := Facets.by_height(tones, n, f.y, bot_y, top_y, f.x + f.z * 1.7)
		if family == Rock.SLAB: # estratos: faixas claras e escuras alternadas
			var band := int(floor((f.y - bot_y) / maxf(0.01, top_y - bot_y) * 5.0))
			col = col.lightened(0.06) if band % 2 == 0 else col.darkened(0.05)
		return col
	Facets.loft(st, rings, top_tip, null, paint)

## Cristal (prisma de 4-5 lados com ponta) ao longo de `dir`.
static func crystal(st: SurfaceTool, base: Vector3, r: float, h: float, dir: Vector3, rng: RandomNumberGenerator, tones := CRYSTAL) -> void:
	var basis := along(dir)
	var xf := Transform3D(basis, base)
	var rings := [Facets.ring(5, r, -0.04, rng, 0.08, 0.0, 0.0, xf), Facets.ring(5, r * 0.92, h * 0.68, rng, 0.08, 0.1, 0.0, xf)]
	var paint := func(_f: Vector3, n: Vector3) -> Color:
		var up := n.dot(basis.y)
		return (tones[0] as Color) if up > 0.3 else ((tones[1] as Color) if n.x + n.z > 0.0 else (tones[2] as Color))
	Facets.loft(st, rings, xf * Vector3(0, h, 0), null, paint)

## Cascalho: pedrinhas rentes.
static func pebble(st: SurfaceTool, c: Vector3, s: float, rng: RandomNumberGenerator, tones: Array) -> void:
	var rings := []
	for spec in [[0.0, 0.85], [s * 0.45, 1.0], [s * 0.8, 0.6]]:
		var ring := Facets.ring(5, s * spec[1], spec[0], rng, 0.2, rng.randf() * TAU)
		for i in ring.size():
			ring[i] += c
		rings.append(ring)
	var paint := func(f: Vector3, n: Vector3) -> Color:
		return Facets.by_height(tones, n, f.y, c.y, c.y + s, f.x + f.z)
	Facets.loft(st, rings, c + Vector3(0, s * 0.95, 0), true, paint)

# --- Ruinas (arquitetura pre-historica estilizada) -----------------------------

const RUIN_STONE := [Color("bcae96"), Color("948670"), Color("6b604f")]

## Toco de coluna quebrada (octogonal, topo serrilhado). Rente: ate `h`.
static func column_stump(st: SurfaceTool, c: Vector3, r: float, h: float, rng: RandomNumberGenerator) -> void:
	var sides := 8
	var phase := rng.randf() * TAU
	var base := Facets.ring(sides, r * 1.08, -0.03, rng, 0.03, phase)
	var mid := Facets.ring(sides, r, h * 0.55, rng, 0.03, phase)
	var top := PackedVector3Array()
	for i in sides:
		var a := phase + TAU * i / sides
		var y := h * (0.72 + 0.28 * fposmod(sin(i * 2.7 + c.x) * 13.1, 1.0)) # topo quebrado
		top.append(Vector3(cos(a) * r * 0.97, y, sin(a) * r * 0.97))
	var rings := []
	for ring in [base, mid, top]:
		var out := PackedVector3Array()
		for v in ring:
			out.append(v + c)
		rings.append(out)
	var paint := func(f: Vector3, n: Vector3) -> Color:
		if n.y > 0.6:
			return Facets.facet_shade(MOSS[1].lerp(RUIN_STONE[1], 0.35), n) # musgo no corte
		return Facets.by_height(RUIN_STONE, n, f.y, c.y, c.y + h, f.x + f.z)
	Facets.loft(st, rings, c + Vector3(0, h * 0.8, 0), null, paint)

## Bloco talhado caido (meio enterrado), com quinas lascadas.
static func fallen_block(st: SurfaceTool, c: Vector3, size: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3(1, 0, 0), rng.randf_range(-0.12, 0.12))
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var ring := func(y: float, k: float) -> PackedVector3Array:
		var pts := PackedVector3Array()
		for q in [Vector2(-hx, -hz), Vector2(hx * 0.92, -hz), Vector2(hx, -hz * 0.8), Vector2(hx, hz), Vector2(-hx * 0.9, hz), Vector2(-hx, hz * 0.85)]:
			pts.append(c + basis * Vector3(q.x * k, y, q.y * k))
		return pts
	var paint := func(f: Vector3, n: Vector3) -> Color:
		if n.y > 0.7:
			return Facets.facet_shade(RUIN_STONE[0].lerp(MOSS[0], 0.25), n)
		return Facets.by_height(RUIN_STONE, n, f.y, c.y - 0.05, c.y + size.y, f.x + f.z)
	Facets.loft(st, [ring.call(-0.06, 1.0), ring.call(size.y - 0.05, 1.0), ring.call(size.y, 0.9)], true, null, paint)

## Laje do piso antigo, rente (2-3 cm), rachada.
static func flagstone(st: SurfaceTool, c: Vector3, s: float, yaw: float, rng: RandomNumberGenerator) -> void:
	var ring := Facets.ring(5, s, 0.0, rng, 0.14, yaw)
	var top := PackedVector3Array()
	var bottom := PackedVector3Array()
	for v in ring:
		top.append(c + v + Vector3(0, 0.03, 0))
		bottom.append(c + v * 1.04 + Vector3(0, -0.01, 0))
	var paint := func(f: Vector3, n: Vector3) -> Color:
		return Facets.by_height([RUIN_STONE[1], RUIN_STONE[2], RUIN_STONE[2].darkened(0.2)], n, f.y, -0.01, 0.03, f.x * 3.0 + f.z)
	Facets.loft(st, [bottom, top], true, null, paint)

## Glifo talhado (incrustacao jade) num plano: centro, eixos `right`/`up` do
## plano e a normal para fora. Formas: "spiral" (amonite), "track" (pegada de
## tres dedos), "crystal" (losango). Malha propria: brilha a noite.
static func glyph(st: SurfaceTool, center: Vector3, right: Vector3, up: Vector3, normal: Vector3, size: float, shape: String) -> void:
	var col := Palette.JADE
	var paint := func(_f: Vector3, n: Vector3) -> Color:
		return Facets.facet_shade(col, n)
	var lift := normal * 0.012
	var bar := func(a: Vector2, b: Vector2, w: float) -> void:
		var pa := center + right * a.x * size + up * a.y * size + lift
		var pb := center + right * b.x * size + up * b.y * size + lift
		var d := (pb - pa).normalized()
		var side := d.cross(normal).normalized() * w * size
		Facets.tri(st, pa - side, pa + side, pb + side, normal, paint)
		Facets.tri(st, pa - side, pb + side, pb - side, normal, paint)
	match shape:
		"spiral":
			var prev := Vector2.ZERO
			for i in range(1, 15):
				var t := float(i) / 14.0
				var a := t * TAU * 1.6
				var p := Vector2(cos(a), sin(a)) * (0.06 + 0.42 * t)
				bar.call(prev, p, 0.06)
				prev = p
		"track":
			bar.call(Vector2(0, -0.35), Vector2(0, 0.05), 0.09)
			for toe in [Vector2(-0.32, 0.42), Vector2(0, 0.5), Vector2(0.32, 0.42)]:
				bar.call(Vector2(0, 0.05), toe, 0.07)
		_:
			for edge in [[Vector2(0, 0.5), Vector2(0.3, 0)], [Vector2(0.3, 0), Vector2(0, -0.5)], [Vector2(0, -0.5), Vector2(-0.3, 0)], [Vector2(-0.3, 0), Vector2(0, 0.5)]]:
				bar.call(edge[0], edge[1], 0.07)

## Copa da arvore coletavel (mesma familia dos lobos, tons quentes de "lenha").
## Malha em cache, origem no pe do tronco (copa a partir de ~1,9 m).
static var _harvest: ArrayMesh
static func harvest_crown(tones: Array) -> ArrayMesh:
	if _harvest != null:
		return _harvest
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4040
	lobe(st, Vector3(0.05, 3.0, 0.0), 0.85, 1.15, rng, tones, 7)
	for k in 5:
		var a := TAU * k / 5.0 + 0.4
		var c := Vector3(cos(a) * 0.82, 2.55 + 0.18 * float(k % 2), sin(a) * 0.82)
		lobe(st, c, 0.6, 0.78, rng, tones, 6)
	_harvest = st.commit()
	return _harvest
