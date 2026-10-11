extends RefCounted

# Visual Overhaul 3.0 — modelos low-poly das criaturas, gerados por codigo.
# Antes: esferas, caixas e cones soltos. Agora: corpo, pescoco, cranio, cauda e
# pernas sao malhas continuas (aneis "lofted") facetadas, com silhueta de
# teropode (cranio longo, pernas digitigradas com tres dedos, cauda que
# equilibra o corpo) e cor por vertice multiplicando o material (listras no
# dorso, ventre claro). Os NOMES dos nos e os materiais por no continuam os do
# modelo antigo (Body, Head, Crest, Collar, Eye1, LegL...), porque a paleta
# noturna, os testes e as animacoes dependem deles.
#
# Usado pela ferramenta tools/build_creatures.gd, que grava dino.tscn e
# carno.tscn. Em jogo so rodam os ornamentos por faccao (no fim, em cache).

const Facets := preload("res://scenes/visuals/facets.gd")

## Especie "selvagem" (todo dinossauro do jogo: selvagem, guardiao, aliado,
## invasor) e a variante Carnotauro (so na cena de teste de onda).
const WILD := {
	"main": Color("c76c4c"), "belly": Color("e7ae58"), "cream": Color("fff2cd"), "dark": Color("183e3e"),
	"crest": Color("e7ae58"), "jade": Color("69be9b"), "eye": Color("f4d27a"),
	"body_scale": Vector3(1.0, 1.0, 1.0), "head_len": 1.0, "head_depth": 1.0, "leg": 1.2, "tail": 0.86,
	"arm": 1.0, "horns": false, "stripes": true,
}
const CARNO := {
	"main": Color("695778"), "belly": Color("c9a37a"), "cream": Color("fff2cd"), "dark": Color("2a2235"),
	"crest": Color("b86f55"), "jade": Color("69be9b"), "eye": Color("f0b450"),
	"body_scale": Vector3(1.16, 1.08, 1.06), "head_len": 0.82, "head_depth": 1.25, "leg": 1.3, "tail": 0.95,
	"arm": 0.55, "horns": true, "stripes": false,
}

# ---------------------------------------------------------------------------
# Geometria
# ---------------------------------------------------------------------------

## Anel eliptico no plano XY (eixo do corpo = Z). `keel` > 1 deixa a barriga
## mais funda que o dorso; `ridge` > 1 levanta a linha do dorso.
static func ring_z(z: float, y: float, rx: float, ry: float, sides := 8, keel := 1.0, ridge := 1.0) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in sides:
		var a := TAU * i / sides + PI / sides
		var s := sin(a)
		var k := ridge if s > 0.0 else keel
		out.append(Vector3(cos(a) * rx, y + s * ry * k, z))
	return out

