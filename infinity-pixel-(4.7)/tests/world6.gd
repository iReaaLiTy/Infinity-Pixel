extends Node

# World 6.0 — barras de vida das criaturas, pegadas do Player, inventario e
# menu fosseis e o mundo expandido (regioes, cachoeira, vulcao, navegacao).
# Os valores de jogo sao comparados com as constantes originais.
# Uso: Godot [--headless] --path . res://tests/world6.tscn [-- --report=<arquivo>]
# Sem janela, as verificacoes de layout em 1280x720/1600x900/1920x1080 viram
# SKIP (nao contam como aprovadas); a rodada com janela as executa.

const WILD := preload("res://scenes/enemies/wild_dino.tscn")
const WildDino := preload("res://scenes/enemies/wild_dino.gd")
const WorldBiomes := preload("res://scenes/world/world_biomes.gd")
const Footprints := preload("res://scenes/world/player_footprints.gd")

var passed := []
var failed := []
var skipped := []
var app
var world
var player

func check(ok: bool, label: String) -> void:
	(passed if ok else failed).append(label)
	print(("PASS: " if ok else "FAIL: ") + label)

func skip(label: String) -> void:
	skipped.append(label)
	print("SKIP: " + label)

func frames(n := 3) -> void:
	for i in n: await get_tree().process_frame

func physics(n := 3) -> void:
	for i in n: await get_tree().physics_frame

func headless() -> bool:
	return DisplayServer.get_name() == "headless"

func _ready() -> void:
	var report := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report = arg.trim_prefix("--report=")
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await frames(10)
	if has_method("menu_checks"): await call("menu_checks")
	app.start_game()
	await frames(20)
	world = app.world
	player = world.get_node("Player")
	player._invulnerable_left = INF
	DayNightManager.clock_hold = true
	await health_bar_checks()
	await footprint_checks()
	if has_method("inventory_checks"): await call("inventory_checks")
	if has_method("map_checks"): await call("map_checks")
	print("WORLD6 RESULTS: %d passed; %d failed; %d skipped" % [passed.size(), failed.size(), skipped.size()])
	if report != "":
		var f := FileAccess.open(report, FileAccess.WRITE)
		f.store_string(JSON.stringify({"passed": passed, "failed": failed, "skipped": skipped}, "\t"))
		f.close()
	DayNightManager.clock_hold = false
	app.show_menu()
	get_tree().quit(0 if failed.is_empty() else 1)

func dino_at(offset: Vector3, ally := false) -> Node:
	var d = WILD.instantiate()
	world.add_child(d)
	d.global_position = player.global_position + offset
	d.set_physics_process(false)
	if ally:
		d.domesticate()
	return d

func bar_of(d: Node):
	return d.hp_label.get_node_or_null("HealthBar")

