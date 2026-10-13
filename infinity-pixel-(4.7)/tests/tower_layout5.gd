extends Node

# Gameplay 5.0 — espacamento dos 6 pontos de defesa (playtest externo: "torres
# muito proximas"). Le os slots REAIS da cena (scenes/world/prototype_area.tscn)
# e confere: posicoes documentadas, separacao, colisao, navmesh, acesso, rotas
# livres, cobertura das 3 rotas, torres L1-L3 em todos os slots e navegacao.
# Uso: Godot [--headless] --path . res://tests/tower_layout5.tscn [-- --report=<arquivo>]
const Layout := preload("res://tools/valley_layout.gd")
const ValleyArt := preload("res://tools/build_valley_art.gd")
const OLD := {
	"SlotWestInner": Vector3(-10.5, 0, -5.5),
	"SlotWestOuter": Vector3(-18, 0, -1.5),
	"SlotRuinMeadow": Vector3(-3.8, 0, -1),
	"SlotRuinArch": Vector3(3.6, 0, 12.5),
	"SlotEastInner": Vector3(10.5, 0, -5.5),
	"SlotEastOuter": Vector3(18, 0, -1.5),
}
const POSITIONS := {
	"SlotWestInner": Vector3(-12, 0, -11),
	"SlotWestOuter": Vector3(-19, 0, 6),
	"SlotRuinMeadow": Vector3(-3.5, 0, 1),
	"SlotRuinArch": Vector3(4.5, 0, 13),
	"SlotEastInner": Vector3(12.5, 0, -8),
	"SlotEastOuter": Vector3(19, 0, 6),
}
const ROUTE := {"SlotWestInner": "Oeste", "SlotWestOuter": "Oeste", "SlotRuinMeadow": "Ruína", "SlotRuinArch": "Ruína", "SlotEastInner": "Leste", "SlotEastOuter": "Leste"}
var passed := []
var failed := []

func check(ok: bool, label: String) -> void:
	(passed if ok else failed).append(label)
	print(("PASS: " if ok else "FAIL: ") + label)

func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

static func min_separation(points: Array) -> float:
	var best := INF
	for i in points.size():
		for j in range(i + 1, points.size()):
			best = minf(best, Vector2(points[i].x - points[j].x, points[i].z - points[j].z).length())
	return best

## [metros do caminho a ate `reach` de alguma torre, menor distancia ao centro de uma torre]
func coverage_of(route: PackedVector3Array, towers: Array, reach: float) -> Array:
	var coverage := 0.0
	var clearance := INF
	for k in range(1, route.size()):
		var steps := maxi(1, ceili(route[k - 1].distance_to(route[k]) * 4))
		for step in steps:
			var point: Vector3 = route[k - 1].lerp(route[k], float(step) / steps)
			var nearest := INF
			for p in towers: nearest = minf(nearest, flat(point, p))
			clearance = minf(clearance, nearest)
			if nearest <= reach: coverage += route[k - 1].distance_to(route[k]) / steps
	return [coverage, clearance]

