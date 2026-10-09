extends RefCounted

# Spec 019 — feedback visual de combate, so apresentacao: nada aqui le ou muda
# dano, vida, alvo, tempo de ataque ou movimento. Efeitos curtos (<= 0,6 s),
# sem fisica, sem luz propria, sem sombra; cada um se apaga sozinho.
# Malhas compartilhadas (imutaveis). Materiais: um por efeito (a transparencia
# anima por instancia), unshaded e baratos.

static var _shard: ArrayMesh
static var _ring: ArrayMesh

## Lasca facetada (losango 3D) de ~0,2 m.
static func shard_mesh() -> ArrayMesh:
	if _shard == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var top := Vector3(0, 0.12, 0)
		var bottom := Vector3(0, -0.08, 0)
		var ring := [Vector3(0.07, 0, 0), Vector3(0, 0, 0.07), Vector3(-0.07, 0, 0), Vector3(0, 0, -0.07)]
		for i in 4:
			var a: Vector3 = ring[i]
			var b: Vector3 = ring[(i + 1) % 4]
			for tri in [[top, b, a], [bottom, a, b]]:
				var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
				for v in tri:
					st.set_normal(-n)
					st.add_vertex(v)
		_shard = st.commit()
	return _shard

## Anel chato (r interno 0,85, externo 1,0), deitado no chao.
static func ring_mesh() -> ArrayMesh:
	if _ring == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := 24
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var p := [Vector3(cos(a0) * 0.85, 0, sin(a0) * 0.85), Vector3(cos(a0), 0, sin(a0)),
				Vector3(cos(a1), 0, sin(a1)), Vector3(cos(a1) * 0.85, 0, sin(a1) * 0.85)]
			for k in [0, 2, 1, 0, 3, 2]:
				st.set_normal(Vector3.UP)
				st.add_vertex(p[k])
		_ring = st.commit()
	return _ring

static func fx_material(color: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(color, alpha)
	m.no_depth_test = false
	return m

static func _host(near: Node) -> Node:
	# Efeitos ficam no mundo (o Node3D mais alto acima do ator), nao no ator:
	# sobrevivem a morte/queue_free dele e somem junto com o mundo ao reiniciar.
	if near == null or not near.is_inside_tree():
		return null
	var host: Node = near
	while host.get_parent() is Node3D:
		host = host.get_parent()
	return host

static func _instance(host: Node, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	mi.global_position = pos
	return mi

## Faisca de impacto: 4 lascas pequenas que saltam e somem (~0,25 s).
static func hit_spark(near: Node, pos: Vector3, color: Color, count := 4) -> void:
	var host := _host(near)
	if host == null:
		return
	var mat := fx_material(color.lightened(0.25))
	for i in count:
		var mi := _instance(host, shard_mesh(), mat, pos)
		var a := TAU * i / count + randf() * 0.8
		var out := Vector3(cos(a), randf_range(0.4, 0.9), sin(a)) * randf_range(0.45, 0.7)
		mi.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		var t := mi.create_tween().set_parallel(true)
		t.tween_property(mi, "global_position", pos + out, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(mi, "scale", Vector3.ONE * 0.2, 0.22)
		t.chain().tween_callback(mi.queue_free)

## Explosao de eliminacao: lascas na cor da criatura + anel no chao (~0,6 s).
static func burst(near: Node, pos: Vector3, color: Color, count := 10) -> void:
	var host := _host(near)
	if host == null:
		return
	var mat := fx_material(color)
	for i in count:
		var mi := _instance(host, shard_mesh(), mat, pos + Vector3(0, 0.6, 0))
		mi.scale = Vector3.ONE * randf_range(1.2, 2.0)
		var a := TAU * i / count + randf() * 0.5
		var end := pos + Vector3(cos(a) * randf_range(0.9, 1.6), randf_range(0.05, 0.3), sin(a) * randf_range(0.9, 1.6))
		var t := mi.create_tween().set_parallel(true)
		t.tween_property(mi, "global_position", end, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(mi, "rotation", Vector3(randf() * 6.0, randf() * 6.0, 0), 0.45)
		t.tween_property(mi, "scale", Vector3.ONE * 0.1, 0.5).set_delay(0.1)
		t.chain().tween_callback(mi.queue_free)
	ring(near, pos, color, 2.2, 0.5)

## Anel que se expande no chao e some.
static func ring(near: Node, pos: Vector3, color: Color, radius := 2.0, time := 0.5) -> void:
	var host := _host(near)
	if host == null:
		return
	var mat := fx_material(color, 0.85)
	var mi := _instance(host, ring_mesh(), mat, pos + Vector3(0, 0.06, 0))
	mi.scale = Vector3.ONE * 0.3
	var t := mi.create_tween().set_parallel(true)
	t.tween_property(mi, "scale", Vector3.ONE * radius, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, time)
	t.chain().tween_callback(mi.queue_free)

static var _arc: ArrayMesh

## Arco do golpe (meia-lua deitada, abrindo para -Z), ~110 graus.
static func arc_mesh() -> ArrayMesh:
	if _arc == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := 12
		for i in n:
			var a0 := deg_to_rad(-55.0 + 110.0 * i / n)
			var a1 := deg_to_rad(-55.0 + 110.0 * (i + 1) / n)
			# mais grosso no meio, fino nas pontas
			var w0 := 0.28 * sin(PI * float(i) / n) + 0.04
			var w1 := 0.28 * sin(PI * float(i + 1) / n) + 0.04
			var p := [Vector3(sin(a0), 0, -cos(a0)) * (1.5 - w0), Vector3(sin(a0), 0, -cos(a0)) * 1.5,
				Vector3(sin(a1), 0, -cos(a1)) * 1.5, Vector3(sin(a1), 0, -cos(a1)) * (1.5 - w1)]
			for k in [0, 2, 1, 0, 3, 2]:
				st.set_normal(Vector3.UP)
				st.add_vertex(p[k])
		_arc = st.commit()
	return _arc

## Rastro do golpe do jogador na direcao `yaw` (frente = -Z). ~0,18 s.
static func slash(near: Node, pos: Vector3, yaw: float, color := Color("fff3d6")) -> void:
	var host := _host(near)
	if host == null:
		return
	var mat := fx_material(color, 0.75)
	var mi := _instance(host, arc_mesh(), mat, pos)
	mi.rotation = Vector3(deg_to_rad(-8.0), yaw, 0)
	mi.scale = Vector3.ONE * 0.75
	var t := mi.create_tween().set_parallel(true)
	t.tween_property(mi, "scale", Vector3.ONE * 1.05, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.18)
	t.chain().tween_callback(mi.queue_free)