# --- Barras de vida -------------------------------------------------------------
func health_bar_checks() -> void:
	player.global_position = Vector3(0, 0.1, -9)
	await physics(2)
	var ally = dino_at(Vector3(1.4, 0.4, 0.6), true)
	await frames(4)
	var bar = bar_of(ally)
	check(bar != null and ally.hp_label.visible and ally.hp_label.text == "ALIADO  ·  80/80", "Aliado em foco: identificacao + numero (80/80) e barra grafica")
	check(bar != null and is_equal_approx(bar.target, 1.0) and bar.faction == &"ally", "100%: barra cheia na cor jade do aliado")
	ally.take_damage(40.0)
	await frames(2)
	check(ally.hp_label.text.ends_with("40/80") and is_equal_approx(bar.target, 0.5) and bar.shown > 0.55, "Dano: numero atualiza na hora (40/80); barra desce suave (%.2f ainda)" % bar.shown)
	check(bar.ghost >= 0.99 and bar._flash > 0.5, "Dano: rastro claro do valor anterior e piscada do golpe")
	await get_tree().create_timer(1.6).timeout # tempo real (o rastro espera e desce por tempo, nao por quadro)
	check(is_equal_approx(bar.shown, 0.5) and bar.ghost < 0.9, "50%%: barra chega a metade; o rastro desce (%.2f)" % bar.ghost)
	ally.take_damage(28.0)
	for i in 60: await get_tree().process_frame
	check(ally.hp_label.text.ends_with("12/80") and bar.shown < 0.2, "HP critico: 12/80 e barra curta (%.2f)" % bar.shown)
	var hp_before: float = ally.hp
	var healed: float = ally.heal_ally(30.0)
	await frames(2)
	check(healed == 30.0 and ally.hp == hp_before + 30.0 and bar._heal > 0.5 and bar.shown < bar.target, "Cura: valor real +30 (regra intacta), brilho jade e barra subindo suave")
	for i in 90: await get_tree().process_frame
	check(is_equal_approx(bar.shown, 42.0 / 80.0), "Cura: barra chega a 42/80")
	check(WildDino.MAX_HP == 80.0, "Vida maxima das criaturas inalterada (80)")
	# Faccoes: selvagem (terracota), guardiao (ambar), invasor (azul-violeta).
	var wild = dino_at(Vector3(-2.5, 0.4, 1.0))
	wild.take_damage(10.0)
	var guard = dino_at(Vector3(3.0, 0.4, -1.5))
	guard.guardian_of = "TESTE"
	guard._update_label()
	var foe = dino_at(Vector3(-3.5, 0.4, -2.5))
	foe.add_to_group("wave_enemy")
	await frames(4)
	check(bar_of(wild) != null and bar_of(wild).faction == &"wild" and wild.hp_label.visible, "Selvagem golpeado: barra terracota visivel")
	check(bar_of(guard) != null and bar_of(guard).faction == &"guardian", "Guardiao em confronto (perto): barra ambar")
	check(bar_of(foe) != null and bar_of(foe).faction == &"invader", "Invasor: barra azul-violeta")
	var tones = preload("res://scenes/visuals/creature_health_bar.gd").TONES
	check(tones[&"ally"] != tones[&"wild"] and tones[&"wild"] != tones[&"guardian"] and tones[&"guardian"] != tones[&"invader"], "Quatro cores de faccao distintas")
	# Selvagem com vida cheia e longe: escondido (sem poluir a tela).
	var calm = dino_at(Vector3(10.0, 0.4, 6.0))
	await frames(4)
	check(not calm.hp_label.visible, "Selvagem calmo e longe: sem rotulo nem barra")
	# Onda grande: no maximo MAX_LABELS rotulos ao mesmo tempo.
	var horde := []
	for i in 16:
		var h = dino_at(Vector3(-6.0 + (i % 4) * 4.0, 0.4, -6.0 + (i / 4) * 3.0))
		h.add_to_group("wave_enemy")
		horde.append(h)
	await frames(4)
	var shown := 0
	var bars := 0
	for d in get_tree().get_nodes_in_group("wild_dino"):
		if d.hp_label.visible and not d.hp_label.get_meta("bar_only", false): shown += 1
		elif d.hp_label.visible: bars += 1
	check(shown <= app.hud.MAX_LABELS and bars <= app.hud.MAX_BARS_ONLY, "Onda grande: %d rotulos com texto (limite %d) + %d so com a barra (limite %d)" % [shown, app.hud.MAX_LABELS, bars, app.hud.MAX_BARS_ONLY])
	check(bars > 0, "Onda grande: criaturas sem espaco para o texto ainda mostram a barra")
	# Varios aliados: so o em foco e os feridos aparecem.
	for h in horde + [wild, guard, foe, calm]:
		h.queue_free()
	ally.queue_free() # o primeiro aliado sai: o foco passa a ser o do time
	await frames(2)
	var team := []
	team.append(dino_at(Vector3(1.2, 0.4, 0.8), true)) # em foco (< 3,3 m)
	team.append(dino_at(Vector3(6.0, 0.4, 2.0), true)) # sadio e longe
	team.append(dino_at(Vector3(-6.0, 0.4, 3.0), true)) # ferido
	team[2].take_damage(30.0)
	await frames(4)
	var vis := team.filter(func(a): return a.hp_label.visible)
	check(vis.size() == 2 and team[0] in vis and team[2] in vis, "Varios aliados: foco + ferido visiveis, sadio distante escondido")
	for a in team:
		a.queue_free()
	await frames(2)
	# Domesticacao: o rotulo vira ALIADO e a barra troca de cor.
	var tamed = dino_at(Vector3(-1.5, 0.4, 1.2))
	tamed.take_damage(65.0)
	await frames(3)
	tamed.domesticate()
	await frames(3)
	check(tamed.hp_label.text.begins_with("ALIADO") and bar_of(tamed) != null and bar_of(tamed).faction == &"ally", "Domesticacao: rotulo ALIADO e barra jade")
	# Noite: barras continuam legiveis (sem luz, por cima da cena).
	var night_ok: bool = (bar_of(tamed).material_override as ShaderMaterial).shader.code.contains("unshaded")
	check(night_ok, "Noite: barra sem iluminacao (legivel no escuro)")
	for a in [tamed]:
		a.queue_free()
	await frames(2)

