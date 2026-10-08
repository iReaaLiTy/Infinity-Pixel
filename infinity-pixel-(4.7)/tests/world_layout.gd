extends Node

var passed: Array[String] = []
var failed: Array[String] = []

func check(ok: bool, label: String) -> void:
	(passed if ok else failed).append(label)
	print(("PASS: " if ok else "FAIL: ") + label)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

func _ready() -> void:
	var app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	app.start_game()
	await frames(10)
	var world: Node3D = app.world
	var player: CharacterBody3D = world.get_node("Player")
	var spawn: Vector3 = world.get_node("PlayerSpawn").global_position
	var base = world.get_node("Territory")
	var map := world.get_world_3d().navigation_map
	var regions := world.get_node("WorldRegions")
	var encounter = world.get_node("EncounterSpawner").current_encounter
	encounter.set_physics_process(false)
	check(flat(spawn, base.position) >= 3 and flat(spawn, base.position) <= 7, "Spawn seguro perto do refugio, fora do nucleo")
	check(flat(player.position, spawn) < .1 and player.current_hp == 100, "Player nasce no marcador com 100 HP")
	check(encounter.territorial and flat(encounter.home_position, regions.get_node("CreatureZones/CommonTerritory").position) < .1, "Encontro territorial localizado na clareira de criaturas")
	var shape := CapsuleShape3D.new()
	shape.radius = .55
	shape.height = 1.6
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1 | 8
	var space := world.get_world_3d().direct_space_state
	var destinations: Dictionary = {"PlayerSpawn": spawn, "RefugeApproach": base.position + Vector3(0,0,1.3)}
	for marker: Marker3D in regions.find_children("*", "Marker3D", true, false):
		if marker.name in ["Refuge", "StoneGarden"]:
			continue # landmarks indicate solids, not a walk destination
		destinations[String(regions.get_path_to(marker))] = marker.global_position
	check(NavigationServer3D.map_get_iteration_id(map) > 0, "Navmesh sincronizada")
	for label in destinations:
		var p: Vector3 = destinations[label]
		var on_mesh := NavigationServer3D.map_get_closest_point(map, p)
		var route := NavigationServer3D.map_get_path(map, spawn, p, true)
		check(flat(on_mesh,p)<.35 and route.size()>=2 and flat(route[route.size()-1],p)<.35, "Regiao conectada a base: " + label)
		query.transform.origin = Vector3(p.x, .95, p.z)
		check(space.intersect_shape(query,1).is_empty(), "Destino sem sobreposicao solida: " + label)
	var build_zone: Marker3D = regions.get_node("SafeZone/BuildZone")
	var open := true
	for x in [-3.5,0.0,3.5]:
		for z in [-4.5,0.0,4.5]:
			var p := build_zone.global_position + Vector3(x,0,z)
			query.transform.origin = p + Vector3(0,.95,0)
			open = open and space.intersect_shape(query,1).is_empty() and flat(NavigationServer3D.map_get_closest_point(map,p),p)<.35
	check(open, "BuildZone 8x10 m aberta e navegavel em nove amostras")
	# Actual WASD route out of the refuge, across meadow and through old arch.
	var event := InputEventKey.new()
	event.keycode = KEY_S
	event.physical_keycode = KEY_S
	event.pressed = true
	Input.parse_input_event(event)
	await frames(310)
	event.pressed = false
	Input.parse_input_event(event)
	check(player.position.z > 20 and absf(player.position.x)<.3, "Player sai da base e alcanca area selvagem por WASD real")
	player.take_damage(1000)
	await frames(125)
	check(not player.is_dead and player.current_hp==100 and flat(player.position,spawn)<.1, "Morte e respawn retornam a nova area segura")
	# All physical holes must exclude their center; no surface on top of rocks.
	var holes := true
	for body: StaticBody3D in world.get_node("ArenaCollision").get_children():
		if String(body.name).begins_with("Trunk") or String(body.name).begins_with("Rock"):
			var p := body.global_position
			var nearest := NavigationServer3D.map_get_closest_point(map,p)
			holes = holes and flat(nearest,p)>.4 and nearest.y<.6
	check(holes, "Troncos e pedras recortados na navmesh")
	# Visual solido = colisao no mesmo lugar (leitura nativa do Transform3D).
	var art := world.get_node("ArenaArt")
	var solids := world.get_node("ArenaCollision").get_children()
	var same_place := solids.size() == 66
	var worst := 0.0
	for body: StaticBody3D in solids:
		var visual := art.get_node_or_null(NodePath(body.name)) as Node3D
		if visual == null:
			same_place = false
			continue
		worst = maxf(worst, flat(body.global_position, visual.global_position))
		var solid_shape: Shape3D = body.get_node("CollisionShape3D").shape
		if String(body.name).begins_with("Rock"):
			same_place = same_place and is_equal_approx(solid_shape.radius, maxf(visual.scale.x, visual.scale.z) * .45)
		elif String(body.name).begins_with("Trunk"):
			same_place = same_place and is_equal_approx(solid_shape.radius, visual.scale.x * .5)
	check(same_place and worst < .01, "66 colisores no mesmo XZ e tamanho dos visuais (maior desvio %.3f m)" % worst)
	var uncovered := []
	for visual in art.get_children():
		var label := String(visual.name)
		if label.begins_with("Trunk") or label.begins_with("Rock") or label.begins_with("Arch") \
				or label.begins_with("FirePost") or label.begins_with("BannerPole") or label == "RefugeCore":
			if not world.get_node("ArenaCollision").has_node(NodePath(visual.name)):
				uncovered.append(label)
	check(uncovered.is_empty(), "Nenhum solido visual sem colisor %s" % [uncovered])
	# Sem ilhas: nenhum vertice da navmesh acima do chao (topo de pedra/arco).
	var high := 0
	for v in world.get_node("NavigationRegion").navigation_mesh.get_vertices():
		if v.y > .6: high += 1
	check(high == 0, "Navmesh sem ilhas em cima de pedras/arco (%d vertices altos)" % high)
	# Trilhas legiveis: nenhum tronco/pedra sobre a faixa de uma trilha.
	var blocked := []
	for trail: Node3D in regions.get_node("NightRoutes").get_children() + [regions.get_node("WildZone/GladeTrail"), regions.get_node("WildZone/HeathTrail")]:
		for stretch in trail.get_children():
			if not String(stretch.name).begins_with("Stretch"): continue
			var faces: PackedVector3Array = stretch.mesh.get_faces()
			for body: StaticBody3D in solids:
				var p := Vector2(body.global_position.x, body.global_position.z)
				var inside := false
				for f in range(0, faces.size(), 3):
					inside = inside or Geometry2D.point_is_inside_triangle(p, Vector2(faces[f].x, faces[f].z), Vector2(faces[f+1].x, faces[f+1].z), Vector2(faces[f+2].x, faces[f+2].z))
				if inside and not String(body.name).begins_with("Arch"):
					blocked.append("%s/%s:%s" % [trail.name, stretch.name, body.name])
	check(blocked.is_empty(), "Nenhum obstaculo no meio das trilhas %s" % [blocked])
	# Camera fixa olhando para -Z (Spec 007): copa a ate 3,5 m do lado da camera
	# (+Z) de um ponto da trilha esconde o Player ali. Amostra a linha central.
	var hidden := []
	for trail: Node3D in regions.get_node("NightRoutes").get_children() + [regions.get_node("WildZone/GladeTrail"), regions.get_node("WildZone/HeathTrail")]:
		for stretch in trail.get_children():
			if not String(stretch.name).begins_with("Stretch"): continue
			var faces: PackedVector3Array = stretch.mesh.get_faces()
			# quad = 2 triangulos: os cantos dao as pontas a/b da faixa
			var corners := {}
			for f in faces: corners[Vector2(snappedf(f.x, .01), snappedf(f.z, .01))] = true
			var pts: Array = corners.keys()
			var a: Vector2 = (pts[0] + pts[3]) * .5 if pts.size() == 4 else pts[0]
			var b: Vector2 = (pts[1] + pts[2]) * .5 if pts.size() == 4 else pts[0]
			for t in 11:
				var s: Vector2 = a.lerp(b, t / 10.0)
				for body: StaticBody3D in solids:
					if not String(body.name).begins_with("Trunk"): continue
					var dz := body.global_position.z - s.y
					if dz > 0 and dz < 3.5 and absf(body.global_position.x - s.x) < 1.3:
						var tag := "%s/%s" % [trail.name, body.name]
						print("[OCLUSAO] %s amostra %s tronco %s" % [tag, s, body.global_position])
						if not tag in hidden: hidden.append(tag)
	check(hidden.is_empty(), "Nenhuma copa do lado da camera escondendo trilhas %s" % [hidden])
	# Bosque denso x regiao rochosa com mais pedras que arvores.
	var counts := {"WoodlandReserve": [0, 0], "StoneReserve": [0, 0]}
	for zone in counts:
		var m: Marker3D = regions.get_node("ResourceZones/" + zone)
		var half: Vector2 = m.get_meta("size_xz") * .5 + Vector2(2, 2)
		for body: StaticBody3D in solids:
			var d := body.global_position - m.global_position
			if absf(d.x) <= half.x and absf(d.z) <= half.y:
				counts[zone][0 if String(body.name).begins_with("Trunk") else 1] += 1
	check(counts.WoodlandReserve[0] > counts.StoneReserve[0] and counts.StoneReserve[1] > counts.StoneReserve[0],
		"Bosque mais arborizado; regiao rochosa com mais pedras que arvores (bosque %s, pedras %s)" % [counts.WoodlandReserve, counts.StoneReserve])
	player.remove_from_group("player")
	player.collision_layer = 0
	player.set_physics_process(false)
	player.position = Vector3(0,0,-40)
	base.health = 1000 # test fixture: allow all three routes to complete before defeat
	DayNightManager.start_night()
	var wave = world.get_node("WaveManager")
	var seen := {}
	var starts: Array[Vector3] = []
	for i in 285:
		await frames(1)
		for enemy in wave._active_wave_enemies:
			if not seen.has(enemy):
				seen[enemy] = true
				starts.append(enemy.position)
	check(starts.size()==3, "Tres inimigos nascem em rotas distintas")
	var distinct := starts.size()==3
	for i in starts.size():
		for j in range(i+1,starts.size()):
			distinct = distinct and flat(starts[i],starts[j])>15
	check(distinct, "Entradas noturnas separadas por mais de 15 m")
	await frames(1000)
	var arrived: bool = wave._active_wave_enemies.size()==3
	for enemy in wave._active_wave_enemies:
		arrived = arrived and flat(enemy.position,base.position)<=1.5
	check(arrived and base.health<1000, "Inimigos percorrem as tres rotas e atacam o refugio")
	for enemy in wave._active_wave_enemies.keys():
		enemy.take_damage(1000)
	await frames(5)
	check(DayNightManager.is_day() and app.screen=="playing" and not get_tree().paused, "Onda vencida retorna ao dia sem interrupcao")
	base.take_damage(1000)
	await frames(3)
	check(app.screen=="defeat", "Refugio continua sendo condicao de derrota")
	app.show_menu()
	await frames(3)
	var destination := "user://spec012-world.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): destination=arg.trim_prefix("--report=")
	var file := FileAccess.open(destination,FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed,"display":DisplayServer.get_name()},"  "))
	file.close()
	print("SPEC012 RESULTS: %d passed; %d failed" % [passed.size(),failed.size()])
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)
