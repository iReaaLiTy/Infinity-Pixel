extends Node

# Visual Overhaul 4.0: flora, rochas e ruinas (FloraArt), rig das criaturas
# (joelho, tornozelo, ponta da cauda, passo pela distancia), ajustes de
# desempenho, fonte embutida e audio. So apresentacao: cada bloco tambem confere
# que fisica, navegacao e posicoes de gameplay nao mudaram.
# Uso: Godot [--headless] --path . res://tests/visual_overhaul4.tscn [-- --report=<arquivo>]
const Layout := preload("res://tools/valley_layout.gd")
const Flora := preload("res://scenes/visuals/flora.gd")
var passed: Array[String] = []
var failed: Array[String] = []
var app
var world: Node3D

func check(ok: bool, label: String) -> void:
	(passed if ok else failed).append(label)
	print(("PASS: " if ok else "FAIL: ") + label)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _ready() -> void:
	var report := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report = arg.trim_prefix("--report=")
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await frames(20)
	await menu_checks()
	app.start_game()
	await frames(30)
	world = app.world
	scenery_checks()
	await creature_checks()
	performance_checks()
	print("OVERHAUL4 RESULTS: %d passed; %d failed" % [passed.size(), failed.size()])
	if report != "":
		var f := FileAccess.open(report, FileAccess.WRITE)
		f.store_string(JSON.stringify({"passed": passed, "failed": failed}, "\t"))
		f.close()
	app.show_menu()
	get_tree().quit(0 if failed.is_empty() else 1)

# --- Menu: fonte embutida e diorama com a flora nova ---------------------------
func menu_checks() -> void:
	var font: Font = app._display_font()
	var base: Font = font.base_font if font is FontVariation else font
	check(base is FontFile and (base as FontFile).resource_path.ends_with("LilitaOne-Regular.ttf") and FileAccess.file_exists("res://assets/fonts/OFL.txt"),
		"Titulo e botoes com fonte embutida (Lilita One, OFL) e licenca no projeto; nada depende de fonte do sistema")
	var backdrop: Node3D = app.menu_backdrop
	check(backdrop != null and backdrop.find_child("FloraArt", true, false) != null, "Diorama do menu usa a flora nova")

# --- Cenario --------------------------------------------------------------------
func _walkable(v: Vector3) -> bool:
	return absf(v.x) < 24.0 and v.z > -24.0 and v.z < 28.0

