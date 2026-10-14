extends Node

# Design Overhaul 5.0 — contratos visuais novos (torres, materiais, menu, HUD,
# icones, cursor e malhas geradas). Os valores de jogo (dano, alcance,
# cadencia, custos, colisor) sao comparados com as constantes ORIGINAIS: a
# reforma e so de apresentacao.
# Uso: Godot [--headless] --path . res://tests/design5.tscn [-- --report=<arquivo>]
# Sem janela, as verificacoes de layout em 1280x720 / 1600x900 / 1920x1080 nao
# rodam (o modo sem janela nao redimensiona a viewport): aparecem como SKIP e
# NAO contam como aprovadas; a rodada com janela as executa.

const DefenseTower := preload("res://scenes/world/defense_tower.gd")
const TowerForge := preload("res://scenes/visuals/tower_forge.gd")
const SurfaceFinish := preload("res://scenes/visuals/surface_finish.gd")
const CarvedStyle := preload("res://scenes/ui/carved_style.gd")
const UiArt := preload("res://scenes/ui/ui_art.gd")
const WILD := preload("res://scenes/enemies/wild_dino.tscn")
# Tabela de jogo ANTES da reforma (Spec 013B) — nao pode mudar.
const LEVELS_BEFORE := [
	{"cost": 30, "damage": 10.0, "interval": 1.0, "range": 8.0},
	{"cost": 30, "damage": 15.0, "interval": 0.85, "range": 9.0},
	{"cost": 45, "damage": 20.0, "interval": 0.70, "range": 10.0},
]

var passed := []
var failed := []
var skipped := []
var app
var world

func check(ok: bool, label: String) -> void:
	(passed if ok else failed).append(label)
	print(("PASS: " if ok else "FAIL: ") + label)

func skip(label: String) -> void:
	skipped.append(label)
	print("SKIP: " + label)

func frames(n := 3) -> void:
	for i in n: await get_tree().process_frame

func tris(mesh: Mesh) -> int:
	var count := 0
	for s in mesh.get_surface_count():
		count += mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX].size() / 3
	return count

func _ready() -> void:
	var report := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report = arg.trim_prefix("--report=")
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await frames(10)
	forge_checks()
	await menu_checks()
	app.start_game()
	await frames(20)
	world = app.world
	await tower_checks()
	await material_checks()
	await hud_checks()
	await cursor_checks()
	await layout_checks()
	print("DESIGN5 RESULTS: %d passed; %d failed; %d skipped" % [passed.size(), failed.size(), skipped.size()])
	if report != "":
		var f := FileAccess.open(report, FileAccess.WRITE)
		f.store_string(JSON.stringify({"passed": passed, "failed": failed, "skipped": skipped}, "\t"))
		f.close()
	app.show_menu()
	get_tree().quit(0 if failed.is_empty() else 1)

# --- Malhas geradas (TowerForge) ----------------------------------------------
func forge_checks() -> void:
	var tops := []
	for level in [1, 2, 3]:
		var p: Dictionary = TowerForge.parts(level)
		var meshes := [p.body, p.glow, p.head, p.crystal]
		check(meshes.all(func(m): return m is ArrayMesh and m.get_surface_count() == 1 and tris(m) > 0), "L%d: corpo, runas, mecanismo e cristal gerados (1 superficie cada)" % level)
		var body_tris := tris(p.body)
		check(body_tris > 900 and body_tris < 9000, "L%d: geometria trabalhada e dentro do orcamento (%d triangulos no corpo)" % [level, body_tris])
		# O colisor tem 0,8 m e o Player 0,4 m de raio: o corpo dele nunca passa de
		# 0,8 m do eixo. Entre 0,32 e 2 m (altura do corpo) nada sai de 1,02 m; rente
		# ao chao (< 0,32 m) as pedras de fundacao ficam sobre o plinto do ponto de
		# defesa (1,24 m), como as pedrinhas que ele ja tinha.
		var outside := 0
		var max_mid := 0.0
		var max_low := 0.0
		var lowest := INF
		var highest := -INF
		for v in p.body.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			lowest = minf(lowest, v.y)
			highest = maxf(highest, v.y)
			var r := Vector2(v.x, v.z).length()
			if v.y >= 0.32 and v.y < 2.0:
				max_mid = maxf(max_mid, r)
				if r > 1.02: outside += 1
			elif v.y < 0.32:
				max_low = maxf(max_low, r)
				if r > 1.22: outside += 1
		check(outside == 0 and lowest > -0.06, "L%d: corpo dentro de %.2f m (0,32-2 m) e base dentro de %.2f m (< 0,32 m); nada enterrado" % [level, max_mid, max_low])
		tops.append(p.head_y + p.crystal_pos.y)
		check(TowerForge.parts(level).body == p.body, "L%d: malhas cacheadas (mesmo recurso para todas as torres)" % level)
	check(tops[0] < tops[1] and tops[1] < tops[2], "Silhueta cresce a cada nivel (cristal a %.2f / %.2f / %.2f m)" % tops)
	check(TowerForge.parts(3).orbit and TowerForge.parts(3).orbit_mesh is ArrayMesh and not TowerForge.parts(1).orbit, "So o Bastiao (L3) tem lascas orbitando o cristal")

