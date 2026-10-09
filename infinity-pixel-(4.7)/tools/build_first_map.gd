extends SceneTree

# Spec 012: deterministic authored layout. Reuses the CURRENT low-poly art.
# Pipeline: this tool -> build_collisions.ps1 -> bake_navmesh.gd.
# Spec 017A: this tool also writes refuge_art.tscn (tools/build_refuge_art.gd,
# visual only) and hides the old meshes it replaces. Hidden nodes keep their
# transforms: build_collisions.gd still reads RefugeCore from here.
# Never rewrites actors, gameplay scripts, lighting or camera.
const ART := "res://scenes/visuals/arena_art.tscn"
const RefugeArt := preload("res://tools/build_refuge_art.gd")
# Spec 017A prototype: south ridge pieces replaced by RefugeArt/SouthWall.
const SOUTH_WALL_PIECES := [2, 3, 4]
const REGIONS := "res://scenes/world/world_regions.tscn"
const TREES := [
	Vector2(-13,-19), Vector2(-17,-21), Vector2(-21,-17), Vector2(-20,-11),
	Vector2(-15,-8), Vector2(-18,-5), Vector2(-22,-2), Vector2(-22,7),
	Vector2(-19,11), Vector2(-21,16), Vector2(-18,20), Vector2(-21,24),
	Vector2(-15,25), Vector2(-12,21), Vector2(-9,25), Vector2(-6,20),
	Vector2(-5,26), Vector2(5,26), Vector2(-9,19), Vector2(-4,14),
	Vector2(19,25), Vector2(22,22), Vector2(22,16), Vector2(21,11),
	Vector2(22,7), Vector2(22,-2), Vector2(19,-6), Vector2(22,-11),
	Vector2(21,-17), Vector2(16,-21), Vector2(12,-19), Vector2(-9,-23),
	Vector2(7,-23), Vector2(-16,15), Vector2(-8,16), Vector2(-17,7),
	Vector2(-14.2,-3.9), Vector2(-7,13.5), Vector2(-3.8,23), Vector2(-23,12),
	Vector2(-12,27), Vector2(16,-10),
]
# Indices 18, 19, 38, 39, 40: trees moved out of the stone heath into the
# woodland (denser west, sparse east). 36: south (far-from-camera) side of the west choke.
const ROCKS := [
	Vector2(-15,3.3), Vector2(-16,-13), Vector2(14,-3.9), Vector2(18,-15),
	Vector2(-7,3), Vector2(-14,17), Vector2(-18,23), Vector2(8.46,.74),
	Vector2(17,9), Vector2(14,26), Vector2(18,13), Vector2(20.5,17.5),
	Vector2(16.5,22.8), Vector2(11.2,19.5), Vector2(-5,17), Vector2(14.6,3.4),
]
# Stone heath boulders (index -> scale). Index 7 stays the Spec 009/010 lone
# rock used by the navigation contracts; unlisted rocks keep their scale.
# 13 + 12 flank the heath trail (natural gate); 2 + 15 form the east choke.
const BOULDERS := {
	2: Vector3(2.2, 1.5, 1.9), 8: Vector3(2.6, 1.9, 2.3), 9: Vector3(2.4, 1.7, 2.0),
	10: Vector3(2.0, 1.5, 2.4), 11: Vector3(2.8, 2.0, 2.4), 12: Vector3(2.3, 1.7, 2.1),
	13: Vector3(2.5, 1.8, 2.2), 15: Vector3(2.1, 1.6, 2.0),
}

func _initialize() -> void:
	build.call_deferred()

func own(node: Node, scene: Node) -> void:
	for child in node.get_children():
		child.owner = scene
		own(child, scene)

func save_scene(node: Node, path: String) -> void:
	own(node, node)
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK)
	assert(ResourceSaver.save(packed, path) == OK)

