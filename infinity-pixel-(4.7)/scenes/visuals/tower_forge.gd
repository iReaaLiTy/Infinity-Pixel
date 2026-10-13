extends RefCounted

# Design Overhaul 5.0 — familia arquitetonica das Torres de Defesa (so visual).
#
# Tres niveis evolutivos da MESMA linguagem:
#   base   — plinto octogonal, blocos de pedra facetados em fiadas desencontradas,
#            porta com verga, pedras de fundacao com musgo, ornamento fossil;
#   corpo  — alvenaria vertical, madeira de sustentacao amarrada com corda,
#            runas de jade (L2+), galeria de madeira (L2) e janelas (L3);
#   topo   — plataforma defensiva (deck com paliçada no L1, parapeito com
#            ameias no L2/L3) e o mecanismo de disparo, que GIRA para o alvo:
#            balista de madeira (L1), besta de costelas fosseis (L2) e coroa de
#            presas com o grande cristal (L3).
#
# Malhas low-poly facetadas com cor por vertice (Facets), geradas UMA vez por
# nivel e compartilhadas por todas as torres (instanciamento por recurso).
# Nada aqui le ou muda dano, alcance, cadencia, alvo, colisao ou navegacao: o
# corpo fisico continua o cilindro de 0,8 m x 2,4 m do defense_tower.gd. Abaixo
# de 2 m nada passa de 1,0 m do eixo (o colisor + o raio do Player ja mantem
# todo mundo a mais de 1,1 m): a arte nunca vira obstaculo invisivel.
# Frente da torre (porta) = +Z, voltada para a camera estrategica.

const Facets := preload("res://scenes/visuals/facets.gd")
const Palette := preload("res://scenes/visuals/palette.gd")
const SurfaceFinish := preload("res://scenes/visuals/surface_finish.gd")

# Paleta da direcao de arte 5.0 (tom desejado na tela; o toon aplica ALBEDO_SCALE).
const JADE := Color("69c7a0")
const JADE_DEEP := Color("19382f")
const JADE_MID := Color("2f7f68")
const STONE_LIGHT := Color("b6b5a1")
const STONE := Color("8e8f7d")
const STONE_DARK := Color("555e56")
const STONE_WARM := Color("a49b86")
const WOOD := Color("79543e")
const WOOD_LIGHT := Color("94694a")
const WOOD_DARK := Color("49362c")
const IVORY := Color("e8dfca")
const IVORY_SHADE := Color("c4b79a")
const AMBER := Color("d5a45e")
const ROPE := Color("b58f5c")
const MOSS := Color("6a9152")
const MOSS_DARK := Color("4a7040")
const DOOR := Color("231f1b")
const IRON := Color("3d4340")
# Emissao do cristal: jade PROFUNDO. A noite a energia sobe, mas a cor nao
# estoura em branco (antes: #7fd8b0 x 2,2 saturava no tonemap).
const CRYSTAL_EMISSION := Color("1f8a66")
const RUNE_EMISSION := Color("2fa57c")

## Altura do pivo do mecanismo (topo da plataforma) e do topo da silhueta.
const HEAD_Y := [2.2, 2.62, 2.54]

static var _cache := {}
static var _toon: StandardMaterial3D

## Material toon compartilhado por todas as torres (corpo e mecanismo).
static func material() -> StandardMaterial3D:
	if _toon == null:
		_toon = SurfaceFinish.finished(Palette.toon(0.28, 0.14)) as StandardMaterial3D
	return _toon

## Material de brilho (cristal/runas): um por torre, a energia anima por torre.
static func glow_material() -> StandardMaterial3D:
	var m := Palette.toon_glow(CRYSTAL_EMISSION, 0.2, 0.3)
	m.resource_name = "tower_glow"
	return m

## Partes do nivel (1..3): {body, glow, head, head_glow, crystal, crystal_pos,
## head_y, orbit (L3: lascas que orbitam), top}. Malhas cacheadas.
static func parts(level: int) -> Dictionary:
	level = clampi(level, 1, 3)
	if not _cache.has(level):
		match level:
			1: _cache[level] = _level1()
			2: _cache[level] = _level2()
			_: _cache[level] = _level3()
	return _cache[level]

# ---------------------------------------------------------------------------
# Pintura
# ---------------------------------------------------------------------------

static func _hash(v: Vector3) -> float:
	return fposmod(sin(v.x * 12.9898 + v.y * 78.233 + v.z * 37.719) * 43758.5453, 1.0)

## Variacao estavel por face + volume "assado" (Facets.facet_shade).
static func _shade(col: Color, c: Vector3, n: Vector3, amount := 0.07) -> Color:
	var v := _hash(c * 3.7 + n * 1.3)
	col = col.lightened(amount * (v - 0.5) * 2.0) if v > 0.5 else col.darkened(amount * (0.5 - v) * 2.0)
	return Facets.facet_shade(col, n)

static func _flat(col: Color, amount := 0.07) -> Callable:
	return func(c: Vector3, n: Vector3) -> Color: return _shade(col, c, n, amount)

## Pedra: tom do bloco (estado), chanfro de cima claro (aresta gasta), base do
## bloco escura (oclusao), musgo nas faces de cima conforme a chance do estado.
static func _stone_paint(state: Dictionary) -> Callable:
	return func(c: Vector3, n: Vector3) -> Color:
		var base: Color = state.tone
		if n.y > 0.8 and state.moss > 0.0 and _hash(c * 5.1) < state.moss:
			base = MOSS if _hash(c * 2.3) > 0.35 else MOSS_DARK
		elif n.y > 0.25 and n.y <= 0.8:
			base = base.lightened(0.12)
		elif n.y < -0.2:
			base = base.darkened(0.22)
		return _shade(base, c, n, 0.08)

## Madeira: tom do estado; topo claro (corte), lados com veio (faixas alternadas).
static func _wood_paint(state: Dictionary) -> Callable:
	return func(c: Vector3, n: Vector3) -> Color:
		var base: Color = state.tone
		if absf(n.y) > 0.85:
			base = base.lightened(0.1)
		elif fposmod((c.x + c.z) * 9.0 + c.y * 2.0, 1.0) < 0.3:
			base = base.darkened(0.1) # veio estilizado
		return _shade(base, c, n, 0.06)

static func _gem_paint(dark: Color, light: Color, y0: float, y1: float) -> Callable:
	return func(c: Vector3, n: Vector3) -> Color:
		var col := dark.lerp(light, clampf((c.y - y0) / maxf(0.01, y1 - y0), 0.0, 1.0))
		return col.lightened(0.14) if fposmod(atan2(n.z, n.x) / TAU * 6.0, 2.0) < 1.0 else col.darkened(0.1)