# --- Torres no jogo -----------------------------------------------------------
func tower_checks() -> void:
	check(DefenseTower.LEVELS == LEVELS_BEFORE, "Tabela de dano, alcance, cadencia e custo identica a de antes da reforma")
	var slot: Node3D = world.get_node("DefenseSlots/SlotRuinMeadow")
	var tower = slot.build()
	await frames(3)
	var shape: CylinderShape3D = tower.get_child(0).shape
	var obstacle: NavigationObstacle3D = tower.get_children().filter(func(n): return n is NavigationObstacle3D)[0]
	check(is_equal_approx(shape.radius, 0.8) and is_equal_approx(shape.height, 2.4) and is_equal_approx(obstacle.radius, 0.8) and is_equal_approx(obstacle.height, 2.4) and tower.collision_layer == 1 << 3, "Colisor e obstaculo da torre iguais (0,8 m x 2,4 m, camada 4)")
	for level in [1, 2, 3]:
		if level > 1:
			var old_visual: Node3D = tower._visual
			var old_body: Mesh = tower.get_node("TowerVisual/Body").mesh if tower.has_node("TowerVisual/Body") else null
			tower.upgrade()
			await frames(2)
			check(not is_instance_valid(old_visual) or old_visual.is_queued_for_deletion() or old_visual.get_parent() != tower, "L%d: modelo anterior removido na melhoria" % level)
			check(tower._visual.get_node("Body").mesh != old_body, "L%d: troca visual apos a melhoria (malha nova)" % level)
		var p: Dictionary = TowerForge.parts(level)
		var v: Node3D = tower._visual
		check(v.get_node("Body").mesh == p.body and v.get_node("Head/Rig/Mechanism").mesh == p.head and tower._crystal.mesh == p.crystal, "L%d: modelo correto do nivel (corpo, mecanismo e cristal)" % level)
		check(is_equal_approx(tower._head.position.y, TowerForge.HEAD_Y[level - 1]) and tower.stats() == LEVELS_BEFORE[level - 1], "L%d: mecanismo na plataforma (%.2f m) e estatisticas do nivel inalteradas" % [level, tower._head.position.y])
		check(tower._glow_mats.size() == 2 and tower._crystal.material_override == tower._glow_mats[0], "L%d: cristal e runas com o brilho noturno desta torre" % level)
		check((tower._orbit != null) == (level == 3), "L%d: lascas orbitando so no nivel 3" % level)
	# Mecanismo aponta para o alvo e a lasca sai do cristal no disparo real.
	DayNightManager.gameplay_enabled = true
	var foe = WILD.instantiate()
	world.add_child(foe)
	foe.add_to_group("wave_enemy")
	foe.global_position = tower.global_position + Vector3(5.0, 0.5, 0.0)
	foe.set_physics_process(false)
	tower._fire(foe)
	var local: Vector3 = tower._visual.to_local(foe.global_position)
	check(absf(wrapf(tower._head.rotation.y - atan2(local.x, local.z), -PI, PI)) < 0.01, "Disparo: mecanismo voltado para o alvo no mesmo quadro")
	var bolt: MeshInstance3D = null
	for n in slot.get_children():
		if n is MeshInstance3D and n.mesh == preload("res://scenes/visuals/combat_fx.gd").shard_mesh() and n.material_override is StandardMaterial3D and n.material_override.emission_enabled:
			bolt = n
	check(bolt != null and bolt.global_position.distance_to(tower._crystal.global_position) < 0.05, "Disparo: a lasca nasce no cristal do mecanismo (%.3f m)" % (bolt.global_position.distance_to(tower._crystal.global_position) if bolt != null else -1.0))
	check(tower._recoil > 0.9 and tower._flash > 0.9, "Disparo: recuo e clarao do cristal no instante do tiro (so visual)")
	var hp0: float = foe.hp
	for i in 20: await get_tree().physics_frame
	check(foe.hp == hp0 - LEVELS_BEFORE[2].damage or foe.hp < hp0, "Disparo: dano real aplicado na chegada (%.0f -> %.0f)" % [hp0, foe.hp])
	foe.queue_free()
	tower.target = null
	DayNightManager.gameplay_enabled = false
	# Brilho noturno: o cristal sobe sem estourar (energia limitada, jade profundo).
	tower.set_night_glow(1.0)
	var night: float = tower._glow_mats[0].emission_energy_multiplier
	tower.set_night_glow(0.0)
	var day: float = tower._glow_mats[0].emission_energy_multiplier
	var emission: Color = tower._glow_mats[0].emission
	check(night > day + 1.0 and night <= 2.0 and emission.get_luminance() < 0.5, "Cristal a noite mais forte (%.2f) que de dia (%.2f), com emissao contida (luminancia %.2f)" % [night, day, emission.get_luminance()])