func material(color: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color) # albedo ja e sRGB, como no resto da arte
	m.roughness = 1
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func group(parent: Node, label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	parent.add_child(node)
	return node

func marker(parent: Node, label: String, pos: Vector2, extent := Vector2.ZERO) -> void:
	var node := Marker3D.new()
	node.name = label
	node.position = Vector3(pos.x, 0, pos.y)
	if extent != Vector2.ZERO:
		node.set_meta("size_xz", extent)
	parent.add_child(node)

func polygon(parent: Node, label: String, points: Array, mat: Material, height: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, points.size() - 1):
		for p: Vector2 in [points[0], points[i], points[i + 1]]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(Vector3(p.x, height, p.y))
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = surface.commit()
	node.material_override = mat
	parent.add_child(node)

func patch(parent: Node, label: String, center: Vector2, size: Vector2, mat: Material, height: float) -> void:
	var points := []
	for i in 12:
		var a := TAU * i / 12.0
		var irregular := 1.0 + .06 * sin(i * 2.7)
		points.append(center + Vector2(cos(a) * size.x, sin(a) * size.y) * .5 * irregular)
	polygon(parent, label, points, mat, height)

func path(parent: Node, label: String, points: Array, width: float, mat: Material) -> void:
	var folder := group(parent, label)
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var side := (b - a).normalized().orthogonal() * width * .5
		polygon(folder, "Stretch%d" % i, [a+side, b+side, b-side, a-side], mat, .033)
	for i in range(1, points.size()-1):
		patch(folder, "Bend%d" % i, points[i], Vector2.ONE * width * 1.1, mat, .034)

func build() -> void:
	var art := (load(ART) as PackedScene).instantiate()
	# Expand the compact playable clearing; base keeps its established position.
	var clearing: MeshInstance3D = art.get_node("Clearing")
	clearing.mesh = clearing.mesh.duplicate()
	clearing.mesh.size = Vector3(48, 1, 52)
	clearing.position = Vector3(0, -.5, 2)
	clearing.material_override = material("56774f")
	var bark := material("665239")
	var leaves := [material("36765a"),material("438567"),material("547a4d")]
	var stone := material("7c8980")
	art.get_node("MainPath").visible = false
	# Spec 013C: sem texto 3D "POSTO DE DEFESA" (parecia debug no playtest).
	if art.has_node("PostLabel"):
		art.get_node("PostLabel").free()
	art.get_node("MeetingPath").visible = false
	# Spec 017A: old white crystal -> RefugeArt/Crystal (same solid, same node).
	for label in ["RefugeCore", "RefugeCap"]:
		art.get_node(label).visible = false
	for i in TREES.size():
		var p: Vector2 = TREES[i]
		var h := 2.8 + (i % 4) * .3 # canopies kept low; no camera change
		var trunk: MeshInstance3D = art.get_node("Trunk%d" % i)
		trunk.position = Vector3(p.x, h * .43, p.y)
		trunk.scale = Vector3(.5, h * .9, .5)
		trunk.material_override = bark
		for j in 2:
			var crown: MeshInstance3D = art.get_node("Crown%d_%d" % [i,j])
			crown.position = Vector3(p.x, h * .76 + j * .6, p.y)
			crown.scale = Vector3(2.5-j*.5, 2.0-j*.4, 2.5-j*.5)
			crown.material_override = leaves[i%3]
	for i in ROCKS.size():
		var p: Vector2 = ROCKS[i]
		var rock: MeshInstance3D = art.get_node("Rock%d" % (i*3))
		var y := .38
		if BOULDERS.has(i):
			rock.scale = BOULDERS[i] # keeps the authored rotation
			y = BOULDERS[i].y * .36 # slightly buried, like the small rocks
		rock.position = Vector3(p.x, y, p.y)
		rock.material_override = stone
	# Low vegetation forms clusters beside routes, never rigid blockers.
	var fern_index := 0
	for node in art.get_children():
		if String(node.name).begins_with("Fern"):
			var anchor: Vector2 = TREES[(fern_index / 3 + 7) % TREES.size()]
			node.position = Vector3(anchor.x + .8 + (fern_index%3)*.25, .3, anchor.y - .6)
			fern_index += 1
		elif String(node.name).begins_with("Cliff"):
			node.material_override = stone
			# Escarpment outside the walls: slight jitter so it reads as rock, not a fence.
			var k := int(String(node.name).trim_prefix("Cliff").split("_")[0])
			var side := signf(node.position.x)
			# Radius 2 m: center >= 26 keeps the visual outside the 24.2 m wall.
			node.position.x = side * (26.6 + .6 * sin(k * 1.9 + side))
			node.position.z = -22 + k * 6 + .8 * cos(k * 2.3 + side)
			node.scale = Vector3(4, 3.4 + .6 * absf(sin(k * 1.3 + side)) * 2.0, 5)
		elif String(node.name).begins_with("Mountain"):
			node.material_override = stone
			var i := int(String(node.name).trim_prefix("Mountain"))
			var a := TAU * i / 22.0
			node.position = Vector3(sin(a)*47, 1, cos(a)*47+2)
		elif String(node.name).begins_with("BorderRidge"):
			node.free() # idempotent regeneration, not runtime mutation
	# Visible natural edges for the existing north/south world bounds.
	for side in [-1,1]:
		for i in 7:
			if side < 0 and i in SOUTH_WALL_PIECES:
				continue
			var ridge := MeshInstance3D.new()
			ridge.name = "BorderRidge%s_%d" % ["South" if side<0 else "North",i]
			var mesh := SphereMesh.new()
			mesh.radius=.5
			mesh.height=1
			mesh.radial_segments=8
			mesh.rings=4
			ridge.mesh=mesh
			ridge.scale=Vector3(8,3,4)
			ridge.position=Vector3(-24+i*8, .5, -25 if side<0 else 29)
			ridge.material_override=stone
			art.add_child(ridge)
	# Existing bounds now coincide with visible escarpments at the edge of the valley.
	var bounds := [Vector3(24.2,1,2),Vector3(-24.2,1,2),Vector3(0,1,28.2),Vector3(0,1,-24.2)]
	for i in 4:
		var boundary: StaticBody3D = art.get_node("Boundary%d" % i)
		boundary.position = bounds[i]
		var shape: CollisionShape3D = boundary.get_node("Collider")
		shape.shape = shape.shape.duplicate()
		shape.shape.size = Vector3(.4,2,52) if i<2 else Vector3(48,2,.4)
	save_scene(art, ART)
	art.free()

	var regions := Node3D.new()
	regions.name = "WorldRegions"
	var safe := group(regions, "SafeZone")
	var transition := group(regions, "TransitionZone")
	var wild := group(regions, "WildZone")
	var routes := group(regions, "NightRoutes")
	var resources := group(regions, "ResourceZones")
	var creatures := group(regions, "CreatureZones")
	var landmarks := group(regions, "Landmarks")
	var sand := material("9e9268")
	var trail := material("a68c61")
	patch(safe,"RefugeClearing",Vector2(0,-14),Vector2(25,18),material("7c8860"),.012)
	patch(safe,"BuildClearing",Vector2(7,-15),Vector2(9,11),material("8c9068"),.018)
	marker(safe,"BuildZone",Vector2(7,-15),Vector2(8,10))
	marker(safe,"Center",Vector2(0,-12),Vector2(24,18))
	patch(transition,"Meadow",Vector2(0,0),Vector2(33,18),material("567553"),.009)
	marker(transition,"Center",Vector2(0,1),Vector2(30,16))
	patch(wild,"WoodlandFloor",Vector2(-12,16),Vector2(19,22),material("365b45"),.01)
	patch(wild,"StoneHeath",Vector2(15,17),Vector2(16,21),material("738575"),.011)
	patch(creatures,"EncounterGlade",Vector2(-10,10),Vector2(10,10),material("7b8853"),.021)
	marker(creatures,"CommonTerritory",Vector2(-10,10),Vector2(10,10))
	marker(creatures,"DistantTerritory",Vector2(13,22),Vector2(8,7))
	marker(resources,"WoodlandReserve",Vector2(-17,20),Vector2(9,10))
	marker(resources,"StoneReserve",Vector2(17,17),Vector2(9,12))
	marker(wild,"Center",Vector2(0,22),Vector2(38,12))
	path(routes,"RuinRoad",[Vector2(0,-13),Vector2(0,-5),Vector2(0,4),Vector2(0,14),Vector2(0,26)],4.6,trail)
	path(routes,"WestTrail",[Vector2(0,-9),Vector2(-7,-5),Vector2(-13,0),Vector2(-21,2)],3.8,trail)
	path(routes,"EastTrail",[Vector2(0,-9),Vector2(7,-5),Vector2(14,0),Vector2(21,2)],3.8,trail)
	# Both wild trails leave the road at the same fork, past the meadow.
	path(wild,"GladeTrail",[Vector2(0,6),Vector2(-6,8),Vector2(-10,10),Vector2(-12,17)],2.8,sand)
	path(wild,"HeathTrail",[Vector2(0,6),Vector2(7,9),Vector2(13,13),Vector2(14,22)],2.6,sand)
	patch(wild,"ForkPaving",Vector2(0,6),Vector2(5.2,4.2),sand,.036)
	marker(routes,"RuinEntry",Vector2(0,23))
	marker(routes,"WestEntry",Vector2(-20,2))
	marker(routes,"EastEntry",Vector2(20,2))
	marker(landmarks,"Refuge",Vector2(0,-15))
	marker(landmarks,"DefensePost",Vector2(0,-7))
	marker(landmarks,"OldArch",Vector2(0,16))
	marker(landmarks,"StoneGarden",Vector2(16,17))
	marker(landmarks,"Fork",Vector2(0,6))
	marker(landmarks,"WestChoke",Vector2(-14,.2))
	marker(landmarks,"EastChoke",Vector2(14.2,-.2))
	marker(landmarks,"HeathGate",Vector2(13.8,20.6))
	# Paving around the refuge, no physics on low decorative stones.
	for i in 12:
		var a := TAU*i/12.0
		patch(safe,"Paving%d"%i,Vector2(sin(a)*3.3,cos(a)*3.3-15),Vector2(.8,.6),sand,.035)
	save_scene(regions, REGIONS)
	regions.free()
	RefugeArt.generate()
	print("[MAP012] authored valley: 48 x 52 m, 42 trees, 16 rocks, 3 night routes")
	quit()
