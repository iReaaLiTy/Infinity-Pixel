extends Node3D

# Visual Overhaul 3.0 (Fase F) — sinais pre-historicos no Vale de Jade, postos
# com intencao: um sitio fossil perto da Ruina do Arco, outro na Regiao
# Rochosa, rastros de pegadas fossilizadas acompanhando as trilhas selvagens
# (o caminho que os dinossauros fazem) e amonites nas bordas das pedras.
# Tudo BAIXO (<= 0,28 m) e sem colisao: nao bloqueia caminho, nao mexe em
# navmesh nem em fisica. Uma malha so (uma chamada de desenho), sem sombra.

const Props := preload("res://scenes/visuals/prehistoric_props.gd")

## [tipo, x, z, giro]
const PLACES := [
	["slab", 5.6, 19.4, 0.5], ["ribs", 6.9, 21.2, 1.1], ["ammonite", 4.3, 21.0, 0.0],
	["slab", 19.2, 11.6, -0.7], ["ribs", 17.6, 9.9, 0.3], ["ammonite", 20.4, 14.2, 1.0],
	["ammonite", 10.6, 20.6, 2.0], ["ammonite", 17.2, 24.2, 0.4], ["ammonite", -16.8, 21.6, 1.3],
	["ribs", -18.6, 8.2, 2.2], ["ammonite", -20.2, 16.4, 0.8],
]
## Rastros: [de, ate, passos] — ao lado das trilhas selvagens (Spec 012).
const TRAILS := [
	[Vector2(-2.6, 8.4), Vector2(-9.0, 12.4), 9],
	[Vector2(3.4, 9.6), Vector2(11.4, 15.6), 10],
	[Vector2(-15.0, 18.0), Vector2(-11.2, 24.0), 7],
]

func _ready() -> void:
	name = "FossilArt"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var meshes := {"slab": Props.fossil_slab_mesh(), "ribs": Props.low_ribs_mesh(), "ammonite": Props.ammonite_slab_mesh()}
	for p in PLACES:
		st.append_from(meshes[p[0]], 0, Transform3D(Basis(Vector3.UP, p[3]), Vector3(p[1], 0.0, p[2])))
	var print_mesh := Props.footprint_mesh()
	for t in TRAILS:
		var a: Vector2 = t[0]
		var b: Vector2 = t[1]
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		var yaw := atan2(-dir.x, -dir.y)
		for i in int(t[2]):
			var at := a.lerp(b, (i + 0.5) / float(t[2])) + side * (0.22 if i % 2 == 0 else -0.22)
			st.append_from(print_mesh, 0, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(1.35, 1.0, 1.35)), Vector3(at.x, 0.05, at.y)))
	var mi := MeshInstance3D.new()
	mi.name = "Fossils"
	mi.mesh = st.commit()
	mi.material_override = Props.material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# Cranios de dinossauro na travessa dos dois estandartes do Refugio (no alto,
	# acima dos solidos BannerPole): marca o Refugio como lugar de cacadores.
	var skulls := SurfaceTool.new()
	skulls.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in [-2.0, 2.0]:
		skulls.append_from(Props.skull(Vector3.ZERO, 0.0).mesh, 0, Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * 0.55), Vector3(x, 3.36, -15.62)))
	var sk := MeshInstance3D.new()
	sk.name = "RefugeSkulls"
	sk.mesh = skulls.commit()
	sk.material_override = Props.material()
	add_child(sk)