# --- Materiais ------------------------------------------------------------------
func material_checks() -> void:
	await frames(2)
	var toon := TowerForge.material()
	check(toon.detail_enabled and toon.detail_albedo == SurfaceFinish.grain() and toon.uv2_world_triplanar and toon.has_meta("finished"), "Material das torres com o grao de superficie (triplanar no mundo)")
	var grain := SurfaceFinish.grain()
	check(grain.get_width() == SurfaceFinish.GRAIN_SIZE and grain.get_height() == SurfaceFinish.GRAIN_SIZE, "Grao procedural de %d px (sem textura externa)" % SurfaceFinish.GRAIN_SIZE)
	var finished := 0
	var unique := {}
	var actors_touched := 0
	for mi: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
		var m := mi.material_override
		if m != null and m.has_meta("finished"):
			finished += 1
			unique[m] = true
	for actor in get_tree().get_nodes_in_group("wild_dino") + get_tree().get_nodes_in_group("player"):
		for mi: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
			if mi.material_override != null and mi.material_override.has_meta("finished"):
				actors_touched += 1
	check(finished > 20 and unique.size() < finished, "Arte do mundo com acabamento: %d malhas, %d materiais compartilhados" % [finished, unique.size()])
	check(actors_touched == 0, "Criaturas e Player com os materiais originais (identidade preservada)")
	var glow_ok := true
	for mi: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
		var s := mi.material_override as StandardMaterial3D
		if s != null and s.emission_enabled and s.has_meta("finished"):
			glow_ok = false
	check(glow_ok, "Materiais com emissao (cristais, runas) ficam fora do acabamento")

# --- Menu -----------------------------------------------------------------------
func button(text: String) -> Button:
	for b in app.ui.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			return b
	return null

func menu_checks() -> void:
	app.show_menu()
	app.show_menu()
	await frames(3)
	var backdrops: Array = app.get_children().filter(func(n): return n.name.begins_with("MenuBackdrop") and not n.is_queued_for_deletion())
	check(backdrops.size() == 1, "Menu sem duplicacao de fundos (show_menu repetido)")
	var b: Node3D = app.menu_backdrop
	var towers := b.find_children("TowerShowcase*", "Node3D", false, false)
	check(towers.size() == 2 and towers.all(func(t): return t.find_children("*", "CollisionObject3D", true, false).is_empty()) and b.find_children("*", "CharacterBody3D", true, false).is_empty() and b.find_children("*", "NavigationRegion3D", true, false).is_empty(), "Diorama com as torres novas (so malhas, sem corpo fisico), sem criaturas com fisica nem navegacao")
	var actors := b.find_children("*", "Node3D", false, false).filter(func(n): return n.get("showcase") == "rest")
	check(actors.size() >= 1, "Dinossauro em idle no diorama")
	var names := ["JOGAR", "TUTORIAL", "CONTROLES", "CONFIGURAÇÕES", "CRÉDITOS", "SAIR"]
	check(names.all(func(n): return button(n) != null and button(n).has_meta("icon") and button(n).get_theme_stylebox("normal") is CarvedStyle), "Seis botoes reais, cada um com icone proprio e placa talhada")
	check(button("JOGAR").get_meta("tier") == 0 and names.slice(1).all(func(n): return button(n).get_meta("tier") == 1), "Hierarquia (World 6.0): JOGAR em destaque; demais iguais")
	var play := button("JOGAR")
	check(play.get_theme_stylebox("hover").glow > 0.0 and play.get_theme_stylebox("pressed").depth < play.get_theme_stylebox("normal").depth and not play.get_theme_stylebox("focus").draw_center, "Botoes: brilho no hover, afunda no clique, contorno de foco")
	var fired := [false]
	var probe := Button.new()
	probe.text = "PROBE"
	app._stone_button(app.ui, "PROBE", &"play", 2, func(): fired[0] = true).pressed.emit()
	check(fired[0], "Botao do menu executa a acao ligada (sem botoes decorativos)")
	for n in app.ui.find_children("*", "Button", true, false):
		if n.text == "PROBE": n.queue_free()
	probe.free()
	var mark: Control = app.ui.find_child("TitleMark", true, false)
	var sub: Label = app.ui.find_child("Subtitle", true, false)
	check(mark != null and mark.get_meta("text") == "JADEFALL" and sub != null and sub.text == "GUARDIÕES DO REFÚGIO", "Logotipo JADEFALL no lintel e subtitulo na faixa")
	# Icones novos desenham sem erro (o runner reprova qualquer SCRIPT ERROR).
	var shelf := HBoxContainer.new()
	app.ui.add_child(shelf)
	for kind in [&"damage", &"range", &"cadence", &"elixir", &"tower", &"defense", &"wood", &"stone", &"territory", &"play", &"tutorial", &"controls", &"settings", &"credits", &"quit"]:
		shelf.add_child(UiArt.icon_control(kind, 24))
	await frames(3)
	check(shelf.get_child_count() == 15, "Icones da interface (inclui dano, alcance, cadencia e elixir) desenhados")
	shelf.queue_free()

