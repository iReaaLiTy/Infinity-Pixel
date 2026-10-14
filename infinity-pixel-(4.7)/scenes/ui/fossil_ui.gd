extends RefCounted

# World 6.0 — identidade "expedicao paleontologica" da interface (mochila, menu
# e telas). So desenho com as primitivas do CanvasItem (nitido em qualquer
# escala, sem textura): placa de pedra de contorno irregular com rachaduras,
# veios de jade nascendo de algumas rachaduras, vertebras, ossos, amonite,
# pegadas fossilizadas, marcas de garra e cristais. As decoracoes ficam na
# faixa da borda (fora das margens de conteudo): nada cobre o texto.

const UiArt := preload("res://scenes/ui/ui_art.gd")

const STONE_TOP := Color("4b5249")
const STONE_LOW := Color("2a302b")
const STONE_EDGE := Color("151a17")
const BONE := Color("e8dfca")
const BONE_SHADE := Color("b8ab8c")
const JADE := Color("69c7a0")
const JADE_GLOW := Color("aef0cf")

static func _h(i: int, salt: float) -> float:
	return fposmod(sin(i * 12.9898 + salt * 78.233) * 43758.5453, 1.0)

## Contorno irregular de uma placa: anda pelo retangulo com passos curtos e
## desloca cada ponto para dentro/fora; os cantos sao lascados.
static func slab_outline(r: Rect2, salt := 1.0, rough := 3.5, chip := 16.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var k := 0
	for side in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var dir := (b - a).normalized()
		var out := Vector2(dir.y, -dir.x)
		var length := a.distance_to(b)
		var c := chip * (0.7 + 0.6 * _h(side, salt))
		var steps := maxi(3, int((length - 2.0 * c) / 24.0))
		pts.append(a + dir * c)
		for i in range(1, steps):
			var t := c + (length - 2.0 * c) * i / steps
			k += 1
			pts.append(a + dir * t + out * (_h(k, salt) - 0.5) * 2.0 * rough)
		pts.append(b - dir * c)
		# lasca do canto: um ponto recuado entre os dois lados
		var nb: Vector2 = corners[(side + 2) % 4]
		var next_dir := (nb - b).normalized()
		pts.append(b - dir * c * 0.35 + next_dir * c * 0.35 + (dir - next_dir).normalized() * -2.0)
	return pts

static func _shift(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + d)
	return out

static func _inset(pts: PackedVector2Array, center: Vector2, amount: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + (center - p).normalized() * amount)
	return out

## Placa arqueologica completa (mochila, menu, telas). `fossils` liga os
## ornamentos da borda (vertebras, amonite, ossos, pegadas, garras, cristais).
static func slab(ci: CanvasItem, r: Rect2, salt := 1.0, fossils := true, tint := Color(1, 1, 1, 1)) -> void:
	var outline := slab_outline(r, salt)
	var center := r.get_center()
	ci.draw_colored_polygon(_shift(outline, Vector2(0, 8)), Color(0, 0, 0, 0.45))
	var cols := PackedColorArray()
	for p in outline:
		var t := clampf((p.y - r.position.y) / maxf(r.size.y, 1.0), 0.0, 1.0)
		cols.append(STONE_TOP.lerp(STONE_LOW, t) * tint)
	ci.draw_polygon(outline, cols)
	# manchas de pedra (estaveis) para tirar o "liso"
	for i in 14:
		var p := r.position + Vector2(_h(i, salt + 3.0) * r.size.x, _h(i, salt + 7.0) * r.size.y)
		var s := 18.0 + 40.0 * _h(i, salt + 11.0)
		var spot := PackedVector2Array()
		for j in 7:
			var a := TAU * j / 7.0
			spot.append(p + Vector2(cos(a), sin(a) * 0.6) * s * (0.75 + 0.4 * _h(i * 7 + j, salt)))
		if r.grow(-10).has_point(p):
			ci.draw_colored_polygon(spot, Color(1, 1, 1, 0.025) if i % 2 == 0 else Color(0, 0, 0, 0.05))
	# bisel (luz de cima) e contorno
	var inner := _inset(outline, center, 6.0)
	ci.draw_polyline(inner + PackedVector2Array([inner[0]]), Color(1, 1, 1, 0.07), 2.0, true)
	ci.draw_polyline(outline + PackedVector2Array([outline[0]]), STONE_EDGE, 3.0, true)
	cracks(ci, r, salt)
	if fossils:
		_border_fossils(ci, r, salt)

## Rachaduras saindo das bordas; duas delas com jade aparecendo no fundo.
static func cracks(ci: CanvasItem, r: Rect2, salt := 1.0) -> void:
	for i in 6:
		var side := i % 4
		var t := 0.15 + 0.7 * _h(i, salt + 21.0)
		var start := [Vector2(r.position.x + r.size.x * t, r.position.y), Vector2(r.end.x, r.position.y + r.size.y * t),
			Vector2(r.position.x + r.size.x * t, r.end.y), Vector2(r.position.x, r.position.y + r.size.y * t)][side] as Vector2
		var inward := [Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1), Vector2(1, 0)][side] as Vector2
		var length := 26.0 + 30.0 * _h(i, salt + 5.0)
		var pts := PackedVector2Array([start])
		var p := start
		for k in 3:
			p += inward * length / 3.0 + inward.orthogonal() * (_h(i * 3 + k, salt) - 0.5) * 14.0
			pts.append(p)
		var jade := i == 1 or i == 4
		if jade: # jade surgindo entre a rachadura
			ci.draw_polyline(pts, Color(JADE, 0.35), 5.0, true)
			ci.draw_polyline(pts, JADE_GLOW, 1.6, true)
		else:
			ci.draw_polyline(pts, Color(0, 0, 0, 0.5), 2.0, true)
			ci.draw_polyline(_shift(pts, Vector2(1, 1)), Color(1, 1, 1, 0.06), 1.0, true)