func scenery_checks() -> void:
	var flora: Node3D = world.get_node_or_null("FloraArt")
	check(flora != null and flora.find_children("*", "CollisionObject3D", true, false).is_empty() and not flora.is_in_group("navigation_source"),
		"FloraArt existe, sem corpo fisico e fora de navigation_source")
	var art: Node3D = world.get_node("ArenaArt")
	var old_visible := 0
	var trunks := []
	var rocks := []
	for n in art.get_children():
		var label := String(n.name)
		if label.begins_with("Trunk") or label.begins_with("Crown") or label.begins_with("Rock") or label.begins_with("Fern"):
			if (n as Node3D).visible:
				old_visible += 1
			if label.begins_with("Trunk"): trunks.append(n)
			if label.begins_with("Rock"): rocks.append(n)
	check(old_visible == 0 and trunks.size() == 42 and rocks.size() == 16, "Arvores/rochas antigas ocultas (os nos ficam: o solido le o transform) — 42 troncos, 16 rochas")
	# Juntar 226 nos em blocos: poucas malhas.
	var meshes: Array = flora.find_children("*", "MeshInstance3D", true, false)
	var tris := 0
	for mi: MeshInstance3D in meshes:
		tris += mi.mesh.get_faces().size() / 3
	check(meshes.size() <= 20 and tris < 75000, "Flora em %d malhas (eram 226 nos) e %d triangulos (< 75 mil)" % [meshes.size(), tris])
	var space := world.get_world_3d().direct_space_state
	var loose := 0
	var on_trail := 0
	var in_gap := 0
	var gaps := [[Vector2(-24.2, 2.0), 3.6], [Vector2(24.2, 2.0), 3.6], [Vector2(0.0, 28.2), 3.8]]
	var probe := PhysicsRayQueryParameters3D.new()
	probe.collision_mask = 1 | 8
	var trunk_seen := {}
	var rock_seen := {}
	for mi: MeshInstance3D in meshes:
		var faces := mi.mesh.get_faces()
		for i in range(0, faces.size(), 3):
			var v := mi.global_transform * faces[i]
			var p := Vector2(v.x, v.z)
			# Regra 1: entre 0,3 m e 1,9 m na area andavel, so sobre um solido.
			if _walkable(v) and v.y > 0.3 and v.y < Flora.CANOPY_FLOOR:
				probe.from = v + Vector3(0, 0.01, 0)
				probe.to = Vector3(v.x, -0.2, v.z)
				if space.intersect_ray(probe).is_empty():
					loose += 1
			# Regra 2: trilhas legiveis (so o piso antigo, rente, pode cruzar).
			if v.y > 0.06 and v.y < Flora.CANOPY_FLOOR and _walkable(v): # copas acima de 1,9 m podem cobrir a trilha
				for t in Layout.PATHS:
					if Layout.path_distance(p, t.points) < t.width * 0.5 - 0.25:
						on_trail += 1
						break
			# Regra 3: entradas das ondas abertas.
			for g in gaps:
				if p.distance_to(g[0]) < g[1] and v.y > 0.3 and v.y < Flora.CANOPY_FLOOR:
					in_gap += 1
			if v.y > 0.3 and v.y < Flora.CANOPY_FLOOR:
				for t in trunks:
					if Vector2(t.position.x, t.position.z).distance_to(p) < 0.3:
						trunk_seen[t.name] = true
			if v.y > 0.3:
				for r in rocks:
					if Vector2(r.position.x, r.position.z).distance_to(p) < maxf(r.scale.x, r.scale.z) * 0.5:
						rock_seen[r.name] = true
	check(loose == 0, "Nada solto entre 0,3 e 1,9 m na area andavel: so tronco/rocha sobre o solido (%d vertices soltos)" % loose)
	check(on_trail == 0, "Trilhas livres: nada abaixo de 1,9 m sobre a faixa das rotas, so o piso antigo rente (%d vertices)" % on_trail)
	check(in_gap == 0, "Entradas das ondas abertas: nada entre 0,3 e 1,9 m nas passagens (%d vertices)" % in_gap)
	check(trunk_seen.size() == 42 and rock_seen.size() == 16, "Cada solido tem arte no lugar: %d/42 troncos e %d/16 rochas desenhados sobre o colisor" % [trunk_seen.size(), rock_seen.size()])
	# Cristais e glifos acendem a noite (grupo night_glow, como o Refugio).
	var crystals: MeshInstance3D = flora.get_node_or_null("Crystals")
	check(crystals != null and flora.is_in_group("night_glow") and crystals.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Cristais e glifos numa malha propria, sem sombra, no grupo night_glow")
	if crystals != null:
		flora.set_night_glow(0.0)
		var day: float = crystals.material_override.emission_energy_multiplier
		flora.set_night_glow(1.0)
		var night: float = crystals.material_override.emission_energy_multiplier
		flora.set_night_glow(0.0)
		check(night > day * 3.0, "Cristais discretos de dia (%.2f) e acesos a noite (%.2f)" % [day, night])
	# Arvore coletavel: mesma familia (copa de lobos numa malha so).
	var tree: Node = world.get_node("Collectables").get_child(0)
	var parts := tree.find_children("*", "MeshInstance3D", true, false)
	check(parts.size() >= 2 and parts.any(func(m): return m.mesh == Flora._harvest), "Arvore coletavel com a copa nova de lobos (tons quentes, 1 malha)")

# --- Criaturas: rig e passo -----------------------------------------------------
func creature_checks() -> void:
	var dino: CharacterBody3D = load("res://scenes/enemies/wild_dino.tscn").instantiate()
	world.add_child(dino)
	dino.global_position = Vector3(0.0, 0.5, 0.0)
	dino.set_physics_process(false) # IA fora: so o visual responde ao deslocamento real
	var v: Node3D = dino.get_node("Visual")
	check(v.has_node("LegL/KneeL/AnkleL/Foot-1") and v.has_node("LegR/KneeR/AnkleR/Claw1") and v.has_node("Tail/TailTip"),
		"Rig: coxa no quadril, canela no joelho, pe e garras no tornozelo, ponta da cauda com pivo proprio")
	await frames(10)
	var knee: Node3D = v.get_node("LegL/KneeL")
	check(absf(knee.rotation.x) < 0.01 and absf(v.get_node("LegL").rotation.x) < 0.01, "Parado: pernas e joelho em repouso (sem andar no lugar)")
	# Anda 3 m/s em linha reta: o joelho dobra no balanco e a fase do passo
	# acompanha a distancia (pe nao desliza).
	var bent := 0.0
	var gait0: float = v._gait
	var turns := 0.0
	var last: float = gait0
	var dist := 0.0
	var tip_diff := 0.0
	for i in 90:
		var before := dino.global_position
		dino.velocity = Vector3(3.0, 0.0, 0.0)
		dino.move_and_slide()
		await get_tree().physics_frame
		await get_tree().process_frame
		dist += Vector2(dino.global_position.x - before.x, dino.global_position.z - before.z).length()
		bent = minf(bent, knee.rotation.x)
		turns += fposmod(v._gait - last, TAU)
		last = v._gait
		tip_diff = maxf(tip_diff, absf(v.get_node("Tail/TailTip").rotation.y))
	var amp := 0.42 + 0.12 * clampf((3.0 - 2.0) / 3.0, 0.0, 1.0)
	var expected: float = dist / v._stride(amp) * TAU
	check(bent < -0.3, "Andando: o joelho dobra na perna em balanco (%.2f rad)" % bent)
	check(dist > 1.0 and absf(turns - expected) / expected < 0.2, "Passo pela distancia: fase %.1f rad para %.2f m (esperado %.1f)" % [turns, dist, expected])
	check(tip_diff > 0.02, "Ponta da cauda balanca com atraso proprio")
	dino.velocity = Vector3.ZERO
	dino.move_and_slide()
	await frames(4)
	await get_tree().process_frame
	check(absf(knee.rotation.x) < 0.01, "Parou: joelho volta ao repouso no mesmo instante")
	# Domesticado: pernas/rig continuam; a IA nao foi tocada (velocidade base igual).
	check(dino.BASE_SPEED == 4.0 and dino.get_node("CollisionShape3D").shape != null, "IA e colisao intocadas (velocidade base 4 m/s, colisor original)")
	dino.queue_free()

# --- Desempenho -----------------------------------------------------------------
func performance_checks() -> void:
	var light: DirectionalLight3D = world.get_node("DirectionalLight3D")
	check(light.shadow_enabled and light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS and light.directional_shadow_max_distance <= 50.0,
		"Sombra direcional em 2 fatias ate %.0f m (a camera ve ~36 m): metade das passadas de sombra" % light.directional_shadow_max_distance)
	check(not ProjectSettings.get_setting("application/run/disable_stdout", false), "Log de eventos raros continua no console (so o log por golpe virou --verbose)")
