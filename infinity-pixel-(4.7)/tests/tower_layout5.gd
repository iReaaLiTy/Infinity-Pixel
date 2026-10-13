extends Node

const POSITIONS := {
	"SlotWestInner": Vector3(-11, 0, -4),
	"SlotWestOuter": Vector3(-20, 0, 3),
	"SlotRuinMeadow": Vector3(-2, 0, 2),
	"SlotRuinArch": Vector3(5, 0, 13),
	"SlotEastInner": Vector3(11, 0, -4),
	"SlotEastOuter": Vector3(20, 0, 3),
}
var passed := []
var failed := []
func check(ok: bool, label: String) -> void:
	(passed if ok else failed).append(label)
	print(("PASS: " if ok else "FAIL: ") + label)
func _ready() -> void:
	var app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	app.start_game()
	DayNightManager.clock_hold = true
	for i in 20: await get_tree().physics_frame
	var world: Node3D = app.world
	var map := world.get_world_3d().navigation_map
	var space := world.get_world_3d().direct_space_state
	var shape := CylinderShape3D.new()
	shape.radius = 1.25
	shape.height = 2.4
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1 | 8 | 16
	var minimum := INF
	for name in POSITIONS:
		var p: Vector3 = POSITIONS[name]
		query.transform.origin = p + Vector3(0, 1.3, 0)
		check(space.intersect_shape(query).is_empty(), name + ": plataforma sem colisão com cenário/recurso")
		check(flat(NavigationServer3D.map_get_closest_point(map, p), p) < 0.4, name + ": navmesh no ponto")
		var approach_ok := true
		for side in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			var end: Vector3 = p + side * 1.8
			var route := NavigationServer3D.map_get_path(map, Vector3(0, 0, -10), end, true)
			approach_ok = approach_ok and route.size() >= 2 and flat(route[-1], end) < 0.4
		check(approach_ok, name + ": quatro acessos navegáveis")
		for other in POSITIONS:
			if other != name: minimum = minf(minimum, p.distance_to(POSITIONS[other]))
	check(minimum > 10.0, "Separação mínima >10m: %.2f" % minimum)
	# Every unchanged invasion path crosses an L1 range; no tower sits on its centerline.
	var refuge: Vector3 = world.get_node("Territory").global_position
	for name in ["WestEntry", "RuinEntry", "EastEntry"]:
		var entry: Vector3 = world.get_node("WorldRegions/NightRoutes/" + name).global_position
		var route := NavigationServer3D.map_get_path(map, entry, refuge, true)
		var coverage := 0.0
		var clearance := INF
		for k in range(1, route.size()):
			var length: float = route[k - 1].distance_to(route[k])
			for step in maxi(1, ceili(length * 4)):
				var point: Vector3 = route[k - 1].lerp(route[k], float(step) / maxi(1, ceili(length * 4)))
				var nearest := INF
				for p in POSITIONS.values(): nearest = minf(nearest, point.distance_to(p))
				clearance = minf(clearance, nearest)
				if nearest <= 8.0: coverage += 0.25
		check(coverage >= 10, "%s: %.1fm cobertos pelo alcance L1" % [name, coverage])
		check(clearance > 1.4, "%s: %.2fm livres do centro das torres" % [name, clearance])
	print("RESULT: %d passed; %d failed" % [passed.size(), failed.size()])
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var f := FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			f.store_string(JSON.stringify({"passed": passed, "failed": failed}, "\t"))
	app.show_menu()
	get_tree().quit(0 if failed.is_empty() else 1)

func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x, a.z-b.z).length()