# --- Pegadas ----------------------------------------------------------------------
func walk(dir: Vector3, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		player.global_position += dir * 6.0 * (1.0 / 60.0)
		await get_tree().physics_frame
		t += 1.0 / 60.0

func footprint_checks() -> void:
	var prints = world.get_node_or_null("PlayerFootprints")
	check(prints != null and prints.multimesh != null and prints.multimesh.instance_count == Footprints.MAX_PRINTS, "Pegadas: uma MultiMesh com %d instancias fixas (pool)" % Footprints.MAX_PRINTS)
	if prints == null:
		return
	player.set_physics_process(false)
	player.global_position = Vector3(0, 0.1, -6)
	await physics(4)
	var before: int = prints.active
	await physics(30)
	check(prints.active == before, "Parado: nenhuma pegada nova")
	var first: int = prints._next
	await walk(Vector3(1, 0, 0), 1.0)
	var made: int = (prints._next - first + Footprints.MAX_PRINTS) % Footprints.MAX_PRINTS
	check(made >= 5 and made <= 9, "Andando 6 m: %d pegadas (passada de %.2f m), nao uma por quadro" % [made, Footprints.STRIDE])
	var a: Transform3D = prints.xforms[(prints._next - 1 + Footprints.MAX_PRINTS) % Footprints.MAX_PRINTS]
	var b: Transform3D = prints.xforms[(prints._next - 2 + Footprints.MAX_PRINTS) % Footprints.MAX_PRINTS]
	check(signf(a.basis.determinant()) != signf(b.basis.determinant()) and absf(a.origin.z - b.origin.z) > 0.15, "Alterna pe esquerdo e direito (lados opostos da trilha)")
	var forward := a.basis.z.normalized()
	check(forward.x > 0.95, "Pegada virada para a direcao real do movimento (+X)")
	check(a.origin.x < player.global_position.x, "Pegada atras dos pes")
	# Superficies por regiao.
	var spots := {&"forest": Vector2(-22.0, 14.0), &"stone": Vector2(27.0, 12.0), &"water": WorldBiomes.LAKE_CENTER + Vector2(WorldBiomes.LAKE_RADII.x + 1.2, 0.0), &"volcano": Vector2(10.0, -35.0)}
	for s in spots:
		check(WorldBiomes.surface_at(spots[s]) == s, "Superficie %s reconhecida em %s" % [s, spots[s]])
	check(Footprints.TONES[&"stone"].a < Footprints.TONES[&"forest"].a and Footprints.TONES[&"water"].a > Footprints.TONES[&"forest"].a, "Pedra mais sutil (poeira); margem mais escura (umida)")
	# Desaparece aos poucos e respeita o limite.
	await walk(Vector3(0, 0, -1), 8.0)
	check(prints.active <= Footprints.MAX_PRINTS and prints.node_count() == 1, "Limite: %d pegadas ativas (max %d), nenhum no acumulado" % [prints.active, Footprints.MAX_PRINTS])
	await physics(int((Footprints.LIFE + 1.0) * 60))
	check(prints.active == 0, "Pegadas antigas somem sozinhas")
	player.set_physics_process(true)

# --- Inventario fossil ------------------------------------------------------------
func inventory_checks() -> void:
	var hud = app.hud
	var inv: Control = app.inventory_panel
	var ally = dino_at(Vector3(1.4, 0.4, 0.6), true)
	ally.hp = 47.0
	ally._update_label()
	app.toggle_inventory()
	await frames(4)
	var veil: ColorRect = inv.get_node_or_null("Veil")
	check(inv.visible and veil != null and veil.material is ShaderMaterial and (veil.material as ShaderMaterial).shader.code.contains("hint_screen_texture"), "Mochila: veu que escurece e tira a cor do jogo atras")
	check(DayNightManager.can_play() and not get_tree().paused, "Mochila aberta: o mundo continua rodando (Spec 013D)")
	check(not app.cursor_hidden, "Mochila aberta: cursor visivel")
	check(hud._inv_card.get_theme_stylebox("panel") is StyleBoxEmpty and hud._inv_card.draw.get_connections().size() > 0, "Placa arqueologica desenhada (contorno irregular, fosseis na borda)")
	var outline = preload("res://scenes/ui/fossil_ui.gd").slab_outline(Rect2(0, 0, 1000, 500))
	var off_edge := 0
	for p in outline:
		if absf(p.x) > 4.5 and absf(p.x - 1000) > 4.5 and absf(p.y) > 4.5 and absf(p.y - 500) > 4.5:
			off_edge += 1
	check(outline.size() > 40 and off_edge > 0, "Contorno da placa e irregular (nao e um retangulo): %d pontos" % outline.size())
	var icons := []
	for id in ["resources", "build", "companions"]:
		icons.append(hud._inv_tabs.has(id))
	check(icons.all(func(v): return v) and hud.TABS[0][2] == &"crystal_stone" and hud.TABS[1][2] == &"tool" and hud.TABS[2][2] == &"skull", "Abas preservadas com icones novos (pedra/cristal, ferramenta, cranio)")
	hud.show_inventory_tab("companions")
	await frames(3)
	var card: Dictionary = hud._companion_cards.get(ally, {})
	check(not card.is_empty() and card.hp.text == "47/80" and is_equal_approx(card.bar.value, 47.0) and card.state.text == "SEGUINDO", "Ficha de expedicao com dados reais (47/80, barra, SEGUINDO)")
	var labels := []
	for l: Label in card.tile.find_children("*", "Label", true, false):
		labels.append(l.text)
	check(labels.any(func(t): return t.begins_with("FICHA DE EXPEDIÇÃO")) and labels.any(func(t): return t.begins_with("Tipo:")), "Ficha mostra numero e tipo do aliado")
	var jar = hud._inv_card.find_child("ElixirJar", true, false)
	check(jar != null and hud._elixir_status != null and hud._elixir_craft != null, "Elixir de Jade integrado (frasco de especime + fabricar)")
	app.toggle_inventory()
	await frames(2)
	check(not inv.visible and app.cursor_hidden, "Fechar a mochila devolve o cursor oculto")
	ally.queue_free()
	await frames(2)

# --- Menu fossil centralizado -------------------------------------------------------
func menu_button(text: String) -> Button:
	for b in app.ui.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			return b
	return null

func centered(c: Control) -> bool:
	var view := get_viewport().get_visible_rect()
	return c != null and absf(c.get_global_rect().get_center().x - view.get_center().x) < 3.0

func menu_checks() -> void:
	app.show_menu()
	await frames(8)
	var names := ["JOGAR", "TUTORIAL", "CONTROLES", "CONFIGURAÇÕES", "CRÉDITOS", "SAIR"]
	check(names.all(func(n): return menu_button(n) != null), "Menu: as seis opcoes presentes")
	check(names.all(func(n): return centered(menu_button(n))), "Menu: TODAS as opcoes centralizadas na tela")
	var sizes := names.slice(1).map(func(n): return menu_button(n).size)
	check(sizes.all(func(s): return s.is_equal_approx(sizes[0])) and menu_button("JOGAR").size.x > sizes[0].x and menu_button("JOGAR").size.y > sizes[0].y, "Menu: botoes do mesmo tamanho; JOGAR maior (prioridade)")
	var ys := names.map(func(n): return menu_button(n).get_global_rect().position.y)
	var ordered := true
	for i in range(1, ys.size()):
		ordered = ordered and ys[i] > ys[i - 1]
	var gaps := []
	for i in range(2, names.size()):
		gaps.append(menu_button(names[i]).get_global_rect().position.y - menu_button(names[i - 1]).get_global_rect().end.y)
	check(ordered and gaps.all(func(g): return absf(g - gaps[0]) < 1.0), "Menu: ordem JOGAR, TUTORIAL, CONTROLES, CONFIGURACOES, CREDITOS, SAIR com espacamento igual")
	var mark: Control = app.ui.find_child("TitleMark", true, false)
	var face: Control = app.ui.find_child("TitleFace", true, false)
	check(centered(mark) and face != null and face.clip_children == CanvasItem.CLIP_CHILDREN_AND_DRAW and face.find_child("TitleCracks", false, false) != null, "Logotipo centralizado: pedra com rachaduras e jade recortados pelas letras")
	var stele: Control = app.ui.find_child("MenuStele", true, false)
	check(stele != null and centered(stele) and stele.draw.get_connections().size() > 0, "Opcoes dentro da placa fossil centralizada")
	var play := menu_button("JOGAR")
	check(play.get_theme_stylebox("hover").glow > 0.0 and play.get_theme_stylebox("pressed").depth < play.get_theme_stylebox("normal").depth, "Botoes: brilho jade no hover e sensacao de pressao no clique")
	app.show_settings(app._close_overlay)
	await frames(3)
	var tablet: Control = app.overlay.find_child("Tablet", true, false)
	check(tablet != null and tablet.get_theme_stylebox("panel") is StyleBoxEmpty and tablet.draw.get_connections().size() > 0, "Telas secundarias na mesma placa fossil")
	app._close_overlay()
	if headless():
		skip("Menu centralizado em 1280x720, 1600x900 e 1920x1080 (exige janela)")
		return
	for size in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		get_window().size = size
		await frames(8)
		var ok: bool = names.all(func(n): return centered(menu_button(n)) and get_viewport().get_visible_rect().encloses(menu_button(n).get_global_rect()))
		check(ok and centered(mark), "Menu %dx%d: opcoes e logotipo centralizados e dentro da tela" % [size.x, size.y])
	get_window().size = Vector2i(1280, 720)
	await frames(4)

# --- Mapa expandido (World 6.0) ----------------------------------------------------
## Empurra o Player (fisica real, move_and_slide) numa direcao por alguns segundos.
func push(dir: Vector3, seconds: float) -> void:
	player.set_physics_process(false)
	var t := 0.0
	while t < seconds:
		player.velocity = dir.normalized() * 6.0 + Vector3(0, -1, 0)
		player.move_and_slide()
		await get_tree().physics_frame
		t += 1.0 / 60.0
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)