# ---------------------------------------------------------------------------
# Geometria
# ---------------------------------------------------------------------------

## Base com Y ao longo de `axis`. `face` (opcional): o Z local (a espessura das
## pecas planas) aponta para ela — runas, tabuas e paineis ficam de frente.
static func _basis_along(axis: Vector3, face := Vector3.ZERO) -> Basis:
	var y := axis.normalized()
	if face != Vector3.ZERO:
		var zf := face - y * face.dot(y)
		if zf.length_squared() > 1e-6:
			zf = zf.normalized()
			return Basis(y.cross(zf), y, zf)
	var ref := Vector3.UP if absf(y.y) < 0.95 else Vector3.BACK
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)

## Viga/poste de secao poligonal entre a e b (meia largura w x meia espessura d;
## a espessura aponta para `face`, se dada). `tip` = true: ponta afiada (estaca).
static func _beam(st: SurfaceTool, a: Vector3, b: Vector3, w: float, d: float, paint: Callable, sides := 4, taper := 1.0, face := Vector3.ZERO, tip := false) -> void:
	var axis := b - a
	var length := axis.length()
	if length < 0.001:
		return
	var xf := Transform3D(_basis_along(axis, face), a)
	var k := 1.0 / cos(PI / sides)
	var rings := []
	var steps := [0.0, 0.82 if tip else 1.0]
	for t in steps:
		var ring := PackedVector3Array()
		var s := lerpf(1.0, taper, t)
		for i in sides:
			var ang := TAU * i / sides + PI / sides
			ring.append(xf * Vector3(cos(ang) * w * k * s, t * length, sin(ang) * d * k * s))
		rings.append(ring)
	Facets.loft(st, rings, b if tip else true, true, paint)

## Losango em relevo voltado para +Z (placas de jade, estandartes).
static func _diamond(st: SurfaceTool, at: Vector3, size: float, depth: float, paint: Callable) -> void:
	var front := PackedVector3Array()
	var back := PackedVector3Array()
	for q in [Vector2(0, 1), Vector2(0.62, 0), Vector2(0, -1), Vector2(-0.62, 0)]:
		back.append(at + Vector3(q.x * size, q.y * size, -depth * 0.5))
		front.append(at + Vector3(q.x * size * 0.82, q.y * size * 0.82, depth * 0.5))
	Facets.loft(st, [back, front], true, true, paint)

## Prisma vertical octogonal/poligonal (degrau, laje, nucleo).
static func _prism(st: SurfaceTool, at: Vector3, r0: float, r1: float, h: float, sides: int, paint: Callable, phase := 0.0) -> void:
	var a := PackedVector3Array()
	var b := PackedVector3Array()
	for i in sides:
		var ang := phase + TAU * i / sides
		a.append(at + Vector3(sin(ang) * r0, 0, cos(ang) * r0))
		b.append(at + Vector3(sin(ang) * r1, h, cos(ang) * r1))
	Facets.loft(st, [a, b], true, true, paint)

## Bloco de pedra: setor de anel entre os angulos a0..a1 (0 = +Z), do raio ri
## ao raio externo ro0 (embaixo) / ro1 (em cima), com chanfro b em cima e
## embaixo e uma junta vertical estreita com os vizinhos.
static func _block(st: SurfaceTool, a0: float, a1: float, ri: float, ro0: float, ro1: float, y0: float, y1: float, b: float, paint: Callable) -> void:
	var section := func(y: float, ro: float, inset: float, side: float) -> PackedVector3Array:
		var pts := PackedVector3Array()
		var da := side / maxf(ro, 0.1)
		for q in [[ri, a0 + da], [ro - inset, a0 + da], [ro - inset, a1 - da], [ri, a1 - da]]:
			pts.append(Vector3(sin(q[1]) * q[0], y, cos(q[1]) * q[0]))
		return pts
	var rm0 := lerpf(ro0, ro1, b / maxf(y1 - y0, 0.01))
	var rm1 := lerpf(ro0, ro1, 1.0 - b / maxf(y1 - y0, 0.01))
	Facets.loft(st, [section.call(y0, ro0, b, b * 0.9), section.call(y0 + b, rm0, 0.0, 0.012),
		section.call(y1 - b, rm1, 0.0, 0.012), section.call(y1, ro1, b, b * 0.9)], true, true, paint)

## Alvenaria em fiadas desencontradas (running bond). Fiadas abaixo de `door_top`
## deixam o vao da porta (centrado em +Z, meia abertura `door_half` em rad).
static func _masonry(st: SurfaceTool, rng: RandomNumberGenerator, y0: float, y1: float, courses: int, r0: float, r1: float, ri: float, blocks: int, bevel: float, tones: Array, moss_first: float, door_top := -1.0, door_half := 0.0, moss_top := 0.0) -> void:
	var state := {"tone": STONE, "moss": 0.0}
	var paint := _stone_paint(state)
	for k in courses:
		var ya := lerpf(y0, y1, float(k) / courses)
		var yb := lerpf(y0, y1, float(k + 1) / courses)
		var ra := lerpf(r0, r1, float(k) / courses)
		var rb := lerpf(r0, r1, float(k + 1) / courses)
		var in_door := yb <= door_top + 0.01
		# Fiadas da porta: um bloco centrado na frente (pulado = vao). Acima,
		# alternam meio bloco (juntas desencontradas).
		var phase := -PI / blocks if in_door or k % 2 == 0 else 0.0
		phase += rng.randf_range(-0.03, 0.03) if not in_door else 0.0
		for i in blocks:
			var a0 := phase + TAU * i / blocks
			var a1 := phase + TAU * (i + 1) / blocks
			var mid := wrapf((a0 + a1) * 0.5, -PI, PI)
			if in_door and absf(mid) < door_half:
				continue
			state.tone = tones[rng.randi() % tones.size()]
			state.moss = moss_first if k == 0 else (moss_top if k == courses - 1 else 0.0)
			var out := rng.randf_range(-0.012, 0.02)
			var hy := rng.randf_range(-0.012, 0.012)
			_block(st, a0, a1, ri, ra + out, rb + out, ya, yb + hy * (0.0 if k == courses - 1 else 1.0), bevel, paint)

