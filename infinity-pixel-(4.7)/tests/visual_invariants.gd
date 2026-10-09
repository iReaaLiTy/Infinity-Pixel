extends Node

# Spec 017A: a reforma visual nao pode mexer em fisica, navegacao nem posicoes
# de gameplay. Compara o mundo real (main.tscn -> start_game) com a linha de
# base gravada ANTES da reforma (tests/visual_invariants_baseline.json).
# Uso: -- --report=<json>            compara com a linha de base
#      -- --write-baseline=<json>    grava uma nova linha de base (so na Etapa 1)
const BASELINE := "res://tests/visual_invariants_baseline.json"
const NAVMESH := "res://scenes/world/arena_navmesh.tres"
const COLLISION := "res://scenes/world/arena_collision.tscn"

var passed: Array[String] = []
var failed: Array[String] = []

func check(ok: bool, label: String) -> void:
	(passed if ok else failed).append(label)
	print(("PASS: " if ok else "FAIL: ") + label)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func r(v) -> Variant:
	# Arredonda para 4 casas: so ruido de float nao conta como mudanca.
	if v is float:
		return snappedf(v, 0.0001)
	if v is Vector3:
		return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001), snappedf(v.z, 0.0001)]
	if v is Vector2:
		return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001)]
	if v is Transform3D:
		return r(v.basis.x) + r(v.basis.y) + r(v.basis.z) + r(v.origin)
	if v is Array or v is PackedVector3Array or v is PackedFloat32Array:
		var text := var_to_str(v)
		return text if text.length() < 200 else "sha256:" + text.sha256_text()
	return var_to_str(v)

func shape_data(shape: Shape3D) -> Dictionary:
	var d := {"type": shape.get_class()}
	for p in shape.get_property_list():
		if p.usage & PROPERTY_USAGE_STORAGE and not String(p.name).begins_with("resource_") \
				and p.name != "script":
			d[p.name] = r(shape.get(p.name))
	return d

func is_dynamic(node: Node, world: Node) -> bool:
	while node != world and node != null:
		if node is CharacterBody3D or node is RigidBody3D:
			return true
		node = node.get_parent()
	return false

func solids(world: Node3D) -> Dictionary:
	var out := {}
	for body: CollisionObject3D in world.find_children("*", "CollisionObject3D", true, false):
		if is_dynamic(body, world):
			continue
		var shapes := []
		for owner_id in body.get_shape_owners():
			var holder := body.shape_owner_get_owner(owner_id) as Node3D
			for i in body.shape_owner_get_shape_count(owner_id):
				var s := shape_data(body.shape_owner_get_shape(owner_id, i))
				s["local"] = r(body.shape_owner_get_transform(owner_id))
				s["disabled"] = body.is_shape_owner_disabled(owner_id)
				s["holder"] = String(holder.name) if holder != null else ""
				shapes.append(s)
		out[String(world.get_path_to(body))] = {
			"class": body.get_class(), "layer": body.collision_layer, "mask": body.collision_mask,
			"global": r(body.global_transform), "groups": body.get_groups().map(func(g): return String(g)),
			"shapes": shapes,
		}
	return out

func gameplay(world: Node3D) -> Dictionary:
	var out := {}
	for label in ["PlayerSpawn", "Territory", "EnemySpawnPoint", "EncounterSpawner"]:
		out[label] = r(world.get_node(label).global_position)
	out["WaveManager.spawn_offsets"] = world.get_node("WaveManager").spawn_offsets.map(func(v): return r(v))
	for slot: Node3D in world.get_node("DefenseSlots").get_children():
		out["DefenseSlots/" + slot.name] = [r(slot.global_position), slot.route]
	for item: Node3D in world.get_node("Collectables").get_children():
		out["Collectables/" + item.name] = r(item.global_position)
	var regions := world.get_node("WorldRegions")
	for marker: Marker3D in regions.find_children("*", "Marker3D", true, false):
		out["WorldRegions/" + String(regions.get_path_to(marker))] = [r(marker.global_position), r(marker.get_meta("size_xz", Vector2.ZERO))]
	return out

# Visuais que a ferramenta de colisao (build_collisions.gd) le para gerar os 66
# solidos: se mudarem, uma regeneracao futura mudaria a fisica.
func collision_sources(world: Node3D) -> Dictionary:
	var out := {}
	for visual in world.get_node("ArenaArt").get_children():
		var label := String(visual.name)
		if label.begins_with("Trunk") or label.begins_with("Rock") or label.begins_with("Arch") \
				or label.begins_with("FirePost") or label.begins_with("BannerPole") or label == "RefugeCore":
			var d := {"transform": r((visual as Node3D).transform)}
			if label.begins_with("Arch"):
				d["mesh_size"] = r(visual.mesh.size)
			out[label] = d
	return out

func snapshot(world: Node3D) -> Dictionary:
	return {
		"navmesh_sha256": FileAccess.get_sha256(NAVMESH),
		"collision_scene_sha256": FileAccess.get_sha256(COLLISION),
		"arena_collision_count": world.get_node("ArenaCollision").get_child_count(),
		"navigation_source": get_tree().get_nodes_in_group("navigation_source").map(func(n): return String(world.get_path_to(n))),
		"navmesh_vertices": world.get_node("NavigationRegion").navigation_mesh.get_vertices().size(),
		"navmesh_polygons": world.get_node("NavigationRegion").navigation_mesh.get_polygon_count(),
		"solids": solids(world),
		"collision_sources": collision_sources(world),
		"gameplay": gameplay(world),
	}