## Anel perpendicular a `dir`, centrado em `c` (membros em qualquer direcao).
static func ring_axis(c: Vector3, dir: Vector3, rx: float, ry: float, sides := 6) -> PackedVector3Array:
	dir = dir.normalized()
	var u := Vector3.RIGHT if absf(dir.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	u = (u - dir * u.dot(dir)).normalized()
	var v := dir.cross(u).normalized()
	var out := PackedVector3Array()
	for i in sides:
		var a := TAU * i / sides + PI / sides
		out.append(c + u * cos(a) * rx + v * sin(a) * ry)
	return out

## Tubo por uma polilinha (membros, dedos, chifres): raios por ponto, ponta fechada.
static func tube(st: SurfaceTool, pts: Array, radii: Array, paint: Callable, sides := 6, tip := true, flat := 1.0) -> void:
	var rings := []
	for i in pts.size():
		var d: Vector3
		if i == 0: d = pts[1] - pts[0]
		elif i == pts.size() - 1: d = pts[i] - pts[i - 1]
		else: d = pts[i + 1] - pts[i - 1]
		rings.append(ring_axis(pts[i], d, radii[i], radii[i] * flat, sides))
	var last: Vector3 = pts[pts.size() - 1]
	var end_dir: Vector3 = (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized()
	Facets.loft(st, rings, (last + end_dir * radii[radii.size() - 1] * 1.6) if tip else true, true, paint)

static func begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

# ---------------------------------------------------------------------------
# Pintura (multiplica o albedo do material: 1 = cor do material)
# ---------------------------------------------------------------------------

## Volume assado leve + dorso mais escuro + listras transversais (selvagem).
static func skin_paint(stripes: bool, z_offset := 0.0) -> Callable:
	return func(c: Vector3, n: Vector3) -> Color:
		var k := 0.9 + 0.1 * n.y
		if n.y > 0.25:
			k *= 0.86
			if stripes and sin((c.z + z_offset) * 15.0) > 0.35:
				k *= 0.74
		elif n.y < -0.35:
			k *= 1.0
		var v := fposmod(sin(c.x * 41.3 + c.y * 17.1 + c.z * 29.7) * 43758.5453, 1.0)
		k *= 0.97 + 0.05 * v
		return Color(k, k, k)

static func plain_paint(shade := 0.1) -> Callable:
	return func(_c: Vector3, n: Vector3) -> Color:
		var k := (1.0 - shade) + shade * n.y
		return Color(k, k, k)

# ---------------------------------------------------------------------------
# Partes
# ---------------------------------------------------------------------------

static func body_mesh(sp: Dictionary) -> ArrayMesh:
	var s: Vector3 = sp.body_scale
	var st := begin()
	var rings := [
		ring_z(0.66 * s.z, 1.03, 0.23 * s.x, 0.25 * s.y, 8),
		ring_z(0.38 * s.z, 1.01, 0.39 * s.x, 0.4 * s.y, 8, 1.12),
		ring_z(0.06 * s.z, 0.99, 0.45 * s.x, 0.46 * s.y, 8, 1.18, 1.04),
		ring_z(-0.22 * s.z, 1.05, 0.41 * s.x, 0.44 * s.y, 8, 1.12, 1.06),
		ring_z(-0.42 * s.z, 1.17, 0.29 * s.x, 0.32 * s.y, 8),
	]
	Facets.loft(st, rings, Vector3(0, 1.2, -0.5 * s.z), Vector3(0, 1.03, 0.72 * s.z), skin_paint(sp.stripes))
	return st.commit()

## Placa clara do ventre (meia elipse um pouco maior que o corpo, so embaixo).
static func belly_mesh(sp: Dictionary) -> ArrayMesh:
	var s: Vector3 = sp.body_scale
	var st := begin()
	var spans := [[0.42, 1.0, 0.345, 0.38], [0.1, 0.98, 0.425, 0.49], [-0.2, 1.04, 0.38, 0.47], [-0.4, 1.16, 0.28, 0.34]]
	var rings := []
	for q in spans:
		var r := PackedVector3Array()
		for i in 5:
			var a := PI + 0.42 + (PI - 0.84) * i / 4.0
			var keel := 1.18 if q[0] > -0.1 and q[0] < 0.2 else 1.12
			r.append(Vector3(cos(a) * q[2] * s.x * 1.04, q[1] + sin(a) * q[3] * s.y * keel * 1.03, q[0] * s.z))
		rings.append(r)
	# faixa aberta: uma face por quad, voltada para baixo/fora
	var paint := plain_paint(0.08)
	for k in rings.size() - 1:
		var lo: PackedVector3Array = rings[k]
		var hi: PackedVector3Array = rings[k + 1]
		for i in 4:
			var mid := (lo[i] + lo[i + 1] + hi[i] + hi[i + 1]) * 0.25
			var out := mid - Vector3(0, 1.0, mid.z)
			Facets.tri(st, lo[i], lo[i + 1], hi[i + 1], out, paint)
			Facets.tri(st, lo[i], hi[i + 1], hi[i], out, paint)
	return st.commit()

static func neck_mesh(sp: Dictionary) -> ArrayMesh:
	var s: Vector3 = sp.body_scale
	var st := begin()
	var w := 1.0 + (s.x - 1.0) * 1.5
	var rings := [
		ring_z(-0.34, 1.15, 0.27 * w, 0.3, 7),
		ring_z(-0.48, 1.31, 0.22 * w, 0.23, 7),
		ring_z(-0.6, 1.49, 0.19 * w, 0.2, 7),
		ring_z(-0.68, 1.62, 0.19 * w, 0.2, 7),
	]
	Facets.loft(st, rings, true, true, skin_paint(sp.stripes, 0.2))
	return st.commit()

## Cranio: largo nas bochechas, focinho afinando; o fundo e reto (a mandibula
## fica embaixo, em outro no, para abrir a boca).
static func head_mesh(sp: Dictionary) -> ArrayMesh:
	var L: float = sp.head_len
	var D: float = sp.head_depth
	var st := begin()
	var rings := [
		ring_z(-0.6, 1.73, 0.18, 0.18 * D, 7, 0.8),
		ring_z(-0.6 - 0.14 * L, 1.75, 0.245, 0.22 * D, 7, 0.75, 1.05),
		ring_z(-0.6 - 0.3 * L, 1.71, 0.21, 0.18 * D, 7, 0.7),
		ring_z(-0.6 - 0.46 * L, 1.67, 0.155, 0.135 * D, 7, 0.7),
		ring_z(-0.6 - 0.6 * L, 1.64, 0.11, 0.1 * D, 7, 0.75),
	]
	Facets.loft(st, rings, Vector3(0, 1.62, -0.6 - 0.69 * L), Vector3(0, 1.74, -0.55), skin_paint(false))
	return st.commit()

## Mandibula (pivo na articulacao): malha relativa ao pivo.
const JAW_PIVOT := Vector3(0, 1.62, -0.68)
static func jaw_mesh(sp: Dictionary) -> ArrayMesh:
	var L: float = sp.head_len
	var D: float = sp.head_depth
	var st := begin()
	var p := JAW_PIVOT
	var rings := [
		ring_z(-0.66 - p.z, 1.58 - p.y, 0.15, 0.07 * D, 6),
		ring_z(-0.6 - 0.3 * L - p.z, 1.54 - p.y, 0.14, 0.06 * D, 6),
		ring_z(-0.6 - 0.5 * L - p.z, 1.55 - p.y, 0.1, 0.05 * D, 6),
	]
	Facets.loft(st, rings, Vector3(0, 1.57 - p.y, -0.6 - 0.62 * L - p.z), true, plain_paint(0.15))
	return st.commit()

## Dentes: serrilhado creme na borda do cranio (acompanha a mandibula aberta?
## nao: ficam no cranio; os de baixo ficam na mandibula).
static func teeth_mesh(sp: Dictionary, lower: bool) -> ArrayMesh:
	var L: float = sp.head_len
	var st := begin()
	var paint := plain_paint(0.05)
	for side in [-1.0, 1.0]:
		for i in (4 if not lower else 3):
			var t := (0.2 + i * 0.12) if not lower else (0.26 + i * 0.12)
			var z: float = -0.6 - t * L
			var x: float = side * lerpf(0.15, 0.08, (t - 0.18) / 0.4)
			var y := 1.6 if not lower else 1.585
			var a := Vector3(x, y, z + 0.025)
			var b := Vector3(x, y, z - 0.025)
			var tip := Vector3(x * 0.95, y + (-0.06 if not lower else 0.035), z)
			Facets.tri(st, a, b, tip, Vector3(side, 0, 0), paint)
			Facets.tri(st, a, tip, b, Vector3(-side, 0, 0), paint)
	var m := st.commit()
	if lower:
		# relativo ao pivo da mandibula
		var arrays := m.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i] -= JAW_PIVOT
		arrays[Mesh.ARRAY_VERTEX] = verts
		var out := ArrayMesh.new()
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return out
	return m

## Arcada sobre os olhos + crista nasal (no "Muzzle", nome antigo).
static func brow_mesh(sp: Dictionary) -> ArrayMesh:
	var L: float = sp.head_len
	var D: float = sp.head_depth
	var st := begin()
	var paint := skin_paint(false)
	for side in [-1.0, 1.0]:
		tube(st, [Vector3(side * 0.11, 1.87 + 0.04 * (D - 1.0), -0.66), Vector3(side * 0.18, 1.89 + 0.06 * (D - 1.0), -0.76), Vector3(side * 0.135, 1.85 + 0.04 * (D - 1.0), -0.86)], [0.05, 0.055, 0.035], paint, 5)
	# crista nasal baixa no focinho
	tube(st, [Vector3(0, 1.78, -0.6 - 0.3 * L), Vector3(0, 1.75, -0.6 - 0.48 * L)], [0.045, 0.03], paint, 5, true, 1.3)
	return st.commit()

## Crista: placas triangulares no alto da cabeca e descendo pelo pescoco.
static func crest_mesh(sp: Dictionary) -> ArrayMesh:
	var st := begin()
	var paint := plain_paint(0.2)
	var plates := [[-0.74, 1.9, 0.17], [-0.62, 1.86, 0.15], [-0.53, 1.72, 0.12], [-0.45, 1.56, 0.1], [-0.36, 1.42, 0.08]]
	if sp.horns:
		plates = [[-0.52, 1.75, 0.09], [-0.42, 1.58, 0.08], [-0.33, 1.44, 0.07]]
	for q in plates:
		var z: float = q[0]
		var y: float = q[1]
		var h: float = q[2]
		var a := Vector3(0, y, z - h * 0.55)
		var b := Vector3(0, y, z + h * 0.55)
		var tip := Vector3(0, y + h, z + h * 0.35)
		var w := Vector3(0.025, 0, 0)
		Facets.tri(st, a - w, b - w, tip, Vector3(-1, 0, 0), paint)
		Facets.tri(st, a + w, tip, b + w, Vector3(1, 0, 0), paint)
		Facets.tri(st, a - w, a + w, tip, Vector3(0, 0, -1), paint)
	return st.commit()

## Chifres do Carnotauro (sobre os olhos, para fora e para cima).
static func horn_mesh(side: float) -> ArrayMesh:
	var st := begin()
	tube(st, [Vector3(side * 0.13, 1.88, -0.74), Vector3(side * 0.22, 2.0, -0.72), Vector3(side * 0.27, 2.1, -0.66)], [0.06, 0.04, 0.02], plain_paint(0.2), 5)
	return st.commit()

## Cauda (pivo na raiz): grossa na base, afina ate a ponta, leve curva.
## 4.0: dois segmentos — a ponta (TailTip) tem pivo proprio no meio da cauda e
## balanca atrasada em relacao a base, como um chicote (antes era rigida).
const TAIL_PIVOT := Vector3(0, 1.03, 0.6)
static func _tail_rings(sp: Dictionary) -> Array:
	var T: float = sp.tail
	var s: Vector3 = sp.body_scale
	return [
		ring_z(0.0, 0.0, 0.24 * s.x, 0.26 * s.y, 7),
		ring_z(0.42 * T, -0.06, 0.19 * s.x, 0.21 * s.y, 7),
		ring_z(0.86 * T, -0.1, 0.13, 0.14, 7),
		ring_z(1.26 * T, -0.08, 0.075, 0.085, 7),
		ring_z(1.58 * T, -0.02, 0.028, 0.034, 7),
	]

## Pivo da ponta da cauda, no espaco do no Tail.
static func tail_tip_pivot(sp: Dictionary) -> Vector3:
	return Vector3(0, -0.1, 0.86 * float(sp.tail))

static func tail_mesh(sp: Dictionary) -> ArrayMesh:
	var r := _tail_rings(sp)
	var st := begin()
	Facets.loft(st, [r[0], r[1], r[2]], true, true, skin_paint(sp.stripes, 0.6))
	return st.commit()

static func tail_tip_mesh(sp: Dictionary) -> ArrayMesh:
	var r := _tail_rings(sp)
	var st := begin()
	# o anel da junta repete um pouco maior: sem fresta quando a ponta dobra
	var joint := PackedVector3Array()
	for v in r[2]:
		joint.append(Vector3(v.x * 1.04, -0.1 + (v.y + 0.1) * 1.04, v.z - 0.03))
	Facets.loft(st, [joint, r[3], r[4]], Vector3(0, 0.03, 1.74 * float(sp.tail)), true, skin_paint(sp.stripes, 0.6))
	return _shifted(st, tail_tip_pivot(sp))

## Coxa, canela e pe digitigrado. 4.0: perna com JOELHO e TORNOZELO (pivos
## proprios): a coxa gira no quadril, a canela no joelho e o pe no tornozelo,
## para o passo levantar o pe e assentar no chao (antes a perna era rigida).
## Cada malha e relativa ao seu pivo; o pe continua tocando y = 0.
const HIP := Vector3(0.28, 0.97, 0.16)
const KNEE := Vector3(0.02, -0.44, -0.16) # relativo ao quadril
const ANKLE := Vector3(0.0, -0.78, 0.12) # relativo ao quadril

static func _shifted(st: SurfaceTool, by: Vector3) -> ArrayMesh:
	var arrays := st.commit().surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] -= by
	arrays[Mesh.ARRAY_VERTEX] = verts
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out