## Pedra de fundacao irregular (5 lados), meio enterrada, musgo no topo.
static func _boulder(st: SurfaceTool, rng: RandomNumberGenerator, at: Vector3, s: float, h: float) -> void:
	var state := {"tone": [STONE, STONE_DARK, STONE_WARM][rng.randi() % 3], "moss": 0.55}
	var paint := _stone_paint(state)
	var rings := []
	for spec in [[-0.04, 1.0], [h * 0.55, 0.95], [h, 0.6]]:
		var ring := Facets.ring(6, s * spec[1], spec[0], rng, 0.18, rng.randf() * TAU)
		for k in ring.size():
			ring[k] += at
		rings.append(ring)
	Facets.loft(st, rings, true, null, paint)

## Corda amarrando duas pecas de madeira (anel curto e grosso).
static func _lashing(st: SurfaceTool, at: Vector3, axis: Vector3, r: float) -> void:
	var paint := _flat(ROPE, 0.1)
	var d := axis.normalized() * 0.035
	_beam(st, at - d, at + d, r, r, paint, 6)

## Chifre/presa curva (marfim fossil): curva quadratica de `base` para fora
## (`out`) subindo `lift`; afina ate a ponta.
static func _horn(st: SurfaceTool, base: Vector3, out: Vector3, length: float, radius: float, lift: float, paint: Callable, segs := 4, sides := 5, curl := 0.8) -> void:
	var p0 := base
	var p1 := base + out * length * 0.62
	var p2 := base + out * length * curl + Vector3.UP * lift
	var rings := []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(base.x * 1000.0 + base.z * 77.0 + base.y * 13.0))
	for k in segs:
		var t := float(k) / segs
		var p := p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)
		var tangent := (p1 - p0).lerp(p2 - p1, t)
		var xf := Transform3D(_basis_along(tangent), p)
		rings.append(Facets.ring(sides, radius * (1.0 - t * 0.78), 0.0, rng, 0.0, 0.3, 0.0, xf))
	Facets.loft(st, rings, p2, true, paint)

## Cristal bipiramidal facetado com base em `at`, inclinado por `tilt`.
static func _gem(st: SurfaceTool, at: Vector3, r: float, h_up: float, h_down: float, sides: int, paint: Callable, tilt := Basis()) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(r * 1000.0 + h_up * 100.0)
	var xf := Transform3D(tilt, at)
	Facets.loft(st, [Facets.ring(sides, r, 0.0, rng, 0.05, 0.1, 0.0, xf), Facets.ring(sides, r * 0.9, h_up * 0.22, rng, 0.05, 0.25, 0.0, xf)],
		xf * Vector3(0.0, h_up, 0.0), xf * Vector3(0.0, -h_down, 0.0), paint)

## Amonite em relevo (medalhao fossil) na face de normal `facing`.
static func _ammonite(st: SurfaceTool, at: Vector3, facing: Vector3, r: float) -> void:
	var b := _basis_along(facing)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ivory := _flat(IVORY, 0.05)
	var shade := _flat(IVORY_SHADE, 0.05)
	var xf := Transform3D(b, at)
	Facets.loft(st, [Facets.ring(9, r, 0.0, rng, 0.0, 0.0, 0.0, xf), Facets.ring(9, r * 0.92, 0.035, rng, 0.0, 0.0, 0.0, xf)], true, true, ivory)
	# espiral: tres camaras concentricas em degraus
	for k in 3:
		var rr := r * (0.68 - k * 0.2)
		var off := Vector3(r * 0.08 * k, 0.0, -r * 0.05 * k)
		var xk := Transform3D(b, at + b * (off + Vector3(0, 0.035 + 0.012 * (k + 1), 0)))
		Facets.loft(st, [Facets.ring(8, rr, -0.012, rng, 0.0, k * 0.4, 0.0, xk), Facets.ring(8, rr * 0.85, 0.0, rng, 0.0, k * 0.4, 0.0, xk)], true, null, shade if k % 2 == 0 else ivory)

## Porta: vao escuro recuado, folha de tabuas com travessa, soleira.
static func _door(st: SurfaceTool, r_face: float, y0: float, half_w: float, h: float) -> void:
	var dark := _flat(DOOR, 0.04)
	var z := r_face - 0.1
	_beam(st, Vector3(0, y0, z - 0.06), Vector3(0, y0 + h, z - 0.06), half_w + 0.04, 0.05, dark)
	var wood := {"tone": WOOD}
	var wp := _wood_paint(wood)
	for i in 3:
		wood.tone = [WOOD, WOOD_LIGHT, WOOD_DARK][i % 3]
		var x := lerpf(-half_w * 0.66, half_w * 0.66, i / 2.0)
		_beam(st, Vector3(x, y0 + 0.01, z), Vector3(x, y0 + h * 0.94, z), half_w * 0.31, 0.025, wp)
	wood.tone = WOOD_DARK
	_beam(st, Vector3(-half_w * 0.95, y0 + h * 0.35, z + 0.03), Vector3(half_w * 0.95, y0 + h * 0.35, z + 0.03), 0.025, 0.02, wp)
	_beam(st, Vector3(-half_w * 0.95, y0 + h * 0.72, z + 0.03), Vector3(half_w * 0.95, y0 + h * 0.72, z + 0.03), 0.025, 0.02, wp)
	# argola de ferro
	_beam(st, Vector3(half_w * 0.45, y0 + h * 0.5, z + 0.035), Vector3(half_w * 0.45, y0 + h * 0.5 + 0.001, z + 0.06), 0.03, 0.03, _flat(IRON), 6)
	# soleira de pedra
	_beam(st, Vector3(-half_w - 0.06, y0, r_face - 0.02), Vector3(half_w + 0.06, y0, r_face - 0.02), 0.035, 0.09, _flat(STONE_LIGHT), 4)