# --- HUD ------------------------------------------------------------------------
func hud_checks() -> void:
	var hud = app.hud
	check(hud.get_node("HealthPanel").get_theme_stylebox("panel") is CarvedStyle and app.player_text.text == "JOGADOR  100 / 100", "HUD em pedra talhada; textos dos vitais iguais")
	check(is_instance_valid(hud._player_medal) and is_instance_valid(hud._refuge_medal) and is_instance_valid(hud._cycle_dial), "Medalhoes do explorador e do Refugio e arco do ciclo presentes")
	# Dano no jogador: rastro na barra e medalhao piscando (so apresentacao).
	var player = world.get_node("Player")
	player._invulnerable_left = 0.0
	player.take_damage(20.0)
	await frames(2)
	check(app.player_bar.value == 80.0 and app.player_bar.get_meta("ghost", 0.0) > 0.79 and hud._player_medal.get_meta("flash", 0.0) > 0.0, "Dano: barra 80, rastro do dano e medalhao piscando")
	for i in 90: await get_tree().process_frame
	check(app.player_bar.get_meta("ghost", 1.0) < 0.82, "Rastro do dano desce ate o valor atual")
	# Refugio: dano faz o medalhao piscar; abaixo de 35% fica critico.
	var base = world.get_node("Territory")
	base.health = int(base.max_health * 0.3)
	await frames(3)
	check(hud._refuge_medal.get_meta("critical", false) and hud._refuge_medal.get_meta("flash", 0.0) >= 0.0, "Refugio em estado critico visivel (anel em brasa)")
	base.health = base.max_health
	# Ficha do Elixir: escondida no Dia 1, aparece no Dia 2 com o estoque real.
	await frames(2)
	check(not hud._elixir_chip.visible, "Ficha do Elixir escondida antes do Dia 2")
	DayNightManager.day_number = 2
	world.get_node("JadeElixir").stored = 1
	await frames(2)
	check(hud._elixir_chip.visible and hud._elixir_chip_text.text == "1/1", "Ficha do Elixir no Dia 2 mostra o estoque real (1/1)")
	world.get_node("JadeElixir").stored = 0
	DayNightManager.day_number = 1
	# Painel da torre: dados reais da tabela, proximo nivel e pontos faltando.
	var slot: Node3D = world.get_node("DefenseSlots/SlotRuinMeadow")
	player.global_position = slot.global_position + Vector3(1.6, 0.1, 1.2)
	var tower = slot.tower
	while tower.level > 1: # volta a um estado conhecido para conferir o painel
		tower.level -= 1
	tower._apply_level_visual()
	await frames(4)
	check(app.build_panel.visible and app.build_title.text == "TORRE DE DEFESA  ·  NÍVEL 1", "Painel da torre aparece perto dela")
	check(hud._tower_stat_labels[&"damage"].text == "10" and hud._tower_stat_labels[&"range"].text == "8 m" and hud._tower_stat_labels[&"cadence"].text == "1,0 s", "Painel mostra dano 10, alcance 8 m e cadencia 1,0 s (tabela real)")
	check(hud._tower_next.text.contains("Dano 15") and hud._tower_next.text.contains("9 m") and hud._tower_next.text.contains("0,85 s"), "Previa do proximo nivel com os valores reais do L2")
	var economy = world.get_node("DefenseEconomy")
	economy.points = 12
	economy.points_changed.emit(12, 0)
	await frames(3)
	check(app.build_note.text == "Pontos insuficientes" and hud._tower_missing.text == "Faltam 18 Pontos de Defesa" and hud._tower_missing.visible, "Recursos faltantes: 'Faltam 18 Pontos de Defesa'")
	player.global_position = Vector3(0, 0.1, -10)
	await frames(3)
	# Barra compacta sob o rotulo das criaturas.
	var ally = WILD.instantiate()
	world.add_child(ally)
	ally.global_position = player.global_position + Vector3(1.5, 0.4, 0.5)
	ally.set_physics_process(false)
	ally.domesticate()
	ally.hp = 40.0
	ally._update_label()
	await frames(4)
	# World 6.0: a barra virou grafica (shader): HealthBar dentro do rotulo.
	var bar = ally.hp_label.get_node_or_null("HealthBar")
	check(bar != null and is_equal_approx(bar.target, 0.5) and ally.hp_label.text.begins_with("ALIADO"), "Aliado: barra de vida compacta (40/80) sob o rotulo; texto igual")
	ally.queue_free()