static func thigh_mesh(sp: Dictionary) -> ArrayMesh:
	var g: float = sp.leg
	var st := begin()
	# coxa musculosa: larga em cima, afinando ate o joelho
	tube(st, [Vector3(0, 0.1, 0.03), Vector3(0.03, -0.1, -0.04), Vector3(0.025, -0.3, -0.12), KNEE], [0.19 * g, 0.215 * g, 0.16 * g, 0.1 * g], skin_paint(false), 7, false)
	return st.commit()

static func shin_mesh(sp: Dictionary) -> ArrayMesh:
	var g: float = sp.leg
	var st := begin()
	tube(st, [KNEE, Vector3(0.0, -0.6, -0.02), ANKLE], [0.1 * g, 0.08 * g, 0.066 * g], skin_paint(false), 6, false)
	return _shifted(st, KNEE)

static func foot_mesh(sp: Dictionary) -> ArrayMesh:
	var g: float = sp.leg
	var st := begin()
	var paint := plain_paint(0.15)
	# metatarso inclinado ate a "bola" do pe
	tube(st, [ANKLE, Vector3(0, -0.91, 0.02)], [0.066 * g, 0.06 * g], paint, 6, false)
	for toe in [Vector3(-0.09, 0, -0.2), Vector3(0, 0, -0.26), Vector3(0.09, 0, -0.2)]:
		var start := Vector3(toe.x * 0.3, -0.92, 0.0)
		tube(st, [start, Vector3(toe.x * 0.8, -0.93, toe.z * 0.6), Vector3(toe.x, -0.94, toe.z)], [0.05 * g, 0.04 * g, 0.03], paint, 5, false, 0.7)
	return _shifted(st, ANKLE)

