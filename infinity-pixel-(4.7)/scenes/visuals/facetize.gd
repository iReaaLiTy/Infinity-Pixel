extends RefCounted

# Polimento visual (playtest 09/10/2026): troca as primitivas LISAS dos modelos
# (esfera, cilindro/cone, capsula) por versoes FACETADAS com as mesmas
# dimensoes, no estilo Vale de Jade. So a malha muda: nos, transforms e
# materiais (inclusive a paleta noturna por instancia) ficam iguais. Caixas e
# prismas ja sao facetados e nao mudam. Malhas em cache (imutaveis).

static var _cache := {}

## Troca as malhas de `root` e de todos os descendentes MeshInstance3D.
static func apply(root: Node) -> void:
	var nodes: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		nodes.append(root)
	for mi: MeshInstance3D in nodes:
		var faceted := faceted_mesh(mi.mesh)
		if faceted != null:
			mi.mesh = faceted

static func faceted_mesh(mesh: Mesh) -> Mesh:
	if mesh is SphereMesh:
		var s := mesh as SphereMesh
		return _cached("s_%.3f_%.3f" % [s.radius, s.height], func(): return _sphere(s.radius, s.height * 0.5))
	if mesh is CylinderMesh:
		var c := mesh as CylinderMesh
		return _cached("c_%.3f_%.3f_%.3f_%d" % [c.top_radius, c.bottom_radius, c.height, c.radial_segments], func(): return _cylinder(c.top_radius, c.bottom_radius, c.height, clampi(c.radial_segments, 5, 8)))
	if mesh is CapsuleMesh:
		var k := mesh as CapsuleMesh
		return _cached("k_%.3f_%.3f" % [k.radius, k.height], func(): return _capsule(k.radius, k.height))
	return null

static func _cached(key: String, build: Callable) -> Mesh:
	if not _cache.has(key):
		_cache[key] = build.call()
	return _cache[key]

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, center: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	var out := (a + b + c) / 3.0 - center
	if n.dot(out) > 0.0: # frente no sentido horario (Godot)
		var t := b
		b = c
		c = t
	else:
		n = -n
	for v in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(v)

## Elipsoide facetado (raio horizontal r, meia-altura h): 8 gomos, aneis
## alternados (facetas em losango) e leve irregularidade fixa.
static func _sphere(r: float, h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lats := [-55.0, -18.0, 18.0, 55.0]
	var seg := 8
	var rings := []
	for i in lats.size():
		var phi := deg_to_rad(lats[i])
		var ring := []
		for j in seg:
			var a := TAU * (j + 0.5 * (i % 2)) / seg
			var jit := 1.0 + 0.045 * sin(j * 2.3 + i * 1.7)
			ring.append(Vector3(cos(a) * cos(phi) * r * jit, sin(phi) * h, sin(a) * cos(phi) * r * jit))
		rings.append(ring)
	var top := Vector3(0, h, 0)
	var bottom := Vector3(0, -h, 0)
	for j in seg:
		var k := (j + 1) % seg
		_tri(st, rings[0][j], rings[0][k], bottom, Vector3.ZERO)
		_tri(st, rings[3][j], rings[3][k], top, Vector3.ZERO)
	for i in lats.size() - 1:
		var lo: Array = rings[i]
		var hi: Array = rings[i + 1]
		for j in seg:
			var k := (j + 1) % seg
			if i % 2 == 0: # hi deslocado meio gomo para frente
				_tri(st, lo[j], lo[k], hi[j], Vector3.ZERO)
				_tri(st, hi[j], lo[k], hi[k], Vector3.ZERO)
			else: # lo deslocado
				_tri(st, lo[j], hi[k], hi[j], Vector3.ZERO)
				_tri(st, lo[j], lo[k], hi[k], Vector3.ZERO)
	return st.commit()

## Cilindro/cone facetado com as mesmas medidas (centro na origem, como o
## CylinderMesh), com um anel do meio levemente torcido.
static func _cylinder(top_r: float, bottom_r: float, height: float, sides: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hh := height * 0.5
	var rings := []
	for spec in [[-hh, bottom_r, 0.0], [0.0, (top_r + bottom_r) * 0.5, 0.5], [hh, top_r, 0.0]]:
		var ring := []
		for j in sides:
			var a: float = TAU * (j + spec[2]) / sides
			ring.append(Vector3(cos(a) * spec[1], spec[0], sin(a) * spec[1]))
		rings.append(ring)
	for i in 2:
		for j in sides:
			var k := (j + 1) % sides
			var lo: Array = rings[i]
			var hi: Array = rings[i + 1]
			var c := Vector3(0, (lo[0].y + hi[0].y) * 0.5, 0)
			if i == 0:
				_tri(st, lo[j], lo[k], hi[j], c)
				_tri(st, hi[j], lo[k], hi[k], c)
			else:
				_tri(st, lo[j], hi[k], hi[j], c)
				_tri(st, lo[j], lo[k], hi[k], c)
	# Tampas (o centro do solido fica sempre do lado de dentro).
	for spec in [[rings[0], -hh, bottom_r], [rings[2], hh, top_r]]:
		if spec[2] < 0.0001:
			continue # ponta de cone: sem tampa
		var ring: Array = spec[0]
		var tip := Vector3(0, spec[1], 0)
		for j in sides:
			_tri(st, ring[j], ring[(j + 1) % sides], tip, Vector3.ZERO)
	return st.commit()

static func _capsule(r: float, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hh := height * 0.5
	var seg := 8
	var ys := [-hh, -hh + r * 0.45, -hh + r, hh - r, hh - r * 0.45, hh]
	var rs := [0.0, r * 0.82, r, r, r * 0.82, 0.0]
	var rings := []
	for i in ys.size():
		var ring := []
		for j in seg:
			var a := TAU * (j + 0.5 * (i % 2)) / seg
			ring.append(Vector3(cos(a) * rs[i], ys[i], sin(a) * rs[i]))
		rings.append(ring)
	for i in ys.size() - 1:
		var lo: Array = rings[i]
		var hi: Array = rings[i + 1]
		for j in seg:
			var k := (j + 1) % seg
			_tri(st, lo[j], lo[k], hi[j], Vector3(0, (ys[i] + ys[i + 1]) * 0.5, 0))
			_tri(st, hi[j], lo[k], hi[k], Vector3(0, (ys[i] + ys[i + 1]) * 0.5, 0))
	return st.commit()