## Ombreiras e verga reta (L1) ou arco de aduelas (L2/L3) em volta da porta.
static func _door_frame(st: SurfaceTool, r_face: float, y0: float, half_w: float, h: float, arch: bool, keystone_ammonite: bool) -> void:
	var state := {"tone": STONE_LIGHT, "moss": 0.0}
	var paint := _stone_paint(state)
	for s: float in [-1.0, 1.0]:
		state.tone = STONE_LIGHT if s < 0 else STONE_WARM
		var x := s * (half_w + 0.05)
		_beam(st, Vector3(x, y0, r_face + 0.01), Vector3(x, y0 + h, r_face + 0.01), 0.06, 0.07, paint)
	if not arch:
		state.tone = STONE_WARM
		_beam(st, Vector3(-half_w - 0.14, y0 + h + 0.06, r_face + 0.02), Vector3(half_w + 0.14, y0 + h + 0.06, r_face + 0.02), 0.07, 0.08, paint)
		if keystone_ammonite:
			_ammonite(st, Vector3(0, y0 + h + 0.24, r_face + 0.0), Vector3(0, 0, 1), 0.085)
		return
	# arco de 5 aduelas sobre as ombreiras
	var rad := half_w + 0.05
	var cy := y0 + h
	for i in 5:
		var t0 := PI * i / 5.0
		var t1 := PI * (i + 1) / 5.0
		state.tone = IVORY if i == 2 else [STONE_LIGHT, STONE_WARM][i % 2]
		var p0 := Vector3(cos(t0) * rad, cy + sin(t0) * rad, r_face + 0.015)
		var p1 := Vector3(cos(t1) * rad, cy + sin(t1) * rad, r_face + 0.015)
		_beam(st, p0, p1, 0.065 if i != 2 else 0.075, 0.08, paint, 4)
	if keystone_ammonite:
		_ammonite(st, Vector3(0, cy + rad + 0.2, r_face - 0.01), Vector3(0, 0, 1), 0.1)
	# vao do arco (escuro, recuado)
	var dark := _flat(DOOR, 0.03)
	var fan := PackedVector3Array()
	for i in 7:
		var t := PI * i / 6.0
		fan.append(Vector3(cos(t) * (rad - 0.04), cy + sin(t) * (rad - 0.04), r_face - 0.14))
	for i in 6:
		Facets.tri(st, Vector3(0, cy, r_face - 0.14), fan[i], fan[i + 1], Vector3(0, 0, 1), dark)

## Deck de tabuas (quadrado) com caibros salientes por baixo.
static func _plank_deck(st: SurfaceTool, y: float, half: float, planks: int, thick := 0.07) -> void:
	var wood := {"tone": WOOD}
	var paint := _wood_paint(wood)
	var w := half / planks
	for i in planks:
		wood.tone = [WOOD, WOOD_LIGHT, WOOD, WOOD_DARK][i % 4]
		var z := -half + w * (2 * i + 1)
		var jitter := 0.03 * sin(i * 2.7)
		_beam(st, Vector3(-half - jitter, y, z), Vector3(half + jitter, y, z), w * 0.92, thick * 0.5, paint, 4, 1.0, Vector3.UP)
	wood.tone = WOOD_DARK
	for x in [-half * 0.62, half * 0.62]:
		_beam(st, Vector3(x, y - thick * 0.9, -half - 0.12), Vector3(x, y - thick * 0.9, half + 0.12), 0.05, 0.05, paint)

## Parapeito de pedra octogonal com ameias (merloes) e laje de piso.
static func _parapet(st: SurfaceTool, rng: RandomNumberGenerator, y: float, r_out: float, wall_h: float, merlon_h: float, tones: Array, skip_diagonal := false) -> void:
	var state := {"tone": STONE, "moss": 0.0}
	var paint := _stone_paint(state)
	state.tone = STONE_DARK
	_prism(st, Vector3(0, y - 0.1, 0), r_out - 0.04, r_out, 0.1, 8, paint, PI / 8.0)
	for i in 8:
		var a0 := TAU * i / 8.0 - PI / 8.0
		var a1 := a0 + TAU / 8.0
		state.tone = tones[rng.randi() % tones.size()]
		state.moss = 0.25
		_block(st, a0, a1, r_out - 0.13, r_out, r_out - 0.01, y, y + wall_h, 0.025, paint)
		# merlao no meio de cada lado (o vao entre eles = ameia); nas diagonais
		# do L3 ficam os pinaculos
		if skip_diagonal and i % 2 == 1:
			continue
		var am := (a0 + a1) * 0.5
		state.tone = tones[rng.randi() % tones.size()]
		state.moss = 0.35
		_block(st, am - 0.2, am + 0.2, r_out - 0.12, r_out - 0.005, r_out - 0.02, y + wall_h - 0.01, y + wall_h + merlon_h, 0.03, paint)

# ---------------------------------------------------------------------------
# Plinto (comum aos tres niveis, cresce com o nivel)
# ---------------------------------------------------------------------------

static func _plinth(st: SurfaceTool, rng: RandomNumberGenerator, r: float, h: float, boulders: int) -> void:
	var state := {"tone": STONE_DARK, "moss": 0.0}
	var paint := _stone_paint(state)
	var rings := [Facets.ring(8, r, -0.03, rng, 0.015, PI / 8.0), Facets.ring(8, r - 0.015, h * 0.6, rng, 0.015, PI / 8.0),
		Facets.ring(8, r - 0.07, h, rng, 0.01, PI / 8.0)]
	Facets.loft(st, rings, true, null, paint)
	for i in boulders:
		var a := PI * 0.32 + TAU * i / boulders + rng.randf_range(-0.15, 0.15)
		if absf(wrapf(a, -PI, PI)) < 0.5:
			a += 0.6 # a frente (porta) fica livre
		var p := Vector3(sin(a) * (r - 0.04), 0.0, cos(a) * (r - 0.04))
		_boulder(st, rng, p, rng.randf_range(0.13, 0.19), rng.randf_range(0.16, 0.26))