## Tres garras numa malha so (relativa ao tornozelo).
static func claws_mesh() -> ArrayMesh:
	var st := begin()
	for toe in [Vector3(-0.09, 0, -0.2), Vector3(0, 0, -0.26), Vector3(0.09, 0, -0.2)]:
		tube(st, [Vector3(toe.x, -0.94, toe.z), Vector3(toe.x * 1.05, -0.95, toe.z - 0.06), Vector3(toe.x * 1.08, -0.97, toe.z - 0.1)], [0.026, 0.02, 0.008], plain_paint(0.1), 4)
	return _shifted(st, ANKLE)

## Garra de um dedo (ponta curva para baixo).
static func claw_mesh(toe: Vector3) -> ArrayMesh:
	var st := begin()
	tube(st, [Vector3(toe.x, -0.94, toe.z), Vector3(toe.x * 1.05, -0.95, toe.z - 0.06), Vector3(toe.x * 1.08, -0.97, toe.z - 0.1)], [0.026, 0.02, 0.008], plain_paint(0.1), 4)
	return st.commit()

## Bracinhos (ombro -> cotovelo -> mao com dois dedos).
static func arm_mesh(side: float, sp: Dictionary) -> ArrayMesh:
	var a: float = sp.arm
	var st := begin()
	var shoulder := Vector3(side * 0.29, 1.1, -0.36)
	var elbow := shoulder + Vector3(side * 0.06, -0.16, -0.06) * a
	var hand := elbow + Vector3(0, -0.04, -0.17) * a
	tube(st, [shoulder, elbow, hand], [0.07 * maxf(a, .7), 0.055 * maxf(a, .7), 0.04 * maxf(a, .7)], skin_paint(false), 5, false)
	for f in [-1.0, 1.0]:
		tube(st, [hand, hand + Vector3(f * 0.025, -0.07, -0.05) * a], [0.022, 0.008], plain_paint(0.1), 4)
	return st.commit()

## Olho (lente facetada) e pupila em fenda. 4.0: olho um pouco maior e pupila
## com um brilho branco (le "vivo" de perto: menu, capturas, rotulos).
static func eye_mesh() -> ArrayMesh:
	var st := begin()
	var rings := [ring_axis(Vector3(-0.012, 0, 0), Vector3.RIGHT, 0.064, 0.058, 6), ring_axis(Vector3(0.022, 0, 0), Vector3.RIGHT, 0.052, 0.047, 6)]
	Facets.loft(st, rings, Vector3(0.044, 0, 0), true, plain_paint(0.05))
	return st.commit()

## Cor na malha (o material da pupila e branco com cor por vertice).
static func pupil_mesh(dark := Color("183e3e")) -> ArrayMesh:
	var st := begin()
	var ink := func(_c: Vector3, _n: Vector3) -> Color: return dark
	var rings := [ring_axis(Vector3(0, 0, 0), Vector3.RIGHT, 0.017, 0.044, 4), ring_axis(Vector3(0.012, 0, 0), Vector3.RIGHT, 0.012, 0.035, 4)]
	Facets.loft(st, rings, true, true, ink)
	# brilho: triangulo claro no alto, a frente da pupila
	var shine := func(_c: Vector3, _n: Vector3) -> Color: return Color(1, 1, 0.94)
	var c := Vector3(0.016, 0.022, -0.012)
	Facets.tri(st, c + Vector3(0, 0.014, 0), c + Vector3(0, -0.006, 0.012), c + Vector3(0, -0.006, -0.012), Vector3.RIGHT, shine)
	return st.commit()