# Nomes automaticos de nos criados por codigo ("@CollisionShape3D@99") mudam com
# a quantidade de nos criados antes deles; nao sao fisica.
func canon(v) -> String:
	var re := RegEx.create_from_string("@(\\w+)@\\d+")
	return re.sub(JSON.stringify(v, "", true), "@$1@", true)

func diff(a: Dictionary, b: Dictionary) -> Array:
	var out := []
	for k in a:
		if not b.has(k):
			out.append("faltando " + str(k))
		elif canon(a[k]) != canon(b[k]):
			out.append(str(k))
			print("  diferenca em %s:\n    antes  %s\n    depois %s" % [k, canon(a[k]), canon(b[k])])
	for k in b:
		if not a.has(k):
			out.append("novo " + str(k))
	return out

func _ready() -> void:
	var report := ""
	var write := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report = arg.trim_prefix("--report=")
		if arg.begins_with("--write-baseline="): write = arg.trim_prefix("--write-baseline=")
	var app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	app.start_game()
	await frames(10)
	var world: Node3D = app.world
	var now := snapshot(world)
	if write != "":
		var f := FileAccess.open(write, FileAccess.WRITE)
		f.store_string(JSON.stringify(now, "\t", true))
		f.close()
		print("[017A] linha de base gravada em %s: %d solidos, %d posicoes" % [write, now.solids.size(), now.gameplay.size()])
		get_tree().quit()
		return
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	# Reidrata via JSON para comparar tipos iguais (int x float).
	now = JSON.parse_string(JSON.stringify(now))
	check(now.navmesh_sha256 == base.navmesh_sha256, "Navmesh com o mesmo hash da linha de base (%s)" % now.navmesh_sha256.left(12))
	check(now.collision_scene_sha256 == base.collision_scene_sha256, "arena_collision.tscn com o mesmo hash")
	check(int(now.arena_collision_count) == 66, "ArenaCollision com 66 solidos (%d)" % now.arena_collision_count)
	check(now.navmesh_vertices == base.navmesh_vertices and now.navmesh_polygons == base.navmesh_polygons, "Navmesh carregada com os mesmos vertices e poligonos")
	var nav_new: Array = now.navigation_source.filter(func(p): return not p in base.navigation_source)
	check(nav_new.is_empty() and now.navigation_source.size() == base.navigation_source.size(), "Grupo navigation_source igual (novos: %s)" % [nav_new])
	var solid_diff := diff(base.solids, now.solids)
	check(solid_diff.is_empty(), "Todos os %d corpos estaticos iguais: camada, mascara, transform, formas (diferencas: %s)" % [base.solids.size(), solid_diff])
	var source_diff := diff(base.collision_sources, now.collision_sources)
	check(source_diff.is_empty(), "Visuais lidos por build_collisions.gd intocados (diferencas: %s)" % [source_diff])
	var play_diff := diff(base.gameplay, now.gameplay)
	check(play_diff.is_empty(), "Posicoes de gameplay iguais (%d itens; diferencas: %s)" % [base.gameplay.size(), play_diff])
	# Regras da reforma visual (so valem quando a arte nova existe).
	var refuge_art := world.get_node_or_null("RefugeArt")
	if refuge_art != null:
		check(refuge_art.find_children("*", "CollisionObject3D", true, false).is_empty(), "RefugeArt sem nenhum corpo fisico")
		check(not refuge_art.is_in_group("navigation_source"), "RefugeArt fora de navigation_source")
		# Regra 4: no chao andavel (dentro dos Boundary: |x| < 24,2; -24,2 < z < 28,2)
		# so pecas rentes (ate 0,15 m de altura propria); acima de 0,3 m, so sobre
		# um solido (meta on_solid, conferida contra o solido real abaixo).
		var tall := []
		var space := world.get_world_3d().direct_space_state
		for mi: MeshInstance3D in refuge_art.find_children("*", "MeshInstance3D", true, false):
			if not mi.is_visible_in_tree():
				continue
			var box := mi.global_transform * mi.get_aabb()
			var c := box.get_center()
			var walkable := absf(c.x) < 24.2 and c.z > -24.2 and c.z < 28.2
			if not walkable or (box.size.y <= 0.15) or box.end.y <= 0.3:
				continue
			var probe := PhysicsPointQueryParameters3D.new()
			probe.position = Vector3(c.x, 1.0, c.z)
			probe.collision_mask = 1 | 8
			if not (mi.has_meta("on_solid") and not space.intersect_point(probe, 1).is_empty()):
				tall.append(String(mi.name))
		check(tall.is_empty(), "Nenhuma peca alta sem solido no chao andavel %s" % [tall])
	var slot = world.get_node("DefenseSlots/SlotWestInner")
	check(slot.preview_ring != null and slot.has_method("build") and slot.is_empty(), "API do ponto de defesa preservada (preview_ring, build, tower)")
	print("RESULT: %d passed, %d failed" % [passed.size(), failed.size()])
	if report != "":
		var f := FileAccess.open(report, FileAccess.WRITE)
		f.store_string(JSON.stringify({"passed": passed, "failed": failed}, "\t"))
		f.close()
	get_tree().quit(0 if failed.is_empty() else 1)