func nav_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var map: RID = world.get_world_3d().navigation_map
	return NavigationServer3D.map_get_path(map, from, to, true)

func path_length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	return total

func map_checks() -> void:
	var map: RID = world.get_world_3d().navigation_map
	await physics(4)
	# Dimensoes: paredes nos limites novos; 1,5x a 2x a area antiga.
	var walls := [world.get_node("ArenaArt/Boundary0"), world.get_node("ArenaArt/Boundary1"), world.get_node("ArenaArt/Boundary2"), world.get_node("ArenaArt/Boundary3")]
	check(is_equal_approx(walls[0].position.x, WorldBiomes.BOUND_X) and is_equal_approx(walls[1].position.x, -WorldBiomes.BOUND_X) \
		and is_equal_approx(walls[2].position.z, WorldBiomes.BOUND_NORTH) and is_equal_approx(walls[3].position.z, WorldBiomes.BOUND_SOUTH), "Mapa: paredes nos limites do mundo expandido (x +-32, z -42..32)")
	var ratio := (WorldBiomes.BOUND_X * 2.0 * (WorldBiomes.BOUND_NORTH - WorldBiomes.BOUND_SOUTH)) / (48.0 * 52.0)
	check(ratio >= 1.5 and ratio <= 2.0, "Mapa: area %.0f m2 = %.2fx a antiga (48 x 52), dentro de 1,5x-2x" % [ratio * 48.0 * 52.0, ratio])
	# Chao fisico cobre os cantos do mundo.
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var corners_ok := true
	for c in [Vector2(-31, -41), Vector2(31, -41), Vector2(-31, 31), Vector2(31, 31)]:
		var ray := PhysicsRayQueryParameters3D.create(Vector3(c.x, 3, c.y), Vector3(c.x, -2, c.y), 1)
		corners_ok = corners_ok and not space.intersect_ray(ray).is_empty()
	check(corners_ok, "Mapa: chao com colisao nos quatro cantos do mundo expandido")
	# Quatro regioes reais (cada centro le como a propria regiao).
	var regions_ok := true
	for id in [WorldBiomes.FOREST, WorldBiomes.STONE, WorldBiomes.WATER, WorldBiomes.VOLCANO]:
		for c: Vector2 in WorldBiomes.REGION_CENTERS[id]:
			regions_ok = regions_ok and WorldBiomes.biome_at(c) == id and WorldBiomes.in_bounds(c, 1.0)
	check(regions_ok, "Regioes: FLORESTA, PEDRA, AGUA e VULCAO com centros dentro do mundo")
	var art: Node3D = world.get_node_or_null("BiomeArt")
	var parts := ["Waterfall", "WaterfallCliff", "LakeWater", "RiverWater", "Volcano", "Lava", "OuterGround", "WaterfallMist", "VolcanoSmoke", "CraterGlow"]
	check(art != null and parts.all(func(p): return art.has_node(p)), "Marcos: cachoeira (queda, paredao, nevoa), lago, rio, vulcao (lava, fumaca, brilho)")
	var particles := 0
	if art != null:
		for p: CPUParticles3D in art.find_children("*", "CPUParticles3D", true, false):
			particles += p.amount
	check(particles > 0 and particles <= 100, "Particulas do mapa limitadas (%d no total)" % particles)
	check(art != null and art.find_children("*", "Area3D", true, false).is_empty() and art.find_children("*", "CollisionObject3D", true, false).is_empty(), "Lava e cachoeira so visuais: nenhuma Area3D/corpo na arte (sem dano)")
	var collision: Node3D = world.get_node_or_null("BiomeCollision")
	check(collision != null and collision.is_in_group("navigation_source") and collision.get_child_count() > 40, "BiomeCollision: solidos das pecas altas (%d) no grupo da navmesh" % (collision.get_child_count() if collision else 0))
	# Navmesh: do Refugio ate cada regiao e marco (sem area isolada).
	var refuge := Vector3(0, 0.5, -10)
	var targets := {"floresta norte": Vector3(-20, 0.5, 27), "canion (pedra)": Vector3(27, 0.5, 15), "arco natural": Vector3(27, 0.5, 4.5),
		"margem do lago": Vector3(-14.5, 0.5, -22), "cachoeira": Vector3(-28.5, 0.5, -26.5), "borda do vulcao": Vector3(12, 0.5, -40.5),
		"pocas de lava": Vector3(20, 0.5, -36.5), "ruinas leste": Vector3(29, 0.5, 26), "ruinas oeste": Vector3(-29, 0.5, 20), "corrego": Vector3(-26, 0.5, -6)}
	var unreachable := []
	for label in targets:
		var t: Vector3 = targets[label]
		var snap := NavigationServer3D.map_get_closest_point(map, t)
		var path := nav_path(refuge, snap)
		if Vector2(snap.x, snap.z).distance_to(Vector2(t.x, t.z)) > 1.5 or path.is_empty() or path[path.size() - 1].distance_to(snap) > 0.3:
			unreachable.append(label)
	check(unreachable.is_empty(), "Navmesh: Refugio alcanca as 10 areas novas (sem area isolada) %s" % [unreachable])
	# Navmesh: agua funda e lava ficam fora (o caminho para no bloqueio); o rio
	# raso e o corrego se atravessam (caminho quase reto de uma margem a outra).
	var lava_pool: Vector2 = WorldBiomes.LAVA_POOLS[0][0]
	var to_lake := nav_path(refuge, Vector3(WorldBiomes.LAKE_CENTER.x, 0.0, WorldBiomes.LAKE_CENTER.y))
	var to_lava := nav_path(refuge, Vector3(lava_pool.x, 0.0, lava_pool.y))
	var lake_gap := 0.0
	var lava_gap0 := 0.0
	if not to_lake.is_empty():
		lake_gap = Vector2(to_lake[to_lake.size() - 1].x, to_lake[to_lake.size() - 1].z).distance_to(WorldBiomes.LAKE_CENTER)
	if not to_lava.is_empty():
		lava_gap0 = Vector2(to_lava[to_lava.size() - 1].x, to_lava[to_lava.size() - 1].z).distance_to(lava_pool)
	var crossings := []
	for spec in [[WorldBiomes.RIVER, WorldBiomes.RIVER_HALF], [WorldBiomes.STREAM, WorldBiomes.STREAM_HALF]]:
		var a: Vector2 = spec[0][0]
		var b: Vector2 = spec[0][spec[0].size() - 1]
		var mid := a.lerp(b, 0.55)
		var side := (b - a).normalized().orthogonal() * (float(spec[1]) + 1.2)
		var p0 := NavigationServer3D.map_get_closest_point(map, Vector3(mid.x + side.x, 0.0, mid.y + side.y))
		var p1 := NavigationServer3D.map_get_closest_point(map, Vector3(mid.x - side.x, 0.0, mid.y - side.y))
		crossings.append(snappedf(path_length(nav_path(p0, p1)) / maxf(p0.distance_to(p1), 0.01), 0.01))
	check(lake_gap > 3.0 and lava_gap0 > 1.5 and crossings.all(func(c): return c < 1.3), "Navmesh: lago fundo e lava fora (%.1f / %.1f m do centro); rio e corrego atravessaveis (desvio %s)" % [lake_gap, lava_gap0, crossings])
	# Ondas: as tres rotas (entradas -> Refugio) continuam abertas e diretas.
	var spawner: Node3D = world.get_node("EnemySpawnPoint")
	var waves: Node = world.get_node("WaveManager")
	var routes_ok := true
	var lengths := []
	for k in 3:
		var from: Vector3 = spawner.global_position + waves.spawn_offsets[k]
		var path := nav_path(NavigationServer3D.map_get_closest_point(map, from), Vector3(0, 0.5, -13))
		var length := path_length(path)
		lengths.append(snappedf(length, 0.1))
		routes_ok = routes_ok and not path.is_empty() and path[path.size() - 1].distance_to(Vector3(0, 0, -13)) < 2.0 and length < from.distance_to(Vector3(0, 0, -13)) * 1.35
	check(routes_ok, "Ondas: tres rotas ate o Refugio abertas e diretas (comprimentos %s m)" % [lengths])
	check(spawner.global_position.is_equal_approx(Vector3(0, 0.5, 23)) and waves.route_count == 3, "Ondas: ponto de spawn (0; 0,5; 23) e 3 rotas preservados")
	# Territorios: so os da Spec 015 (biomas NAO viraram territorios).
	var tm = world.get_node("TerritoryManager")
	var ids: Array = tm.TERRITORIES.map(func(t): return t.id)
	check(ids == [&"center", &"west", &"east"] and tm.total_count() == 3 and is_equal_approx(tm.markers[&"west"].global_position.x, -14.0) and is_equal_approx(tm.markers[&"east"].global_position.x, 13.0), "Territorios intactos: Refugio + Oeste + Leste (biomas nao sao territorios)")
	# Paredes seguram o Player; lava bloqueia sem dano; cachoeira nao prende.
	player._invulnerable_left = 0.0
	var hp0: float = player.current_hp
	player.global_position = Vector3(29.5, 0.1, 0.0)
	await push(Vector3(1, 0, 0), 1.5)
	var x_wall: float = player.global_position.x
	player.global_position = Vector3(lava_pool.x, 0.1, lava_pool.y + 4.0)
	await push(Vector3(0, 0, -1), 1.5)
	var lava_gap: float = Vector2(player.global_position.x, player.global_position.z).distance_to(lava_pool)
	check(x_wall < WorldBiomes.BOUND_X - 0.3, "Parede leste segura o Player (x = %.2f)" % x_wall)
	check(lava_gap > float(WorldBiomes.LAVA_POOLS[0][1]) and is_equal_approx(player.current_hp, hp0), "Lava: Player para na borda (%.2f m do centro) e nao perde vida" % lava_gap)
	var wf: Vector2 = WorldBiomes.WATERFALL
	player.global_position = Vector3(wf.x + 4.2, 0.1, wf.y + 1.0)
	await push(Vector3(-1, 0, 0), 1.0)
	var at_pool: Vector3 = player.global_position
	await push(Vector3(1, 0, 0.3), 1.2)
	check(player.global_position.distance_to(at_pool) > 3.0, "Cachoeira: o Player chega a beira do poco e sai livremente")
	player._invulnerable_left = INF
	# Camera: nas bordas o Player fica no quadro e a camera segue sem travar.
	var cam: Camera3D = player.get_node("StrategicCamera")
	var framed := true
	for edge in [Vector3(0, 0.1, 30.5), Vector3(-30.5, 0.1, 10), Vector3(30.5, 0.1, 10), Vector3(12, 0.1, -40.5), Vector3(-28.5, 0.1, -26.5)]:
		player.global_position = edge
		await physics(90)
		var screen := cam.unproject_position(player.global_position + Vector3(0, 1, 0))
		framed = framed and cam.is_position_in_frustum(player.global_position) and get_viewport().get_visible_rect().grow(-40).has_point(screen)
	check(framed, "Camera: Player enquadrado nas cinco bordas do mundo expandido")
	player.global_position = Vector3(0, 0.1, -10)
	await physics(4)