func _ready() -> void:
	var app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	app.start_game()
	DayNightManager.clock_hold = true
	for i in 20: await get_tree().physics_frame
	var world: Node3D = app.world
	var slots: Node = world.get_node("DefenseSlots")
	var map := world.get_world_3d().navigation_map
	var space := world.get_world_3d().direct_space_state

	# 1. Seis slots, nas posicoes documentadas, rota informativa preservada.
	check(slots.get_child_count() == 6, "Seis pontos de defesa")
	var real := {}
	for slot in slots.get_children():
		real[String(slot.name)] = slot.global_position
	var same := POSITIONS.keys().all(func(n): return real.has(n) and real[n].distance_to(POSITIONS[n]) < 0.01)
	check(same, "Slots da cena = posicoes documentadas (%s)" % [real])
	check(POSITIONS.keys().all(func(n): return slots.get_node(n).route == ROUTE[n]), "Rota informativa de cada slot preservada")
	# O gerador do vale limpa relevo/detalhes nos mesmos pontos (regeneracao estavel).
	var art_ok := true
	for n in POSITIONS:
		var p: Vector3 = POSITIONS[n]
		art_ok = art_ok and ValleyArt.SLOTS.any(func(s): return s.distance_to(Vector2(p.x, p.z)) < 0.01)
	check(art_ok and ValleyArt.SLOTS.size() == 6, "tools/build_valley_art.gd usa as mesmas 6 posicoes")

	# 2. Separacao: minima maior que a antiga e acima de 11 m.
	var old_min := min_separation(OLD.values())
	var new_min := min_separation(real.values())
	check(new_min >= 11.0 and new_min > old_min + 2.5, "Separacao minima %.2f m (antes %.2f m)" % [new_min, old_min])

	# 3. Cada slot: sem colisao, sobre a navmesh, 4 acessos, fora das trilhas,
	# longe do Refugio, da area de construcao, das entradas, marcos e coletaveis.
	var shape := CylinderShape3D.new()
	shape.radius = 1.25
	shape.height = 2.4
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1 | 8 | 16
	var collectables: Array = get_tree().get_nodes_in_group("collectable")
	var refuge: Vector3 = world.get_node("Territory").global_position
	for n in POSITIONS:
		var p: Vector3 = real.get(n, POSITIONS[n])
		var p2 := Vector2(p.x, p.z)
		query.transform.origin = p + Vector3(0, 1.3, 0)
		check(space.intersect_shape(query).is_empty(), n + ": plataforma sem colisao com cenario/recurso")
		check(flat(NavigationServer3D.map_get_closest_point(map, p), p) < 0.4, n + ": navmesh no ponto")
		var approach_ok := true
		for side in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			var end: Vector3 = p + side * 1.8
			var route := NavigationServer3D.map_get_path(map, Vector3(0, 0, -10), end, true)
			approach_ok = approach_ok and route.size() >= 2 and flat(route[-1], end) < 0.4
		check(approach_ok, n + ": quatro acessos navegaveis (Player circula)")
		var trail_gap := INF
		for path in Layout.PATHS:
			trail_gap = minf(trail_gap, Layout.path_distance(p2, path.points) - path.width * 0.5)
		check(trail_gap >= 1.0, "%s: borda da trilha a %.2f m do centro (torre r=0,8 fora do caminho)" % [n, trail_gap])
		var far_ok: bool = flat(p, refuge) >= 8.0 and not Layout.in_build_zone(p2, 1.0) \
			and Layout.ENTRIES.all(func(e): return p2.distance_to(e) >= 4.0) \
			and ValleyArt.MARKERS.all(func(m): return p2.distance_to(m) >= 3.0) \
			and collectables.all(func(c): return flat(c.global_position, p) >= 3.0)
		check(far_ok, n + ": longe do Refugio, area de construcao, entradas, marcos e coletaveis")

	# 4. Rotas noturnas: caminho real da navmesh coberto pelo alcance L1 e sem
	# passar pelo centro de nenhuma torre.
	var l1: float = preload("res://scenes/world/defense_tower.gd").LEVELS[0].range
	for entry_name in ["WestEntry", "RuinEntry", "EastEntry"]:
		var entry: Vector3 = world.get_node("WorldRegions/NightRoutes/" + entry_name).global_position
		var route := NavigationServer3D.map_get_path(map, entry, refuge, true)
		var now := coverage_of(route, real.values(), l1)
		var before := coverage_of(route, OLD.values(), l1)
		check(now[0] >= 12.0 and now[0] >= before[0] * 0.9, "%s: %.1f m do caminho sob alcance L1 de %.0f m (layout antigo: %.1f m)" % [entry_name, now[0], l1, before[0]])
		check(now[1] > 2.0, "%s: caminho passa a %.2f m do centro da torre mais proxima" % [entry_name, now[1]])

	# 5. Torres em todos os slots, melhorias L1 -> L3 e rotas ainda navegaveis.
	var economy = world.get_node("DefenseEconomy")
	economy.points = 10000
	var built := 0
	var maxed := 0
	for slot in slots.get_children():
		slot.build()
		if not slot.is_empty():
			built += 1
			while not slot.tower.is_max_level():
				slot.tower.upgrade()
			if slot.tower.level == 3: maxed += 1
	for i in 5: await get_tree().physics_frame
	check(built == 6 and maxed == 6, "Torres em todos os 6 slots e melhorias ate L3 (%d/%d)" % [built, maxed])
	var routes_ok := true
	for entry_name in ["WestEntry", "RuinEntry", "EastEntry"]:
		var entry: Vector3 = world.get_node("WorldRegions/NightRoutes/" + entry_name).global_position
		var route := NavigationServer3D.map_get_path(map, entry, refuge + Vector3(0, 0, 4), true)
		routes_ok = routes_ok and route.size() > 1 and flat(route[-1], refuge + Vector3(0, 0, 4)) < 1.0
	check(routes_ok, "Com 6 torres: as 3 rotas seguem ate o Refugio")
	var bodies_ok := true
	for slot in slots.get_children():
		for other in slots.get_children():
			if slot != other and is_instance_valid(slot.tower) and is_instance_valid(other.tower):
				bodies_ok = bodies_ok and flat(slot.tower.global_position, other.tower.global_position) > 10.0
	check(bodies_ok, "Modelos das torres sem sobreposicao (centros a mais de 10 m)")

	print("RESULT: %d passed; %d failed" % [passed.size(), failed.size()])
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var f := FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			f.store_string(JSON.stringify({"passed": passed, "failed": failed}, "\t"))
	app.show_menu()
	get_tree().quit(0 if failed.is_empty() else 1)
