extends StyleBox

# Design Overhaul 5.0 — "pedra talhada" da interface (menu, telas, HUD, mochila).
#
# StyleBox desenhado com poligonos (sem textura, nitido em qualquer escala):
# placa chanfrada com espessura (degrau escuro embaixo), face em degrade
# vertical, bisel claro no topo, borda, filete interno (jade ou ambar), cravos
# de jade nos cantos e marcas de cinzel discretas. Os nomes dos campos seguem o
# StyleBoxFlat (bg_color, border_color, shadow_size...) para o codigo que ja
# trocava a cor da borda (alertas da HUD) continuar funcionando.

@export var bg_color := Color("16302a"):
	set(v):
		if bg_color == v:
			return
		bg_color = v
		emit_changed()
## Cor do topo da face (degrade vertical). Alfa 0 = calcula a partir de bg_color.
@export var bg_top := Color(0, 0, 0, 0):
	set(v):
		if bg_top == v:
			return
		bg_top = v
		emit_changed()
@export var border_color := Color("4e7a66"):
	set(v):
		if border_color == v:
			return
		border_color = v
		emit_changed()
@export var border_width := 2.0:
	set(v):
		if border_width == v:
			return
		border_width = v
		emit_changed()
## Filete interno (inlay) a alguns pixels da borda. Alfa 0 = sem filete.
@export var inner_color := Color(0.41, 0.78, 0.63, 0.35):
	set(v):
		if inner_color == v:
			return
		inner_color = v
		emit_changed()
@export var chamfer := 9.0:
	set(v):
		if chamfer == v:
			return
		chamfer = v
		emit_changed()
## Espessura da placa (degrau escuro embaixo), em px.
@export var depth := 0.0:
	set(v):
		if depth == v:
			return
		depth = v
		emit_changed()
@export var draw_center := true:
	set(v):
		if draw_center == v:
			return
		draw_center = v
		emit_changed()
## Brilho externo (hover), 0..1, na cor glow_color.
@export var glow := 0.0:
	set(v):
		if glow == v:
			return
		glow = v
		emit_changed()
@export var glow_color := Color("69c7a0"):
	set(v):
		if glow_color == v:
			return
		glow_color = v
		emit_changed()
@export var shadow_size := 6.0:
	set(v):
		if shadow_size == v:
			return
		shadow_size = v
		emit_changed()
@export var shadow_offset := Vector2(0, 3):
	set(v):
		if shadow_offset == v:
			return
		shadow_offset = v
		emit_changed()
@export var shadow_color := Color(0, 0, 0, 0.35):
	set(v):
		if shadow_color == v:
			return
		shadow_color = v
		emit_changed()
@export var studs := false:
	set(v):
		if studs == v:
			return
		studs = v
		emit_changed()
@export var stud_color := Color("69c7a0"):
	set(v):
		if stud_color == v:
			return
		stud_color = v
		emit_changed()
@export var chisel := true:
	set(v):
		if chisel == v:
			return
		chisel = v
		emit_changed()

# Design 5.0 (otimizacao): toda a placa — sombra, brilho, espessura, face em
# degrade, marcas de cinzel, bisel, filete, borda e cravos — vira UM array de
# triangulos com cor por vertice: uma chamada de desenho por placa (antes, cada
# poligono e cada linha era uma chamada no renderizador Compatibility).
var _pts := PackedVector2Array()
var _cols := PackedColorArray()
var _idx := PackedInt32Array()

func _octagon(r: Rect2, c: float) -> PackedVector2Array:
	c = minf(c, minf(r.size.x, r.size.y) * 0.5)
	var p := r.position
	var e := r.end
	return PackedVector2Array([Vector2(p.x + c, p.y), Vector2(e.x - c, p.y), Vector2(e.x, p.y + c), Vector2(e.x, e.y - c),
		Vector2(e.x - c, e.y), Vector2(p.x + c, e.y), Vector2(p.x, e.y - c), Vector2(p.x, p.y + c)])

## Poligono convexo em leque (cor unica ou uma cor por vertice).
func _fan(pts: PackedVector2Array, col: Color, per_vertex := PackedColorArray()) -> void:
	var base := _pts.size()
	for i in pts.size():
		_pts.append(pts[i])
		_cols.append(per_vertex[i] if per_vertex.size() == pts.size() else col)
	for i in range(1, pts.size() - 1):
		_idx.append_array([base, base + i, base + i + 1])

## Segmento grosso (quad) de a ate b.
func _seg(a: Vector2, b: Vector2, width: float, ca: Color, cb: Color) -> void:
	var d := b - a
	if d.length_squared() < 0.0001:
		return
	var n := d.normalized().orthogonal() * width * 0.5
	var base := _pts.size()
	_pts.append_array([a + n, b + n, b - n, a - n])
	_cols.append_array([ca, cb, cb, ca])
	_idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

## Contorno fechado: um quad por lado.
func _ring(pts: PackedVector2Array, col: Color, width: float) -> void:
	for i in pts.size():
		_seg(pts[i], pts[(i + 1) % pts.size()], width, col, col)