# ---------------------------------------------------------------------------
# NIVEL 1 — SENTINELA DO JADE: alvenaria baixa, quadro de madeira com mao-
# francesa em X, deck de tabuas com paliçada de estacas e balista simples.
# ---------------------------------------------------------------------------
static func _level1() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5101
	var st := _begin()
	var glow := _begin()
	var stones := [STONE, STONE_LIGHT, STONE_WARM, STONE]
	_plinth(st, rng, 0.96, 0.2, 5)
	_masonry(st, rng, 0.2, 1.3, 4, 0.7, 0.6, 0.26, 10, 0.035, stones, 0.45, 0.75, 0.3)
	_door(st, 0.69, 0.2, 0.15, 0.52)
	_door_frame(st, 0.69, 0.2, 0.15, 0.52, false, true)
	# nucleo de pedra escura sob o deck (o quadro de madeira e aberto)
	_prism(st, Vector3(0, 1.28, 0), 0.34, 0.3, 0.86, 8, _flat(STONE_DARK, 0.06), PI / 8.0)
	# quadro: 4 postes nos cantos, maos-francesas em X em cada face
	var wood := {"tone": WOOD}
	var wp := _wood_paint(wood)
	var posts := []
	for i in 4:
		var a := PI / 4.0 + TAU * i / 4.0
		posts.append(Vector3(sin(a), 0, cos(a)))
	for p in posts:
		wood.tone = WOOD
		_beam(st, p * 0.6 + Vector3(0, 1.1, 0), p * 0.5 + Vector3(0, 2.18, 0), 0.07, 0.07, wp, 5, 0.9)
	for i in 4:
		var p0: Vector3 = posts[i] * 0.55
		var p1: Vector3 = posts[(i + 1) % 4] * 0.55
		wood.tone = WOOD_DARK
		_beam(st, p0 + Vector3(0, 1.32, 0), p1 + Vector3(0, 2.04, 0), 0.035, 0.03, wp)
		_beam(st, p1 + Vector3(0, 1.32, 0), p0 + Vector3(0, 2.04, 0), 0.035, 0.03, wp)
		_lashing(st, p0.lerp(p1, 0.5) + Vector3(0, 1.68, 0), p1 - p0, 0.045)
	for p in posts:
		_lashing(st, p * 0.58 + Vector3(0, 1.36, 0), Vector3.UP, 0.085)
		_lashing(st, p * 0.52 + Vector3(0, 2.02, 0), Vector3.UP, 0.08)
	# deck e paliçada de estacas afiadas (com uma travessa amarrada)
	_plank_deck(st, 2.16, 0.66, 6)
	for side in 4:
		var a := TAU * side / 4.0
		var along := Vector3(cos(a), 0, -sin(a))
		var out := Vector3(sin(a), 0, cos(a))
		for k in 4:
			if side == 0 and (k == 1 or k == 2):
				continue # abertura na frente: o mecanismo aponta por cima
			var p: Vector3 = out * 0.62 + along * lerpf(-0.5, 0.5, k / 3.0) + Vector3(0, 2.2, 0)
			wood.tone = [WOOD, WOOD_LIGHT][k % 2]
			_beam(st, p, p + Vector3(0, 0.3 + 0.05 * (k % 2), 0) + out * 0.04, 0.04, 0.04, wp, 5, 1.0, Vector3.ZERO, true)
		wood.tone = WOOD_DARK
		_beam(st, out * 0.63 - along * 0.6 + Vector3(0, 2.33, 0), out * 0.63 + along * 0.6 + Vector3(0, 2.33, 0), 0.025, 0.025, wp)
	# garras fosseis nas pontas da frente
	for s: float in [-1.0, 1.0]:
		_horn(st, Vector3(s * 0.62, 2.24, 0.62), Vector3(s * 0.5, 0.2, 0.84).normalized(), 0.26, 0.045, 0.16, _flat(IVORY, 0.05), 3, 5)
	# jade: losango sobre a porta (marca do Refugio)
	_diamond(glow, Vector3(0, 1.14, 0.675), 0.085, 0.02, _flat(JADE, 0.05))
	# MECANISMO: balista de madeira com cristal na ponta do trilho
	var head := _begin()
	var hp := _wood_paint(wood)
	wood.tone = WOOD_DARK
	_prism(head, Vector3(0, 0.0, 0), 0.32, 0.3, 0.1, 8, hp)
	for s: float in [-1.0, 1.0]:
		wood.tone = WOOD
		_beam(head, Vector3(s * 0.12, 0.08, -0.04), Vector3(s * 0.12, 0.36, -0.02), 0.035, 0.07, hp)
	wood.tone = WOOD_LIGHT
	_beam(head, Vector3(0, 0.34, -0.34), Vector3(0, 0.36, 0.38), 0.05, 0.035, hp)
	for s: float in [-1.0, 1.0]:
		wood.tone = WOOD_DARK
		_beam(head, Vector3(0, 0.38, 0.3), Vector3(s * 0.22, 0.4, 0.24), 0.025, 0.022, hp)
		_beam(head, Vector3(s * 0.22, 0.4, 0.24), Vector3(s * 0.36, 0.41, 0.1), 0.022, 0.02, hp)
		_beam(head, Vector3(s * 0.36, 0.41, 0.1), Vector3(0, 0.39, -0.12), 0.008, 0.008, _flat(IVORY, 0.03))
	_lashing(head, Vector3(0, 0.37, 0.3), Vector3(0, 0, 1), 0.06)
	var crystal := _begin()
	_gem(crystal, Vector3.ZERO, 0.11, 0.24, 0.12, 6, _gem_paint(JADE_MID, Color("b9f0d6"), -0.12, 0.24))
	return _pack(st, glow, head, null, crystal, Vector3(0, 0.5, 0.4), HEAD_Y[0], false, 3.0)