## Coleira de aliado: faixa de couro em volta da base do pescoco + gema jade.
static func collar_mesh() -> ArrayMesh:
	var st := begin()
	var paint := plain_paint(0.1)
	var rings := [ring_z(-0.4, 1.26, 0.25, 0.28, 8), ring_z(-0.47, 1.36, 0.235, 0.26, 8)]
	Facets.loft(st, rings, null, null, paint)
	var gem := Vector3(0, 1.08, -0.56)
	tube(st, [gem + Vector3(0, 0.07, 0.02), gem], [0.05, 0.04], paint, 4)
	return st.commit()

# ---------------------------------------------------------------------------
# Ornamentos por faccao (criados em jogo, malhas em cache). O material vai na
# SUPERFICIE da malha (material_override fica vazio): assim a troca de
# paleta noturna e a regra "selvagem/guardiao mantem os materiais do modelo"
# continuam valendo. A cor nao e a unica diferenca: a silhueta muda.
# ---------------------------------------------------------------------------
static var _ornaments := {}

static func _surface_mat(color: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

static func _finish(st: SurfaceTool, mat: Material) -> ArrayMesh:
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh

## Guardiao: mascara de osso (chifre nasal e placas sobre os olhos).
static func guard_mask_mesh() -> ArrayMesh:
	if not _ornaments.has("mask"):
		var st := begin()
		var paint := plain_paint(0.25)
		tube(st, [Vector3(0, 1.79, -0.95), Vector3(0, 1.9, -1.0), Vector3(0, 2.0, -0.98)], [0.05, 0.035, 0.012], paint, 5)
		for side in [-1.0, 1.0]:
			tube(st, [Vector3(side * 0.12, 1.92, -0.7), Vector3(side * 0.22, 1.98, -0.64), Vector3(side * 0.3, 2.0, -0.55)], [0.045, 0.03, 0.01], paint, 5)
		_ornaments["mask"] = _finish(st, _surface_mat(Color("e8dfca")))
	return _ornaments["mask"]

## Guardiao: colar de contas ambar com uma pedra-runa (o territorio que guarda).
static func totem_beads_mesh() -> ArrayMesh:
	if not _ornaments.has("beads"):
		var st := begin()
		var paint := plain_paint(0.2)
		for i in 9:
			var a := PI * 0.15 + PI * 0.7 * i / 8.0
			var c := Vector3(cos(a) * 0.3, 1.28 - sin(a) * 0.06 - 0.1 * sin(a), -0.44 - sin(a) * 0.12)
			var r := 0.045
			for tri in [[Vector3(0, r, 0), Vector3(r, 0, 0), Vector3(0, 0, -r)], [Vector3(0, r, 0), Vector3(0, 0, -r), Vector3(-r, 0, 0)],
					[Vector3(0, r, 0), Vector3(-r, 0, 0), Vector3(0, 0, r)], [Vector3(0, r, 0), Vector3(0, 0, r), Vector3(r, 0, 0)],
					[Vector3(0, -r, 0), Vector3(0, 0, -r), Vector3(r, 0, 0)], [Vector3(0, -r, 0), Vector3(-r, 0, 0), Vector3(0, 0, -r)],
					[Vector3(0, -r, 0), Vector3(0, 0, r), Vector3(-r, 0, 0)], [Vector3(0, -r, 0), Vector3(r, 0, 0), Vector3(0, 0, r)]]:
				Facets.tri(st, c + tri[0], c + tri[1], c + tri[2], (tri[0] + tri[1] + tri[2]), paint)
		# pedra-runa pendurada no peito
		var p := Vector3(0, 1.08, -0.6)
		var rings := [ring_axis(p + Vector3(0, 0.09, 0), Vector3.UP, 0.07, 0.04, 5), ring_axis(p, Vector3.UP, 0.09, 0.05, 5)]
		Facets.loft(st, rings, true, p - Vector3(0, 0.1, 0), paint)
		_ornaments["beads"] = _finish(st, _surface_mat(Color("d5a45e"), 0.25))
	return _ornaments["beads"]

## Invasor noturno: espinhos dorsais altos e finos (silhueta agressiva).
static func spine_back_mesh() -> ArrayMesh:
	if not _ornaments.has("spine_back"):
		var st := begin()
		var paint := plain_paint(0.2)
		for q in [[-0.36, 1.48, 0.2], [-0.2, 1.48, 0.27], [0.0, 1.47, 0.32], [0.2, 1.45, 0.3], [0.4, 1.38, 0.24], [0.58, 1.28, 0.18]]:
			var z: float = q[0]
			var y: float = q[1]
			var h: float = q[2]
			var base := [Vector3(-0.05, y - 0.06, z - 0.07), Vector3(0.05, y - 0.06, z - 0.07), Vector3(0.05, y - 0.06, z + 0.09), Vector3(-0.05, y - 0.06, z + 0.09)]
			var tip := Vector3(0, y + h, z + h * 0.45)
			for i in 4:
				Facets.tri(st, base[i], base[(i + 1) % 4], tip, (base[i] + base[(i + 1) % 4]) * 0.5 - Vector3(0, y, z + 0.01), paint)
		_ornaments["spine_back"] = st.commit()
	return _ornaments["spine_back"]

## Espinhos da cauda (coordenadas locais do no Tail).
static func spine_tail_mesh() -> ArrayMesh:
	if not _ornaments.has("spine_tail"):
		var st := begin()
		var paint := plain_paint(0.2)
		for q in [[0.18, 0.22, 0.16], [0.42, 0.18, 0.14], [0.64, 0.13, 0.1]]: # 4.0: so no segmento da base
			var z: float = q[0]
			var y: float = q[1]
			var h: float = q[2]
			var base := [Vector3(-0.04, y - 0.05, z - 0.06), Vector3(0.04, y - 0.05, z - 0.06), Vector3(0.04, y - 0.05, z + 0.07), Vector3(-0.04, y - 0.05, z + 0.07)]
			var tip := Vector3(0, y + h, z + h * 0.5)
			for i in 4:
				Facets.tri(st, base[i], base[(i + 1) % 4], tip, (base[i] + base[(i + 1) % 4]) * 0.5 - Vector3(0, y, z + 0.005), paint)
		_ornaments["spine_tail"] = st.commit()
	return _ornaments["spine_tail"]

# ---------------------------------------------------------------------------
# Explorador (Player). Mesmo metodo: partes "lofted" facetadas. Silhueta lida
# de cima (camera estrategica): chapeu de abas largas com faixa jade, capa
# jade nas costas, mochila com saco de dormir e lanterna de cristal. Pivos dos
# membros nos ombros e quadris (animacao de passo e golpe do actor_visual).
# ---------------------------------------------------------------------------
const EXPLORER := {
	"skin": Color("e0a77d"), "tunic": Color("d5a45e"), "vest": Color("7a4e2d"), "pants": Color("2c4a3e"),
	"boots": Color("5e3f27"), "hair": Color("3a2a1e"), "hat": Color("a7794a"), "band": Color("69c7a0"),
	"cape": Color("2f8f6e"), "scarf": Color("69c7a0"), "pack": Color("8a5e3b"), "roll": Color("cdb68c"),
	"strap": Color("b86f55"), "stone": Color("8d9a8f"), "wood": Color("6e4b2c"), "eye": Color("1b2a26"),
}
const SHOULDER := Vector3(0.31, 1.33, 0.0)
const HIP_P := Vector3(0.13, 0.84, 0.0)

static func x_tunic() -> ArrayMesh:
	var st := begin()
	var rings := [ring_axis(Vector3(0, 0.78, 0.0), Vector3.UP, 0.29, 0.21, 8), ring_axis(Vector3(0, 0.98, 0.0), Vector3.UP, 0.27, 0.2, 8),
		ring_axis(Vector3(0, 1.2, 0.0), Vector3.UP, 0.3, 0.21, 8), ring_axis(Vector3(0, 1.36, 0.0), Vector3.UP, 0.27, 0.19, 8)]
	Facets.loft(st, rings, true, true, plain_paint(0.18))
	return st.commit()

## Colete de couro aberto na frente: placas dos lados e das costas.
static func x_vest() -> ArrayMesh:
	var st := begin()
	var paint := plain_paint(0.2)
	var lo := ring_axis(Vector3(0, 0.95, 0.0), Vector3.UP, 0.29, 0.215, 8)
	var hi := ring_axis(Vector3(0, 1.34, 0.0), Vector3.UP, 0.315, 0.225, 8)
	for i in 8:
		var j := (i + 1) % 8
		var mid := (lo[i] + lo[j] + hi[i] + hi[j]) * 0.25
		if mid.z < -0.12 and absf(mid.x) < 0.14:
			continue # abertura da frente (aparece a tunica)
		var out := mid - Vector3(0, mid.y, 0)
		Facets.tri(st, lo[i], lo[j], hi[j], out, paint)
		Facets.tri(st, lo[i], hi[j], hi[i], out, paint)
	return st.commit()

static func x_belt() -> ArrayMesh:
	var st := begin()
	var rings := [ring_axis(Vector3(0, 0.82, 0), Vector3.UP, 0.305, 0.225, 8), ring_axis(Vector3(0, 0.9, 0), Vector3.UP, 0.3, 0.222, 8)]
	Facets.loft(st, rings, null, null, plain_paint(0.1))
	tube(st, [Vector3(0.3, 0.86, 0.05), Vector3(0.33, 0.74, 0.05)], [0.075, 0.065], plain_paint(0.2), 5, false)
	return st.commit()

static func x_head() -> ArrayMesh:
	var st := begin()
	var rings := [ring_axis(Vector3(0, 1.42, 0), Vector3.UP, 0.13, 0.12, 8), ring_axis(Vector3(0, 1.52, -0.01), Vector3.UP, 0.23, 0.22, 8),
		ring_axis(Vector3(0, 1.68, -0.01), Vector3.UP, 0.25, 0.24, 8), ring_axis(Vector3(0, 1.82, 0), Vector3.UP, 0.19, 0.19, 8)]
	Facets.loft(st, rings, Vector3(0, 1.86, 0), true, plain_paint(0.12))
	tube(st, [Vector3(0, 1.64, -0.22), Vector3(0, 1.6, -0.28)], [0.045, 0.03], plain_paint(0.12), 4)
	return st.commit()

static func x_hair() -> ArrayMesh:
	var st := begin()
	var rings := [ring_axis(Vector3(0, 1.46, 0.1), Vector3.UP, 0.18, 0.15, 7), ring_axis(Vector3(0, 1.62, 0.09), Vector3.UP, 0.23, 0.18, 7), ring_axis(Vector3(0, 1.78, 0.06), Vector3.UP, 0.21, 0.18, 7)]
	Facets.loft(st, rings, null, true, plain_paint(0.15))
	return st.commit()

## Chapeu: aba larga (duas faces) e copa levemente amassada.
## 4.0: chapeu de explorador com aba enrolada dos lados, caida na frente, e
## copa vincada (silhueta de "fedora" de expedicao, a mais legivel de cima).
static func _brim_ring(r: float, rz: float, y: float, curl: float, sides: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in sides:
		var a := TAU * i / sides
		var side_up := curl * pow(absf(cos(a)), 2.0) # laterais sobem
		var front := -0.035 * curl / 0.08 * maxf(0.0, -sin(a)) # frente cai (o modelo olha para -z)
		out.append(Vector3(cos(a) * r, y + side_up + front + 0.012 * curl / 0.08 * maxf(0.0, sin(a)), sin(a) * rz + 0.03))
	return out

static func x_hat() -> ArrayMesh:
	var st := begin()
	var paint := plain_paint(0.2)
	var sides := 12
	var rings := [_brim_ring(0.27, 0.27, 1.84, 0.0, sides), _brim_ring(0.4, 0.38, 1.82, 0.03, sides), _brim_ring(0.53, 0.5, 1.8, 0.085, sides)]
	for k in 2:
		var a: PackedVector3Array = rings[k]
		var b: PackedVector3Array = rings[k + 1]
		for i in sides:
			var j := (i + 1) % sides
			Facets.tri(st, a[i], a[j], b[j], Vector3.UP, paint)
			Facets.tri(st, a[i], b[j], b[i], Vector3.UP, paint)
			Facets.tri(st, a[i], b[j], a[j], Vector3.DOWN, paint)
			Facets.tri(st, a[i], b[i], b[j], Vector3.DOWN, paint)
	# copa: afina para cima e o topo tem um vinco (mais baixo no meio)
	var crown := [ring_axis(Vector3(0, 1.82, 0.02), Vector3.UP, 0.27, 0.26, 10), ring_axis(Vector3(0, 1.99, 0.02), Vector3.UP, 0.25, 0.235, 10),
		ring_axis(Vector3(0, 2.08, 0.02), Vector3.UP, 0.19, 0.15, 10)]
	Facets.loft(st, crown, Vector3(0, 2.03, 0.02), null, paint)
	return st.commit()

static func x_hat_band() -> ArrayMesh:
	var st := begin()
	var rings := [ring_axis(Vector3(0, 1.86, 0.02), Vector3.UP, 0.275, 0.265, 10), ring_axis(Vector3(0, 1.92, 0.02), Vector3.UP, 0.265, 0.255, 10)]
	Facets.loft(st, rings, null, null, plain_paint(0.1))
	tube(st, [Vector3(0.24, 1.9, 0.08), Vector3(0.3, 2.04, 0.2), Vector3(0.3, 2.14, 0.34)], [0.04, 0.035, 0.01], plain_paint(0.1), 4, true, 0.35)
	return st.commit()

static func x_scarf() -> ArrayMesh:
	var st := begin()
	var rings := [ring_axis(Vector3(0, 1.36, 0), Vector3.UP, 0.25, 0.2, 8), ring_axis(Vector3(0, 1.45, 0), Vector3.UP, 0.19, 0.16, 8)]
	Facets.loft(st, rings, null, null, plain_paint(0.12))
	return st.commit()

static func x_scarf_tail() -> ArrayMesh:
	var st := begin()
	tube(st, [Vector3(-0.08, 1.38, -0.17), Vector3(-0.12, 1.22, -0.21), Vector3(-0.1, 1.08, -0.2)], [0.06, 0.05, 0.03], plain_paint(0.12), 4, true, 0.4)
	return st.commit()

## Capa: presa nos ombros (origem no topo), cai e abre para tras.
static func x_cape() -> ArrayMesh:
	var st := begin()
	var paint := plain_paint(0.15)
	var cols := 5
	var rows := [[0.0, 0.0, 0.26], [-0.35, 0.06, 0.33], [-0.72, 0.12, 0.38], [-0.96, 0.16, 0.41]]
	var grid := []
	for r in rows:
		var line := []
		for c in cols:
			var t := (c / float(cols - 1)) * 2.0 - 1.0
			line.append(Vector3(t * r[2], r[0], r[1] + 0.05 * (1.0 - t * t) + (0.03 if c % 2 == 1 else 0.0)))
		grid.append(line)
	for r in rows.size() - 1:
		for c in cols - 1:
			var a: Vector3 = grid[r][c]
			var b: Vector3 = grid[r][c + 1]
			var d: Vector3 = grid[r + 1][c]
			var e: Vector3 = grid[r + 1][c + 1]
			Facets.tri(st, a, b, e, Vector3(0, 0, 1), paint)
			Facets.tri(st, a, e, d, Vector3(0, 0, 1), paint)
			Facets.tri(st, a, e, b, Vector3(0, 0, -1), paint)
			Facets.tri(st, a, d, e, Vector3(0, 0, -1), paint)
	return st.commit()

static func x_pack() -> ArrayMesh:
	var st := begin()
	var rings := [ring_axis(Vector3(0, 0.92, 0.33), Vector3.UP, 0.22, 0.13, 6), ring_axis(Vector3(0, 1.3, 0.34), Vector3.UP, 0.21, 0.13, 6)]
	Facets.loft(st, rings, true, true, plain_paint(0.2))
	tube(st, [Vector3(0, 1.0, 0.44), Vector3(0, 1.14, 0.45)], [0.11, 0.1], plain_paint(0.25), 5, false, 0.5)
	return st.commit()

static func x_roll() -> ArrayMesh:
	var st := begin()
	tube(st, [Vector3(-0.24, 1.38, 0.36), Vector3(0.24, 1.38, 0.36)], [0.085, 0.085], plain_paint(0.15), 7, false)
	return st.commit()

static func x_strap() -> ArrayMesh:
	var st := begin()
	for x in [-0.12, 0.12]:
		tube(st, [Vector3(x, 1.38, 0.36), Vector3(x, 1.38, 0.46)], [0.09, 0.09], plain_paint(0.1), 6, false, 0.4)
	return st.commit()

static func x_lantern() -> ArrayMesh:
	var st := begin()
	var p := Vector3(0.24, 1.0, 0.38)
	var rings := [ring_axis(p + Vector3(0, 0.06, 0), Vector3.UP, 0.05, 0.05, 5), ring_axis(p - Vector3(0, 0.04, 0), Vector3.UP, 0.04, 0.04, 5)]
	Facets.loft(st, rings, p + Vector3(0, 0.14, 0), p - Vector3(0, 0.1, 0), plain_paint(0.05))
	return st.commit()

static func x_leg() -> ArrayMesh:
	var st := begin()
	tube(st, [Vector3(0, 0.02, 0), Vector3(0, -0.3, -0.02), Vector3(0, -0.6, 0.0)], [0.12, 0.1, 0.085], plain_paint(0.15), 7, false)
	return st.commit()

static func x_boot() -> ArrayMesh:
	var st := begin()
	var paint := plain_paint(0.18)
	tube(st, [Vector3(0, -0.56, 0.0), Vector3(0, -0.74, 0.0)], [0.11, 0.105], paint, 7, false)
	var rings := [ring_axis(Vector3(0, -0.77, 0.06), Vector3.FORWARD, 0.11, 0.06, 6), ring_axis(Vector3(0, -0.77, -0.12), Vector3.FORWARD, 0.1, 0.06, 6)]
	Facets.loft(st, rings, Vector3(0, -0.78, -0.2), true, paint)
	tube(st, [Vector3(0, -0.53, 0), Vector3(0, -0.6, 0)], [0.13, 0.13], plain_paint(0.05), 7, false)
	return st.commit()

static func x_sleeve() -> ArrayMesh:
	var st := begin()
	tube(st, [Vector3(0, 0.04, 0), Vector3(0.02, -0.22, 0.0), Vector3(0.02, -0.38, -0.02)], [0.1, 0.085, 0.075], plain_paint(0.15), 6, false)
	return st.commit()

static func x_bracer() -> ArrayMesh:
	var st := begin()
	tube(st, [Vector3(0.02, -0.34, -0.02), Vector3(0.02, -0.48, -0.04)], [0.085, 0.075], plain_paint(0.2), 6, false)
	return st.commit()

static func x_hand() -> ArrayMesh:
	var st := begin()
	var rings := [ring_axis(Vector3(0.02, -0.5, -0.04), Vector3.DOWN, 0.06, 0.05, 6), ring_axis(Vector3(0.02, -0.58, -0.05), Vector3.DOWN, 0.065, 0.055, 6)]
	Facets.loft(st, rings, Vector3(0.02, -0.64, -0.06), true, plain_paint(0.12))
	return st.commit()

static func x_haft() -> ArrayMesh:
	var st := begin()
	tube(st, [Vector3(0.02, -0.56, 0.12), Vector3(0.02, -0.6, -0.2), Vector3(0.02, -0.62, -0.62)], [0.03, 0.03, 0.028], plain_paint(0.15), 5, false)
	return st.commit()

## Lamina de pedra lascada na ponta do cabo.
static func x_axe_head() -> ArrayMesh:
	var st := begin()
	var paint := plain_paint(0.25)
	var c := Vector3(0.02, -0.6, -0.56)
	var pts := [c + Vector3(0, 0.02, 0.08), c + Vector3(0, 0.26, 0.04), c + Vector3(0, 0.3, -0.12), c + Vector3(0, 0.08, -0.16), c + Vector3(0, -0.06, -0.04)]
	var w := Vector3(0.05, 0, 0)
	for i in pts.size():
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % pts.size()]
		Facets.tri(st, a - w, b - w * 0.3, b + w * 0.3, (a + b) * 0.5 - c, paint)
		Facets.tri(st, a - w, b + w * 0.3, a + w, (a + b) * 0.5 - c, paint)
	for s in [-1.0, 1.0]:
		for i in range(1, pts.size() - 1):
			Facets.tri(st, pts[0] + w * s, pts[i] + w * s * 0.3, pts[i + 1] + w * s * 0.3, Vector3(s, 0, 0), paint)
	return st.commit()

static func x_wrap() -> ArrayMesh:
	var st := begin()
	tube(st, [Vector3(0.02, -0.6, -0.48), Vector3(0.02, -0.61, -0.6)], [0.045, 0.045], plain_paint(0.1), 5, false)
	return st.commit()

static func x_eye() -> ArrayMesh:
	var st := begin()
	var rings := [ring_axis(Vector3(0, 0, 0), Vector3.FORWARD, 0.032, 0.042, 5), ring_axis(Vector3(0, 0, -0.012), Vector3.FORWARD, 0.025, 0.034, 5)]
	Facets.loft(st, rings, Vector3(0, 0, -0.018), true, plain_paint(0.0))
	return st.commit()