# --- Cursor (sem regressao) -------------------------------------------------------
func cursor_checks() -> void:
	await frames(2)
	check(app.cursor_hidden, "Cursor oculto no jogo")
	app.toggle_inventory()
	await frames(2)
	check(not app.cursor_hidden, "Cursor visivel com a mochila aberta")
	app.toggle_inventory()
	await frames(2)
	app.pause_game()
	await frames(2)
	check(not app.cursor_hidden, "Cursor visivel na pausa")
	app.resume_game()
	await frames(2)
	check(app.cursor_hidden, "Cursor oculto ao voltar ao jogo")

# --- Layout nas tres resolucoes ---------------------------------------------------
func on_screen(c: Control) -> bool:
	return c != null and c.is_visible_in_tree() and get_viewport().get_visible_rect().grow(0.5).encloses(c.get_global_rect())

func layout_checks() -> void:
	if DisplayServer.get_name() == "headless":
		for size in ["1280x720", "1600x900", "1920x1080"]:
			skip("Layout da HUD e do menu em %s (exige janela)" % size)
		return
	var hud = app.hud
	var slot: Node3D = world.get_node("DefenseSlots/SlotRuinMeadow")
	var player = world.get_node("Player")
	world.get_node("DefenseEconomy").add_points(100)
	for size in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		get_window().size = size
		player.global_position = slot.global_position + Vector3(1.6, 0.1, 1.2)
		await frames(8)
		var panels := ["HealthPanel", "PhasePanel", "PointsPanel", "ContextPanel", "DefensePanel"].map(func(n): return hud.get_node(n))
		check(panels.all(func(p): return on_screen(p)), "%dx%d: vitais, ciclo, recursos, contexto e painel da torre dentro da tela" % [size.x, size.y])
		var overlap := false
		for i in panels.size():
			for j in range(i + 1, panels.size()):
				if panels[i].get_global_rect().intersects(panels[j].get_global_rect()):
					overlap = true
		check(not overlap, "%dx%d: paineis da HUD sem sobreposicao" % [size.x, size.y])
		var labels_ok := true
		for l: Label in hud.find_children("*", "Label", true, false):
			if l.is_visible_in_tree() and l.text != "" and l.get_minimum_size().x > l.size.x + 1.0:
				labels_ok = false
		check(labels_ok, "%dx%d: nenhum texto da HUD cortado" % [size.x, size.y])
	player.global_position = Vector3(0, 0.1, -10)
	app.show_menu()
	for size in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(960, 540)]:
		get_window().size = size
		await frames(8)
		var ok := ["JOGAR", "TUTORIAL", "CONTROLES", "CONFIGURAÇÕES", "CRÉDITOS", "SAIR"].all(func(n): return on_screen(button(n)))
		var logo: Control = app.ui.find_child("TitleMark", true, false)
		check(ok and on_screen(logo), "Menu %dx%d: logotipo e todos os botoes visiveis" % [size.x, size.y])
	get_window().size = Vector2i(1280, 720)
	app.start_game()
	await frames(10)
	world = app.world