# ---------------------------------------------------------------------------
# NIVEL 2 — GUARDIA DO VALE: contrafortes, alvenaria alta com faixa de runas,
# porta em arco com amonite, galeria de tabuas sobre misulas, parapeito com
# ameias e chifres fosseis, besta de costelas com cristal maior.
# ---------------------------------------------------------------------------
static func _level2() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5202
	var st := _begin()
	var glow := _begin()
	var stones := [STONE, STONE_LIGHT, STONE_WARM, STONE_LIGHT]
	_plinth(st, rng, 1.0, 0.24, 6)
	_masonry(st, rng, 0.24, 1.86, 6, 0.72, 0.6, 0.26, 12, 0.035, stones, 0.4, 0.78, 0.3)
	_door(st, 0.71, 0.24, 0.15, 0.5)
	_door_frame(st, 0.71, 0.24, 0.15, 0.36, true, true)
	_buttresses(st, rng, 4, 0.24, 1.25, 0.95, 0.62, 0.11, false)
	# faixa de runas (jade) na 4a fiada: seis glifos entre os contrafortes
	for i in 6:
		_rune(glow, TAU * i / 6.0 + PI / 6.0, 0.672, 1.1, i)
	# misulas (maos-francesas) sob a galeria
	var wood := {"tone": WOOD}
	var wp := _wood_paint(wood)
	for i in 8:
		var a := TAU * i / 8.0
		var out := Vector3(sin(a), 0, cos(a))
		wood.tone = WOOD_DARK
		_beam(st, out * 0.6 + Vector3(0, 1.62, 0), out * 0.78 + Vector3(0, 1.86, 0), 0.035, 0.035, wp)
	# galeria: piso de tabuas (octogono), postes e paineis de tabuas verticais
	wood.tone = WOOD_DARK
	_prism(st, Vector3(0, 1.84, 0), 0.82, 0.82, 0.07, 8, wp, PI / 8.0)
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		var p := Vector3(sin(a), 0, cos(a)) * 0.74
		wood.tone = WOOD
		_beam(st, p + Vector3(0, 1.9, 0), p + Vector3(0, 2.56, 0), 0.05, 0.05, wp, 5)
		_lashing(st, p + Vector3(0, 2.0, 0), Vector3.UP, 0.065)
	for i in 8:
		var a0 := TAU * i / 8.0 - PI / 8.0
		var a1 := a0 + TAU / 8.0
		var p0 := Vector3(sin(a0), 0, cos(a0)) * 0.72
		var p1 := Vector3(sin(a1), 0, cos(a1)) * 0.72
		for k in 3:
			var t := (k + 0.5) / 3.0
			if (i == 0 or i == 4) and k == 1:
				continue # seteira na frente e atras
			wood.tone = [WOOD, WOOD_LIGHT, WOOD][k]
			var p := p0.lerp(p1, t)
			_beam(st, p + Vector3(0, 1.9, 0), p + Vector3(0, 2.5 - 0.03 * k, 0), 0.075, 0.02, wp, 4, 1.0, (p0 + p1).normalized())
		wood.tone = WOOD_DARK
		_beam(st, p0 + Vector3(0, 2.3, 0) + (p0 + p1).normalized() * 0.03, p1 + Vector3(0, 2.3, 0) + (p0 + p1).normalized() * 0.03, 0.025, 0.02, wp)
	# ossos cruzados sob a seteira da frente (emblema pequeno)
	var ivory := _flat(IVORY, 0.05)
	_beam(st, Vector3(-0.13, 1.97, 0.775), Vector3(0.13, 2.19, 0.775), 0.02, 0.02, ivory, 5)
	_beam(st, Vector3(0.13, 1.97, 0.775), Vector3(-0.13, 2.19, 0.775), 0.02, 0.02, ivory, 5)
	# parapeito de pedra com ameias + chifres fosseis nos cantos diagonais
	_parapet(st, rng, 2.6, 0.84, 0.14, 0.17, [STONE_LIGHT, STONE_WARM, STONE])
	for i in 4:
		var a := PI / 4.0 + TAU * i / 4.0
		var out := Vector3(sin(a), 0, cos(a))
		_horn(st, out * 0.78 + Vector3(0, 2.86, 0), (out * 0.8 + Vector3.UP * 0.25).normalized(), 0.42, 0.065, 0.26, ivory, 4, 6)
	# MECANISMO: anel giratorio de pedra + besta de costelas fosseis
	var head := _begin()
	var head_glow := _begin()
	var hs := {"tone": STONE_LIGHT, "moss": 0.0}
	_prism(head, Vector3(0, 0.0, 0), 0.38, 0.35, 0.12, 8, _stone_paint(hs), PI / 8.0)
	_prism(head_glow, Vector3(0, 0.115, 0), 0.3, 0.3, 0.02, 8, _flat(JADE, 0.04), PI / 8.0)
	var hw := {"tone": WOOD}
	var hp := _wood_paint(hw)
	for s: float in [-1.0, 1.0]:
		hw.tone = WOOD
		_beam(head, Vector3(s * 0.15, 0.1, -0.06), Vector3(s * 0.14, 0.44, -0.02), 0.04, 0.08, hp)
	hw.tone = WOOD_DARK
	_beam(head, Vector3(0, 0.42, -0.42), Vector3(0, 0.44, 0.46), 0.06, 0.045, hp)
	hw.tone = AMBER.darkened(0.25)
	_beam(head, Vector3(0, 0.47, -0.36), Vector3(0, 0.48, 0.2), 0.022, 0.012, hp)
	for s: float in [-1.0, 1.0]:
		_horn(head, Vector3(s * 0.04, 0.47, 0.36), Vector3(s, 0.05, -0.35).normalized(), 0.5, 0.04, 0.08, ivory, 4, 5, 0.95)
		_beam(head, Vector3(s * 0.46, 0.53, 0.18), Vector3(0, 0.48, -0.16), 0.008, 0.008, _flat(ROPE.lightened(0.2), 0.03))
	# presas que seguram o cristal na ponta
	for s: float in [-1.0, 1.0]:
		_horn(head, Vector3(s * 0.08, 0.46, 0.4), Vector3(s * 0.3, 0.6, 0.5).normalized(), 0.22, 0.03, 0.12, ivory, 3, 5)
	var crystal := _begin()
	var gp := _gem_paint(JADE_MID, Color("c4f6de"), -0.16, 0.32)
	_gem(crystal, Vector3.ZERO, 0.15, 0.32, 0.16, 6, gp)
	for s: float in [-1.0, 1.0]:
		_gem(crystal, Vector3(s * 0.12, -0.06, -0.02), 0.05, 0.14, 0.05, 5, gp, Basis(Vector3(0, 0, 1), -s * 0.5))
	return _pack(st, glow, head, head_glow, crystal, Vector3(0, 0.62, 0.44), HEAD_Y[1], false, 3.5)