static func _border_fossils(ci: CanvasItem, r: Rect2, salt: float) -> void:
	# vertebras ao longo do topo, a esquerda
	vertebrae(ci, r.position + Vector2(40, 9), r.position + Vector2(minf(r.size.x * 0.34, 330.0), 9), 9, Color(BONE, 0.42))
	# ossos cruzados no canto superior direito
	UiArt.bone(ci, Vector2(r.end.x - 62, 6 + r.position.y), Vector2(r.end.x - 18, 22 + r.position.y), 3.4, Color(BONE, 0.45))
	UiArt.bone(ci, Vector2(r.end.x - 22, 4 + r.position.y), Vector2(r.end.x - 58, 24 + r.position.y), 3.4, Color(BONE_SHADE, 0.4))
	# amonite no canto inferior esquerdo
	UiArt.ammonite(ci, Vector2(r.position.x + 22, r.end.y - 20), 15.0, Color(BONE, 0.35), 2.0)
	# pegadas fossilizadas no rodape, a direita
	UiArt.footprint_trail(ci, Vector2(r.end.x - 240, r.end.y - 9), Vector2(r.end.x - 70, r.end.y - 9), 4, 13.0, Color(BONE, 0.16))
	# marcas de garra na borda direita
	UiArt.claw_marks(ci, Rect2(Vector2(r.end.x - 15, r.position.y + r.size.y * 0.42), Vector2(12, 34)), Color(BONE, 0.2))
	# cristais de jade rompendo a pedra (topo ao centro e canto inferior direito)
	for c in [[Vector2(r.position.x + r.size.x * 0.5, r.position.y + 2), 26.0], [Vector2(r.end.x - 30, r.end.y - 4), 20.0]]:
		var at: Vector2 = c[0]
		var h: float = c[1]
		UiArt.crystal(ci, Rect2(at - Vector2(h * 0.3, h * 0.8), Vector2(h * 0.6, h)), 0.6)
		UiArt.crystal(ci, Rect2(at - Vector2(h * 0.62, h * 0.48), Vector2(h * 0.36, h * 0.6)))
		UiArt.crystal(ci, Rect2(at + Vector2(h * 0.24, -h * 0.42), Vector2(h * 0.32, h * 0.52)))

