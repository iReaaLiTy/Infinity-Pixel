extends RefCounted

# Spec 017A — malhas low-poly FACETADAS: cada triangulo tem a sua normal (sem
# suavizacao) e a sua cor por vertice. Usado pela ferramenta da arte do Refugio
# e pelo visual do ponto de defesa. Sem texturas.
#
# `paint` recebe (centro da face, normal da face) e devolve a cor da face.

## Um triangulo voltado para `outward` (o Godot desenha a frente no sentido
## horario; a ordem e corrigida aqui para a luz nunca cair do lado errado).
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, paint: Callable) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		return
	n = n.normalized()
	if n.dot(outward) > 0.0:
		var t := b
		b = c
		c = t
	else:
		n = -n
	st.set_color(paint.call((a + b + c) / 3.0, n))
	st.set_normal(n)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

static func center(points: PackedVector3Array) -> Vector3:
	var sum := Vector3.ZERO
	for p in points:
		sum += p
	return sum / maxf(1.0, points.size())

## Anel irregular de `sides` vertices no plano XZ (antes de `xform`).
static func ring(sides: int, radius: float, y: float, rng: RandomNumberGenerator, jitter := 0.0, phase := 0.0, y_jitter := 0.0, xform := Transform3D.IDENTITY) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in sides:
		var a := phase + TAU * i / sides + rng.randf_range(-jitter, jitter) * 0.5
		var r := radius * (1.0 + rng.randf_range(-jitter, jitter))
		out.append(xform * Vector3(cos(a) * r, y + rng.randf_range(-y_jitter, y_jitter), sin(a) * r))
	return out

## Une aneis com o mesmo numero de vertices. `top`/`bottom`: Vector3 = ponta
## (leque ate ela), true = tampa plana, null = aberto (enterrado no chao).
static func loft(st: SurfaceTool, rings: Array, top, bottom, paint: Callable) -> void:
	var count: int = rings[0].size()
	var inside := Vector3.ZERO
	for r: PackedVector3Array in rings:
		inside += center(r)
	inside /= rings.size()
	for k in rings.size() - 1:
		var lo: PackedVector3Array = rings[k]
		var hi: PackedVector3Array = rings[k + 1]
		var axis := (center(lo) + center(hi)) * 0.5
		for i in count:
			var j := (i + 1) % count
			var out := (lo[i] + lo[j] + hi[i] + hi[j]) * 0.25 - axis
			tri(st, lo[i], lo[j], hi[j], out, paint)
			tri(st, lo[i], hi[j], hi[i], out, paint)
	_cap(st, rings[rings.size() - 1], top, inside, paint)
	_cap(st, rings[0], bottom, inside, paint)

static func _cap(st: SurfaceTool, edge: PackedVector3Array, tip, inside: Vector3, paint: Callable) -> void:
	if tip == null or (tip is bool and not tip):
		return
	var point: Vector3 = tip if tip is Vector3 else center(edge)
	for i in edge.size():
		var j := (i + 1) % edge.size()
		tri(st, edge[i], edge[j], point, (edge[i] + edge[j] + point) / 3.0 - inside, paint)

## Cor da face pela altura e pela inclinacao: base escura embaixo (oclusao
## falsa), topo mais claro. `tones` = [claro, medio, escuro].
static func by_height(tones: Array, n: Vector3, y: float, y0: float, y1: float, seed_value: float) -> Color:
	var t := clampf((y - y0) / maxf(0.01, y1 - y0), 0.0, 1.0)
	var c: Color = (tones[2] as Color).lerp(tones[1], smoothstep(0.0, 0.45, t)).lerp(tones[0], smoothstep(0.45, 1.0, t))
	# Variacao por face (estavel): facetas vizinhas nunca ficam identicas.
	var v := fposmod(sin(seed_value * 12.9898 + n.x * 78.233 + n.z * 37.719) * 43758.5453, 1.0)
	c = c.lightened(0.06 * v) if v > 0.5 else c.darkened(0.06 * (1.0 - v))
	return facet_shade(c, n)

## Volume "assado" na cor: topo claro, faces para o oeste mais escuras. Ao
## meio-dia o Sol vem de tras da camera (luz frontal, quase sem sombra propria);
## sem isto as facetas somem.
static func facet_shade(col: Color, n: Vector3) -> Color:
	var k := 0.8 + 0.2 * n.y - 0.14 * maxf(0.0, -n.x) + 0.05 * maxf(0.0, n.x) - 0.06 * maxf(0.0, -n.z)
	return Color(col.r * k, col.g * k, col.b * k, col.a)

static func instance(label: String, mesh: Mesh, mat: Material, pos := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = label
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