# ---------------------------------------------------------------------------
# NIVEL 3 — BASTIAO ANCESTRAL: oito contrafortes, alvenaria alta com duas faixas
# de runas, portal em arco com cranio de chifres, janelas acesas, cornija de
# misulas, parapeito com pinaculos de cristal, estandartes e a coroa de presas
# com o grande cristal (lascas orbitando).
# ---------------------------------------------------------------------------
static func _level3() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5303
	var st := _begin()
	var glow := _begin()
	var stones := [STONE_LIGHT, STONE_WARM, STONE_LIGHT, STONE]
	_plinth(st, rng, 1.02, 0.18, 0)
	# segundo degrau do plinto com runas no espelho
	_prism(st, Vector3(0, 0.16, 0), 0.92, 0.88, 0.1, 8, _stone_paint({"tone": STONE, "moss": 0.3}), PI / 8.0)
	for i in 8:
		var a := TAU * i / 8.0
		if i == 0:
			continue
		var out := Vector3(sin(a), 0, cos(a))
		_beam(glow, out * 0.915 + Vector3(0, 0.19, 0), out * 0.905 + Vector3(0, 0.24, 0), 0.06, 0.008, _flat(JADE, 0.04), 4, 1.0, out)
	_masonry(st, rng, 0.26, 2.34, 8, 0.74, 0.62, 0.26, 12, 0.032, stones, 0.35, 1.04, 0.3, 0.15)
	_door(st, 0.73, 0.26, 0.17, 0.62)
	_door_frame(st, 0.73, 0.26, 0.17, 0.46, true, false)
	_buttresses(st, rng, 8, 0.26, 1.55, 0.98, 0.64, 0.1, true)
	# cranio de chifres (frill em leque + 3 chifres) sobre o portal
	_skull(st, Vector3(0, 1.2, 0.74))
	# duas faixas de runas (seis glifos cada, desencontradas)
	for i in 6:
		_rune(glow, TAU * i / 6.0 + PI / 6.0, 0.67, 1.32, i)
		_rune(glow, TAU * i / 6.0, 0.636, 1.94, i + 3)
	# janelas em arco nas quatro diagonais (fundo aceso de jade)
	for i in 4:
		var a := PI / 4.0 + TAU * i / 4.0
		_window(st, glow, a, 0.645, 1.56, 0.09, 0.26)
	# cornija: misulas de pedra sob o parapeito
	var cs := {"tone": STONE, "moss": 0.0}
	var cp := _stone_paint(cs)
	for i in 16:
		var a := TAU * i / 16.0
		var out := Vector3(sin(a), 0, cos(a))
		cs.tone = [STONE, STONE_WARM][i % 2]
		_beam(st, out * 0.6 + Vector3(0, 2.2, 0), out * 0.8 + Vector3(0, 2.36, 0), 0.06, 0.05, cp, 4, 0.8, Vector3.UP)
	# caibros de madeira saindo sob o piso do parapeito
	var wood := {"tone": WOOD_DARK}
	var wp := _wood_paint(wood)
	for i in 4:
		var a := TAU * i / 4.0
		var out := Vector3(sin(a), 0, cos(a))
		_beam(st, out * 0.5 + Vector3(0, 2.4, 0), out * 0.98 + Vector3(0, 2.4, 0), 0.05, 0.05, wp)
	_parapet(st, rng, 2.52, 0.9, 0.16, 0.2, [STONE_LIGHT, STONE_WARM, STONE_LIGHT], true)
	# pinaculos nos cantos diagonais com cristais pequenos (acesos a noite)
	var ivory := _flat(IVORY, 0.05)
	for i in 4:
		var a := PI / 4.0 + TAU * i / 4.0
		var out := Vector3(sin(a), 0, cos(a))
		var p := out * 0.8
		var ps := {"tone": STONE_LIGHT, "moss": 0.2}
		_prism(st, p + Vector3(0, 2.5, 0), 0.13, 0.11, 0.62, 4, _stone_paint(ps), PI / 4.0 + a)
		_prism(st, p + Vector3(0, 3.1, 0), 0.15, 0.15, 0.05, 4, _stone_paint(ps), PI / 4.0 + a)
		_horn(st, p + Vector3(0, 2.86, 0) + out * 0.08, (out + Vector3.UP * 0.2).normalized(), 0.26, 0.04, 0.12, ivory, 3, 5)
		_gem(glow, p + Vector3(0, 3.15, 0), 0.07, 0.2, 0.04, 5, _flat(JADE, 0.05))
	# estandartes de pano jade com losango ambar, pendurados na frente
	for s: float in [-1.0, 1.0]:
		var x := s * 0.42
		var cloth := _flat(JADE_DEEP.lightened(0.12), 0.04)
		_beam(st, Vector3(x, 2.48, 0.86), Vector3(x, 1.88, 0.83), 0.12, 0.012, cloth, 4, 0.85)
		_diamond(st, Vector3(x, 2.15, 0.855), 0.1, 0.012, _flat(AMBER, 0.04))
		wood.tone = WOOD_DARK
		_beam(st, Vector3(x - 0.15, 2.48, 0.87), Vector3(x + 0.15, 2.48, 0.87), 0.018, 0.018, wp)
	# MECANISMO: base ornamentada + coroa de presas + mandibulas apontando o alvo
	var head := _begin()
	var head_glow := _begin()
	var hs := {"tone": STONE_LIGHT, "moss": 0.0}
	_prism(head, Vector3(0, 0.0, 0), 0.46, 0.42, 0.12, 8, _stone_paint(hs), PI / 8.0)
	hs.tone = STONE_WARM
	_prism(head, Vector3(0, 0.12, 0), 0.34, 0.28, 0.1, 8, _stone_paint(hs), 0.0)
	_prism(head_glow, Vector3(0, 0.115, 0), 0.4, 0.4, 0.02, 8, _flat(JADE, 0.04), PI / 8.0)
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		var out := Vector3(sin(a), 0, cos(a))
		_horn(head, out * 0.3 + Vector3(0, 0.18, 0), (out * 0.55 + Vector3.UP).normalized(), 0.62, 0.055, -0.12, ivory, 5, 6, 0.55)
	for s: float in [-1.0, 1.0]:
		_horn(head, Vector3(s * 0.14, 0.22, 0.3), Vector3(s * 0.25, 0.35, 1.0).normalized(), 0.55, 0.05, 0.06, ivory, 4, 5, 0.95)
	var crystal := _begin()
	var gp := _gem_paint(JADE_MID, Color("d2f9e6"), -0.22, 0.44)
	_gem(crystal, Vector3.ZERO, 0.21, 0.44, 0.22, 7, gp)
	for i in 3:
		var a := TAU * i / 3.0
		_gem(crystal, Vector3(sin(a) * 0.15, -0.12, cos(a) * 0.15), 0.06, 0.18, 0.05, 5, gp, Basis(Vector3(cos(a), 0, -sin(a)), 0.5))
	var orbit := _begin()
	_gem(orbit, Vector3.ZERO, 0.045, 0.1, 0.06, 5, gp)
	var result := _pack(st, glow, head, head_glow, crystal, Vector3(0, 0.9, 0.04), HEAD_Y[2], true, 3.9)
	result.orbit_mesh = orbit.commit()
	return result

## Contrafortes escalonados (tres degraus de blocos, cada um mais recuado e com
## chanfro claro em cima) nas diagonais; com `cardinal`, tambem nos lados
## (menores; nunca na porta).
static func _buttresses(st: SurfaceTool, rng: RandomNumberGenerator, count: int, y0: float, y1: float, r_foot: float, r_top: float, half: float, cardinal: bool) -> void:
	var state := {"tone": STONE, "moss": 0.0}
	var paint := _stone_paint(state)
	for i in count:
		var a := PI / 4.0 + TAU * i / (8.0 if cardinal else 4.0)
		var small := cardinal and i % 2 == 1
		if small and absf(wrapf(a, -PI, PI)) < 0.2:
			continue # sem contraforte na porta
		var w := half * (0.72 if small else 1.0)
		var top := y1 - (0.4 if small else 0.0)
		var foot := r_foot - (0.06 if small else 0.0)
		for k in 3:
			var ya := lerpf(y0 - 0.02, top, k / 3.0)
			var yb := lerpf(y0 - 0.02, top, (k + 1) / 3.0)
			var ro := lerpf(foot, r_top + 0.06, k / 2.0)
			var da := w / ro
			state.tone = [STONE, STONE_WARM, STONE_LIGHT][(k + i) % 3]
			state.moss = 0.5 if k == 0 else 0.25
			_block(st, a - da, a + da, 0.45, ro, ro - 0.05, ya, yb + 0.01, 0.035, paint)
		# capa inclinada (pedra clara) no alto do contraforte
		state.tone = STONE_LIGHT
		state.moss = 0.0
		var out := Vector3(sin(a), 0, cos(a))
		var cap_c := out * (r_top + 0.02) + Vector3(0, top, 0)
		_beam(st, cap_c - out * 0.08, cap_c + out * 0.04 + Vector3(0, 0.07, 0), w * 0.9, 0.03, paint, 4, 1.0, Vector3.UP)

