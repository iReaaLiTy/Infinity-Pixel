extends RefCounted

# Visual Overhaul 3.0 — "Expedição Pré-histórica": paleta, estilos e desenhos
# vetoriais proprios da interface (pedra, jade, fosseis, pegadas, silhuetas).
# Tudo e desenhado com as primitivas do CanvasItem: nenhum asset externo,
# nitido em qualquer escala da interface. Usado pelo menu, telas, inventario e HUD.

# Paleta da direcao de arte (sRGB).
const JADE := Color("69c7a0")
const JADE_LIGHT := Color("aef0cf")
const JADE_DEEP := Color("2f7f68")
const GREEN_DARK := Color("19382f")
const GREEN_DEEP := Color("10251f")
const AMBER := Color("d5a45e")
const AMBER_LIGHT := Color("f2c46b")
const AMBER_DARK := Color("6e4419")
const IVORY := Color("e8dfca")
const TERRACOTTA := Color("b86f55")
const NIGHT := Color("332452")
const NIGHT_LIGHT := Color("9aa6f0")
const STONE := Color("2a3d36")
const STONE_EDGE := Color("4e7a66")
const INK := Color("0b1a15")
const EMBER := Color("e0795a")

# ---------------------------------------------------------------------------
# Estilos (StyleBoxFlat com cantos chanfrados: corner_detail baixo = pedra talhada)
# ---------------------------------------------------------------------------

## Design 5.0: estilos em "pedra talhada" (CarvedStyle): chanfro, espessura,
## bisel, filete e cravos. As assinaturas antigas continuam (menus, HUD, mochila).
const CarvedStyle := preload("res://scenes/ui/carved_style.gd")

static func carved(fill: Color, edge: Color, margin := Vector4(20, 14, 20, 14), chamfer := 10.0) -> StyleBox:
	var s := CarvedStyle.new()
	s.bg_color = fill
	s.border_color = edge
	s.chamfer = chamfer
	s.content_margin_left = margin.x
	s.content_margin_top = margin.y
	s.content_margin_right = margin.z
	s.content_margin_bottom = margin.w
	return s

## Placa de pedra escura, cantos chanfrados, filete jade interno e cravos de
## jade nos cantos (paineis, modais, HUD).
static func stone_panel(alpha := 0.95, edge := STONE_EDGE, margin := Vector4(20, 14, 20, 14), radius := 10) -> StyleBox:
	var s := carved(Color(GREEN_DEEP, alpha), Color(edge, 0.9), margin, radius + 2.0)
	s.bg_top = Color(STONE.lerp(GREEN_DEEP, 0.35), alpha)
	s.inner_color = Color(JADE, 0.22)
	s.studs = radius >= 10
	s.shadow_size = 10.0
	s.shadow_offset = Vector2(0, 4)
	s.shadow_color = Color(0, 0, 0, 0.4)
	return s

## Estilo de botao de pedra: normal (placa com espessura), hover (borda e
## brilho jade), pressionado (afunda: perde a espessura), foco de teclado
## (contorno ambar) e desabilitado (apagado).
static func button_styles(fill: Color, edge: Color, depth := 5, radius := 10, h := 22, v := 8) -> Dictionary:
	var make := func(bg: Color, border: Color, d: float, glow: float) -> StyleBox:
		var s := carved(bg, border, Vector4(h, v, h, v + d), float(radius))
		s.depth = d
		s.glow = glow
		s.bg_top = bg.lightened(0.16)
		s.inner_color = Color(border, 0.28)
		s.shadow_size = 5.0
		s.shadow_offset = Vector2(0, 3)
		return s
	var normal: StyleBox = make.call(fill, edge, depth, 0.0)
	var hover: StyleBox = make.call(fill.lightened(0.1), JADE, depth, 0.55)
	var pressed: StyleBox = make.call(fill.darkened(0.12), JADE, maxi(1, depth - 3), 0.25)
	pressed.content_margin_top = v + depth - maxi(1, depth - 3) # o texto afunda junto
	pressed.content_margin_bottom = v + maxi(1, depth - 3)
	var focus: StyleBox = make.call(Color(0, 0, 0, 0), AMBER_LIGHT, 0, 0.0)
	focus.draw_center = false
	focus.shadow_size = 0.0
	var disabled: StyleBox = make.call(fill.darkened(0.35), Color(edge, 0.45), depth, 0.0)
	disabled.inner_color = Color(0, 0, 0, 0)
	return {"normal": normal, "hover": hover, "pressed": pressed, "focus": focus, "disabled": disabled}