func _draw(ci: RID, rect: Rect2) -> void:
	if rect.size.x < 2.0 or rect.size.y < 2.0:
		return
	_pts.clear()
	_cols.clear()
	_idx.clear()
	var c := chamfer
	if draw_center and shadow_size > 0.0 and shadow_color.a > 0.0:
		# sombra (duas camadas: borda suave sem desfoque caro)
		for k in 2:
			var grow := shadow_size * (0.5 + 0.5 * k)
			var r := rect.grow(grow * 0.5).grow_individual(0, 0, 0, grow * 0.3)
			r.position += shadow_offset
			_fan(_octagon(r, c + grow * 0.5), Color(shadow_color, shadow_color.a * (0.55 if k == 0 else 0.3)))
	if glow > 0.0:
		for k in 3:
			var g := 2.0 + 3.0 * k
			_ring(_octagon(rect.grow(g), c + g * 0.6), Color(glow_color, glow * (0.45 - 0.13 * k)), 2.5)
	if not draw_center:
		_ring(_octagon(rect.grow(1.0), c + 1.0), border_color, border_width)
		_flush(ci)
		return
	# espessura: placa inteira escura; a face fica acima do degrau
	var face := rect
	if depth > 0.0:
		_fan(_octagon(rect, c), bg_color.darkened(0.55))
		face = Rect2(rect.position, Vector2(rect.size.x, rect.size.y - depth))
	var top := bg_top if bg_top.a > 0.0 else bg_color.lightened(0.1)
	var pts := _octagon(face, c)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bg_color, clampf((p.y - face.position.y) / maxf(face.size.y, 1.0), 0.0, 1.0)))
	_fan(pts, bg_color, cols)
	# marcas de cinzel (posicoes estaveis pelo tamanho da placa)
	if chisel and face.size.x > 60.0 and face.size.y > 24.0:
		var seed_v := int(face.size.x * 7.0 + face.size.y * 13.0)
		var mark := Color(0, 0, 0, 0.13)
		var lite := Color(1, 1, 1, 0.05)
		for i in int(clampf(face.size.x * face.size.y / 9000.0, 2.0, 9.0)):
			var h1 := fposmod(sin(seed_v * 0.37 + i * 12.9898) * 43758.5453, 1.0)
			var h2 := fposmod(sin(seed_v * 0.71 + i * 78.233) * 24634.6345, 1.0)
			var at := face.position + Vector2(c + h1 * (face.size.x - 2.0 * c), c * 0.6 + h2 * (face.size.y - 1.2 * c))
			var dir := Vector2(1, -0.35 + 0.7 * fposmod(h1 * 7.0, 1.0)).normalized() * (5.0 + 7.0 * h2)
			_seg(at, at + dir, 1.0, mark, mark)
			_seg(at + Vector2(0, 1), at + dir + Vector2(0, 1), 1.0, lite, lite)
	# bisel claro no topo (luz de cima), esmaecendo nas pontas
	var cc := minf(c, minf(face.size.x, face.size.y) * 0.5)
	var b0 := Vector2(face.position.x + 1.5, face.position.y + cc)
	var b1 := Vector2(face.position.x + cc, face.position.y + 1.5)
	var b2 := Vector2(face.end.x - cc, face.position.y + 1.5)
	var b3 := Vector2(face.end.x - 1.5, face.position.y + cc)
	var lit := Color(1, 1, 1, 0.22)
	var off := Color(1, 1, 1, 0.0)
	_seg(b0, b1, 2.0, off, lit)
	_seg(b1, b2, 2.0, lit, lit)
	_seg(b2, b3, 2.0, lit, off)
	if inner_color.a > 0.0 and face.size.x > 30.0 and face.size.y > 22.0:
		_ring(_octagon(face.grow(-5.0), maxf(c - 3.0, 2.0)), inner_color, 1.0)
	if border_width > 0.0 and border_color.a > 0.0:
		_ring(_octagon(rect, c), border_color, border_width)
	if studs and face.size.x > 70.0 and face.size.y > 40.0:
		var inset := c * 0.5 + 6.0
		for corner in [Vector2(inset, inset), Vector2(face.size.x - inset, inset), Vector2(inset, face.size.y - inset), Vector2(face.size.x - inset, face.size.y - inset)]:
			var o: Vector2 = face.position + corner
			var s := 3.6
			_fan(PackedVector2Array([o + Vector2(0, -s), o + Vector2(s, 0), o + Vector2(0, s), o + Vector2(-s, 0)]), stud_color.darkened(0.35))
			_fan(PackedVector2Array([o + Vector2(0, -s), o + Vector2(s, 0), o]), stud_color.lightened(0.25))
	_flush(ci)

func _flush(ci: RID) -> void:
	if not _idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci, _idx, _pts, _cols)

## Copia com o mesmo desenho (StyleBox.duplicate copia os @export).
func with(changes: Dictionary) -> StyleBox:
	var s := duplicate()
	for k in changes:
		s.set(k, changes[k])
	return s