## Glifo de runa em jade sobre a pedra (tres desenhos que se alternam): traco
## com losango, traco duplo ou cruz. `a` = angulo da face (0 = +Z).
static func _rune(glow: SurfaceTool, a: float, r: float, y: float, variant: int) -> void:
	var out := Vector3(sin(a), 0, cos(a))
	var side := Vector3(cos(a), 0, -sin(a))
	var paint := _flat(JADE, 0.05)
	var p := out * r + Vector3(0, y, 0)
	match variant % 3:
		0:
			_beam(glow, p, p + Vector3(0, 0.1, 0), 0.016, 0.01, paint, 4, 1.0, out)
			_beam(glow, p + Vector3(0, 0.125, 0), p + Vector3(0, 0.175, 0), 0.025, 0.01, paint, 4, 0.2, out)
		1:
			for s: float in [-1.0, 1.0]:
				_beam(glow, p + side * 0.028 * s, p + side * 0.028 * s + Vector3(0, 0.15, 0), 0.013, 0.01, paint, 4, 1.0, out)
		_:
			_beam(glow, p, p + Vector3(0, 0.16, 0), 0.015, 0.01, paint, 4, 1.0, out)
			_beam(glow, p + Vector3(0, 0.1, 0) - side * 0.045, p + Vector3(0, 0.1, 0) + side * 0.045, 0.012, 0.01, paint, 4, 1.0, out)

## Janela em arco: moldura de pedra, vao escuro e fundo de jade aceso (glow).
static func _window(st: SurfaceTool, glow: SurfaceTool, a: float, r: float, y: float, half_w: float, h: float) -> void:
	var out := Vector3(sin(a), 0, cos(a))
	var side := Vector3(cos(a), 0, -sin(a))
	var frame := _flat(STONE_LIGHT, 0.06)
	for s: float in [-1.0, 1.0]:
		var p := out * (r + 0.03) + side * s * (half_w + 0.035)
		_beam(st, p + Vector3(0, y, 0), p + Vector3(0, y + h, 0), 0.035, 0.04, frame, 4, 1.0, out)
	_beam(st, out * (r + 0.035) + side * -(half_w + 0.07) + Vector3(0, y + h + 0.04, 0), out * (r + 0.035) + side * (half_w + 0.07) + Vector3(0, y + h + 0.04, 0), 0.04, 0.045, frame, 4, 1.0, out)
	_beam(st, out * (r + 0.04) + side * -(half_w + 0.06) + Vector3(0, y - 0.02, 0), out * (r + 0.04) + side * (half_w + 0.06) + Vector3(0, y - 0.02, 0), 0.06, 0.025, frame, 4, 1.0, Vector3.UP)
	_beam(glow, out * (r - 0.01) + Vector3(0, y + 0.01, 0), out * (r - 0.01) + Vector3(0, y + h - 0.01, 0), half_w, 0.015, _flat(JADE_MID.lightened(0.25), 0.05), 4, 1.0, out)

## Cranio de ceratopsideo estilizado: leque (frill), bico e tres chifres.
static func _skull(st: SurfaceTool, at: Vector3) -> void:
	var ivory := _flat(IVORY, 0.05)
	var shade := _flat(IVORY_SHADE, 0.05)
	# frill em leque de 7 laminas
	for i in 7:
		var t := lerpf(-1.15, 1.15, i / 6.0)
		var dir := Vector3(sin(t), cos(t), 0.0)
		_beam(st, at + dir * 0.05, at + dir * 0.27 + Vector3(0, 0, -0.03), 0.055, 0.015, shade if i % 2 == 0 else ivory, 4, 0.75, Vector3.BACK)
		_beam(st, at + dir * 0.27 + Vector3(0, 0, -0.03), at + dir * 0.33 + Vector3(0, 0, -0.04), 0.02, 0.012, ivory, 4, 0.4, Vector3.BACK, true)
	# rosto e bico
	_beam(st, at + Vector3(0, 0.08, 0.02), at + Vector3(0, -0.14, 0.09), 0.07, 0.06, ivory, 5, 0.6)
	_beam(st, at + Vector3(0, -0.14, 0.09), at + Vector3(0, -0.2, 0.15), 0.035, 0.03, shade, 4, 0.3, Vector3.ZERO, true)
	# chifres: dois sobre os olhos, um no focinho
	for s: float in [-1.0, 1.0]:
		_horn(st, at + Vector3(s * 0.05, 0.05, 0.06), Vector3(s * 0.35, 0.45, 1.0).normalized(), 0.24, 0.025, 0.1, ivory, 3, 5)
		_beam(st, at + Vector3(s * 0.045, -0.01, 0.075), at + Vector3(s * 0.045, -0.01, 0.09), 0.018, 0.018, _flat(DOOR), 4)
	_horn(st, at + Vector3(0, -0.07, 0.11), Vector3(0, 0.5, 1.0).normalized(), 0.1, 0.022, 0.05, ivory, 3, 5)

# ---------------------------------------------------------------------------

static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

static func _pack(st: SurfaceTool, glow: SurfaceTool, head: SurfaceTool, head_glow, crystal: SurfaceTool, crystal_pos: Vector3, head_y: float, orbit: bool, top: float) -> Dictionary:
	return {
		"body": st.commit(),
		"glow": glow.commit(),
		"head": head.commit(),
		"head_glow": head_glow.commit() if head_glow != null else null,
		"crystal": crystal.commit(),
		"crystal_pos": crystal_pos,
		"head_y": head_y,
		"orbit": orbit,
		"orbit_mesh": null,
		"top": top,
	}