# ---------------------------------------------------------------------------
# Desenhos (todos recebem o CanvasItem e um retangulo; coordenadas normalizadas)
# ---------------------------------------------------------------------------

static func _p(r: Rect2, x: float, y: float) -> Vector2:
	return r.position + Vector2(x * r.size.x, y * r.size.y)

static func _poly(r: Rect2, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(_p(r, q[0], q[1]))
	return out

## Cristal de jade facetado (marca do Refugio).
static func crystal(ci: CanvasItem, r: Rect2, glow := 0.0) -> void:
	if glow > 0.0:
		ci.draw_circle(r.get_center(), r.size.y * 0.55, Color(JADE, 0.10 * glow))
		ci.draw_circle(r.get_center(), r.size.y * 0.38, Color(JADE, 0.12 * glow))
	var top := _p(r, .5, 0)
	var left := _p(r, .08, .36)
	var right := _p(r, .92, .36)
	var bottom := _p(r, .5, 1)
	var mid := _p(r, .5, .38)
	ci.draw_colored_polygon(PackedVector2Array([top, left, bottom, right]), Color("123a33"))
	var c := r.get_center() + Vector2(0, r.size.y * .05)
	var ins := func(p: Vector2) -> Vector2: return p.lerp(c, .16)
	ci.draw_colored_polygon(PackedVector2Array([ins.call(top), ins.call(left), ins.call(mid)]), Color("c4f6de"))
	ci.draw_colored_polygon(PackedVector2Array([ins.call(top), ins.call(mid), ins.call(right)]), Color("7fd8b0"))
	ci.draw_colored_polygon(PackedVector2Array([ins.call(left), ins.call(bottom), ins.call(mid)]), Color("4fae8c"))
	ci.draw_colored_polygon(PackedVector2Array([ins.call(mid), ins.call(bottom), ins.call(right)]), Color("2f7f68"))

## Pegada de tres dedos (teropode). `angle` em radianos (0 = dedos para cima).
static func footprint(ci: CanvasItem, center: Vector2, size: float, color: Color, angle := 0.0) -> void:
	var rot := func(v: Vector2) -> Vector2: return center + v.rotated(angle) * size
	var heel := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0
		heel.append(rot.call(Vector2(cos(a) * .2, .22 + sin(a) * .17)))
	ci.draw_colored_polygon(heel, color)
	for k in [-1, 0, 1]:
		var dir := Vector2(0, -1).rotated(k * 0.5)
		var side := dir.orthogonal()
		var base := Vector2(0, .1) + dir * .1
		var length := 0.52 if k == 0 else 0.42
		var toe := PackedVector2Array([rot.call(base + side * .085), rot.call(base + dir * length), rot.call(base - side * .085)])
		ci.draw_colored_polygon(toe, color)

## Trilha de pegadas alternadas ao longo de um segmento.
static func footprint_trail(ci: CanvasItem, from: Vector2, to: Vector2, steps: int, size: float, color: Color) -> void:
	var dir := (to - from).normalized()
	var side := dir.orthogonal()
	var angle := dir.angle() + PI / 2.0
	for i in steps:
		var t := (i + 0.5) / steps
		var at := from.lerp(to, t) + side * size * 0.32 * (1.0 if i % 2 == 0 else -1.0)
		footprint(ci, at, size, Color(color, color.a * (0.55 + 0.45 * t)), angle)

## Osso estilizado (fossil): haste com dois nos em cada ponta.
static func bone(ci: CanvasItem, a: Vector2, b: Vector2, thickness: float, color: Color) -> void:
	var dir := (b - a).normalized()
	var n := dir.orthogonal()
	ci.draw_line(a, b, color, thickness)
	for end in [a, b]:
		var out: Vector2 = -dir if end == a else dir
		for s in [-1.0, 1.0]:
			ci.draw_circle(end + n * thickness * 0.55 * s + out * thickness * 0.1, thickness * 0.62, color)

## Tres marcas de garra.
static func claw_marks(ci: CanvasItem, r: Rect2, color: Color) -> void:
	for i in 3:
		var x0 := 0.18 + i * 0.28
		var pts := PackedVector2Array()
		for k in 6:
			var t := k / 5.0
			pts.append(_p(r, x0 + t * 0.22 + sin(t * PI) * 0.05, t))
		for k in pts.size() - 1:
			var w := lerpf(1.0, 3.6, sin((k + 0.5) / (pts.size() - 1) * PI)) * r.size.x / 40.0
			ci.draw_line(pts[k], pts[k + 1], color, maxf(w, 1.0))

## Amonite (fossil em espiral).
static func ammonite(ci: CanvasItem, center: Vector2, radius: float, color: Color, width := 2.0) -> void:
	var pts := PackedVector2Array()
	for i in 60:
		var t := i / 59.0
		var a := t * TAU * 2.4
		pts.append(center + Vector2(cos(a), sin(a)) * radius * (0.12 + 0.88 * t))
	ci.draw_polyline(pts, color, width, true)
	for i in range(12, 60, 6):
		var t := i / 59.0
		var a := t * TAU * 2.4
		var r1 := radius * (0.12 + 0.88 * t)
		var r0 := radius * (0.12 + 0.88 * maxf(t - 0.42, 0.0))
		ci.draw_line(center + Vector2(cos(a), sin(a)) * r0, center + Vector2(cos(a), sin(a)) * r1, Color(color, color.a * 0.6), 1.0)

## Silhueta lateral de um teropode estilizado (olha para a direita).
const DINO_SIL := [[0, .47], [.2, .37], [.4, .27], [.52, .23], [.64, .3], [.72, .2], [.76, .07], [.86, .03],
	[.995, .13], [.96, .2], [.88, .23], [.78, .27], [.74, .4], [.7, .5], [.745, .57], [.77, .64], [.71, .62],
	[.62, .6], [.6, .73], [.62, .87], [.68, .97], [.58, .985], [.55, .9], [.5, .73], [.46, .63], [.36, .53], [.2, .5]]

static func dino_silhouette(ci: CanvasItem, r: Rect2, color: Color, flip := false, eye := Color(0, 0, 0, 0)) -> void:
	var pts := PackedVector2Array()
	for q in DINO_SIL:
		pts.append(_p(r, (1.0 - q[0]) if flip else q[0], q[1]))
	ci.draw_colored_polygon(pts, color)
	if eye.a > 0.0:
		ci.draw_circle(_p(r, (1.0 - .845) if flip else .845, .11), r.size.y * .035, eye)

## Icones (todos cabem no retangulo r).
static func icon(ci: CanvasItem, kind: StringName, r: Rect2, color: Color) -> void:
	match kind:
		&"play":
			crystal(ci, Rect2(_p(r, .2, 0), r.size * Vector2(.6, 1)))
		&"tutorial":
			footprint(ci, _p(r, .36, .62), r.size.y * .5, color, -0.25)
			footprint(ci, _p(r, .66, .36), r.size.y * .42, Color(color, color.a * .7), 0.2)
		&"settings":
			var c := r.get_center()
			var pts := PackedVector2Array()
			for i in 32:
				var a := TAU * i / 32.0
				var rr := r.size.y * (0.48 if (i / 2) % 2 == 0 else 0.36)
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(pts, color)
			ci.draw_circle(c, r.size.y * .16, INK)
		&"controls":
			var key := Rect2(_p(r, .1, .18), r.size * Vector2(.8, .64))
			ci.draw_rect(key, color, false, 2.0)
			for i in 3:
				ci.draw_rect(Rect2(_p(r, .2 + i * .22, .3), r.size * Vector2(.15, .14)), color)
			ci.draw_rect(Rect2(_p(r, .27, .56), r.size * Vector2(.46, .12)), color)
		&"credits":
			ammonite(ci, r.get_center(), r.size.y * .46, color, 2.0)
		&"quit":
			var arch := PackedVector2Array()
			for i in 9:
				var a := PI + PI * i / 8.0
				arch.append(_p(r, .38, .42) + Vector2(cos(a) * r.size.x * .26, sin(a) * r.size.y * .3))
			arch.append(_p(r, .64, 1))
			arch.append(_p(r, .12, 1))
			ci.draw_colored_polygon(arch, Color(color, .35))
			ci.draw_polyline(arch, color, 2.0)
			ci.draw_line(_p(r, .5, .62), _p(r, .98, .62), color, 2.5)
			ci.draw_colored_polygon(_poly(r, [[1, .62], [.82, .48], [.82, .76]]), color)
		&"wood":
			ci.draw_rect(Rect2(_p(r, .06, .3), r.size * Vector2(.7, .42)), Color("8a6440"))
			ci.draw_line(_p(r, .1, .42), _p(r, .7, .42), Color("6e4b2c"), 1.5)
			ci.draw_circle(_p(r, .76, .51), r.size.y * .22, Color("d9b98a"))
			ci.draw_arc(_p(r, .76, .51), r.size.y * .12, 0, TAU, 12, Color("8a6440"), 1.5)
		&"stone":
			ci.draw_colored_polygon(_poly(r, [[.08, .62], [.22, .24], [.55, .12], [.86, .3], [.94, .66], [.6, .9], [.24, .86]]), Color("9aa79d"))
			ci.draw_colored_polygon(_poly(r, [[.22, .24], [.55, .12], [.5, .45]]), Color("b9c5bc"))
			ci.draw_colored_polygon(_poly(r, [[.5, .45], [.7, .3], [.66, .62]]), Color("6e8aa3"))
		&"defense":
			crystal(ci, Rect2(_p(r, .18, 0), r.size * Vector2(.64, 1)))
		&"territory":
			ci.draw_rect(Rect2(_p(r, .2, .74), r.size * Vector2(.6, .18)), Color("8d9a8f"))
			ci.draw_rect(Rect2(_p(r, .36, .5), r.size * Vector2(.28, .26)), Color("7c8980"))
			ci.draw_colored_polygon(_poly(r, [[.5, .04], [.7, .27], [.5, .5], [.3, .27]]), Color("7fe0b8"))
		&"campfire":
			ci.draw_line(_p(r, .14, .9), _p(r, .86, .72), Color("8a6440"), r.size.y * .12)
			ci.draw_line(_p(r, .14, .72), _p(r, .86, .9), Color("6e4b2c"), r.size.y * .12)
			ci.draw_colored_polygon(_poly(r, [[.5, .06], [.74, .5], [.66, .76], [.34, .76], [.26, .5]]), Color("e9a23b"))
			ci.draw_colored_polygon(_poly(r, [[.5, .34], [.62, .58], [.56, .74], [.44, .74], [.38, .58]]), Color("ffe2a8"))
		&"trap":
			ci.draw_rect(Rect2(_p(r, .06, .8), r.size * Vector2(.88, .14)), Color("6e4b2c"))
			for i in 4:
				var x := .14 + i * .24
				ci.draw_colored_polygon(_poly(r, [[x - .09, .8], [x, .14 + (i % 2) * .12], [x + .09, .8]]), IVORY)
		&"tower":
			ci.draw_colored_polygon(_poly(r, [[.24, 1], [.34, .4], [.66, .4], [.76, 1]]), Color("8a6440"))
			ci.draw_rect(Rect2(_p(r, .22, .32), r.size * Vector2(.56, .1)), Color("b9a58c"))
			crystal(ci, Rect2(_p(r, .38, 0), r.size * Vector2(.24, .34)))
		&"heart":
			ci.draw_circle(_p(r, .32, .36), r.size.y * .22, color)
			ci.draw_circle(_p(r, .68, .36), r.size.y * .22, color)
			ci.draw_colored_polygon(_poly(r, [[.1, .44], [.9, .44], [.5, .92]]), color)
		&"player":
			ci.draw_colored_polygon(_poly(r, [[.12, .5], [.88, .5], [.7, .36], [.3, .36]]), Color(color, .9))
			ci.draw_circle(_p(r, .5, .3), r.size.y * .16, color)
			ci.draw_colored_polygon(_poly(r, [[.18, 1], [.26, .62], [.74, .62], [.82, 1]]), color)
		&"refuge":
			crystal(ci, Rect2(_p(r, .2, 0), r.size * Vector2(.6, 1)))
		&"paw":
			footprint(ci, r.get_center() + Vector2(0, r.size.y * .05), r.size.y * .9, color)
		&"world":
			# relogio de sol: o mundo continua andando
			ci.draw_arc(r.get_center(), r.size.y * .42, 0, TAU, 20, color, 2.0)
			ci.draw_line(r.get_center(), r.get_center() + Vector2(0, -r.size.y * .3), color, 2.0)
			ci.draw_line(r.get_center(), r.get_center() + Vector2(r.size.x * .22, r.size.y * .1), color, 2.0)
		_:
			ci.draw_circle(r.get_center(), r.size.y * .3, color)

## Controle que so desenha: devolve um Control do tamanho pedido.
static func drawn(size: Vector2, painter: Callable) -> Control:
	var c := Control.new()
	c.custom_minimum_size = size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.draw.connect(func(): painter.call(c, Rect2(Vector2.ZERO, c.size)))
	return c

static func icon_control(kind: StringName, size: float, color := IVORY) -> Control:
	return drawn(Vector2(size, size), func(ci: CanvasItem, r: Rect2): icon(ci, kind, r, color))

## Tecla desenhada (E, F, H, C, I...) para dicas de interacao.
static func keycap(text: String, font: Font, size := 15) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var w := maxf(size * 1.7, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + size * 0.9)
	c.custom_minimum_size = Vector2(w, size * 1.75)
	c.set_meta("text", text)
	c.draw.connect(func():
		var r := Rect2(Vector2.ZERO, c.size)
		var t: String = c.get_meta("text")
		c.draw_rect(Rect2(r.position + Vector2(0, 3), r.size - Vector2(0, 3)), Color(AMBER_DARK, .9))
		c.draw_rect(Rect2(r.position, r.size - Vector2(0, 3)), AMBER_LIGHT)
		c.draw_rect(Rect2(r.position, r.size - Vector2(0, 3)), Color(AMBER_DARK, .9), false, 1.5)
		var ts := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		font.draw_string(c.get_canvas_item(), Vector2((c.size.x - ts.x) * .5, (c.size.y - 3) * .5 + size * .36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, INK))
	return c

## Moldura decorativa desenhada SOBRE o estilo do proprio painel (sinal draw:
## fica acima do fundo e abaixo dos filhos, nas bordas, fora do conteudo):
## ossos fosseis nos cantos e um cristal no topo.
static func decorate(panel: Control, top_crystal := true, tint := Color(IVORY, 0.3)) -> void:
	panel.draw.connect(func(): paint_frame(panel, panel.size, top_crystal, tint))

static func paint_frame(ci: CanvasItem, s: Vector2, top_crystal := true, tint := Color(IVORY, 0.3)) -> void:
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var o := Vector2(corner.x * s.x, corner.y * s.y)
		var inward := Vector2(1 - 2 * corner.x, 1 - 2 * corner.y)
		bone(ci, o + inward * Vector2(14, 9), o + inward * Vector2(42, 9), 2.6, tint)
		bone(ci, o + inward * Vector2(9, 14), o + inward * Vector2(9, 32), 2.6, tint)
	if top_crystal:
		var w := 22.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(s.x * .5 - w * 1.6, 1), Vector2(s.x * .5 + w * 1.6, 1), Vector2(s.x * .5 + w, 9), Vector2(s.x * .5 - w, 9)]), Color(STONE_EDGE, .95))
		crystal(ci, Rect2(Vector2(s.x * .5 - w * .42, -14), Vector2(w * .84, 26)))

## Troca o texto de uma tecla desenhada (keycap) e ajusta a largura.
static func set_keycap(c: Control, text: String, font: Font, size := 15) -> void:
	c.set_meta("text", text)
	c.custom_minimum_size.x = maxf(size * 1.7, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + size * 0.9)
	c.queue_redraw()