## Cadeia de vertebras (fossil) de a ate b.
static func vertebrae(ci: CanvasItem, a: Vector2, b: Vector2, count: int, color: Color) -> void:
	var dir := (b - a) / maxf(count, 1)
	var n := dir.normalized().orthogonal()
	for i in count:
		var c := a + dir * (i + 0.5)
		var s := 4.5 + 1.2 * sin(i * 0.7)
		ci.draw_circle(c, s, color)
		ci.draw_line(c - n * s * 1.7, c + n * s * 1.7, color, 2.0)
		if i < count - 1:
			ci.draw_line(c + dir.normalized() * s, c + dir - dir.normalized() * s, Color(color, color.a * 0.6), 1.5)

## Divisor de osso com dois nos (titulos de secao).
static func bone_divider(ci: CanvasItem, r: Rect2, color := Color(BONE, 0.45)) -> void:
	var y := r.size.y * 0.5
	ci.draw_line(Vector2(0, y), Vector2(r.size.x - 18, y), Color(0, 0, 0, 0.35), 3.0)
	ci.draw_line(Vector2(0, y - 1), Vector2(r.size.x - 18, y - 1), Color(JADE, 0.35), 1.5)
	UiArt.bone(ci, Vector2(r.size.x - 34, y), Vector2(r.size.x - 6, y), 3.0, color)

## Frasco de especime (Elixir de Jade): vidro, rolha e liquido jade.
static func jar(ci: CanvasItem, r: Rect2, full: float) -> void:
	var s := r.size
	var body := Rect2(r.position + Vector2(s.x * 0.18, s.y * 0.28), Vector2(s.x * 0.64, s.y * 0.68))
	ci.draw_rect(body.grow(2), Color(0, 0, 0, 0.35))
	ci.draw_rect(body, Color(0.75, 0.9, 0.85, 0.16))
	var liquid := Rect2(body.position + Vector2(3, body.size.y * (1.0 - full * 0.85)), Vector2(body.size.x - 6, body.size.y * full * 0.85 - 3))
	if full > 0.0:
		ci.draw_rect(liquid, Color(JADE, 0.85))
		ci.draw_rect(Rect2(liquid.position, Vector2(liquid.size.x, 3)), JADE_GLOW)
	ci.draw_rect(body, Color(0.85, 1.0, 0.95, 0.55), false, 1.5)
	ci.draw_line(body.position + Vector2(5, 6), body.position + Vector2(5, body.size.y - 8), Color(1, 1, 1, 0.45), 2.0)
	ci.draw_rect(Rect2(r.position + Vector2(s.x * 0.3, s.y * 0.12), Vector2(s.x * 0.4, s.y * 0.18)), Color("8a6440"))
	ci.draw_rect(Rect2(r.position + Vector2(s.x * 0.26, s.y * 0.24), Vector2(s.x * 0.48, s.y * 0.06)), Color("6e4b2c"))

## Icones da mochila e do menu (estilo fossil).
static func icon(ci: CanvasItem, kind: StringName, r: Rect2, color: Color) -> void:
	match kind:
		&"crystal_stone": # recursos: pedra com cristal
			ci.draw_colored_polygon(UiArt._poly(r, [[.06, .9], [.16, .52], [.44, .4], [.7, .56], [.8, .92]]), Color("9aa79d"))
			UiArt.crystal(ci, Rect2(UiArt._p(r, .46, 0), r.size * Vector2(.4, .72)))
		&"tool": # construcoes: martelo de pedra amarrado no cabo
			ci.draw_line(UiArt._p(r, .2, .95), UiArt._p(r, .62, .3), Color("8a6440"), r.size.y * .12)
			ci.draw_colored_polygon(UiArt._poly(r, [[.42, .1], [.92, .26], [.82, .52], [.34, .36]]), Color("aab3ab"))
			ci.draw_line(UiArt._p(r, .5, .4), UiArt._p(r, .64, .24), color, 2.0)
		&"skull": # companheiros: cranio de teropode estilizado
			ci.draw_colored_polygon(UiArt._poly(r, [[.06, .5], [.3, .2], [.7, .16], [.96, .4], [.9, .62], [.62, .66], [.5, .86], [.2, .8]]), color)
			ci.draw_circle(UiArt._p(r, .62, .38), r.size.y * .09, Color(0, 0, 0, .75))
			for i in 4:
				var x := .22 + i * .1
				ci.draw_colored_polygon(UiArt._poly(r, [[x, .74], [x + .05, .9], [x + .1, .76]]), color)
		_:
			UiArt.icon(ci, kind, r, color)
