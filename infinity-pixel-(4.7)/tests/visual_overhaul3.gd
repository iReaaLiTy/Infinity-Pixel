extends Node

# Visual Overhaul 3.0: menu, telas, modelos e animacoes, ornamentos por faccao,
# rotulos contextuais, aneis de alcance, cenario fossil e efeitos. So
# apresentacao: cada checagem tambem confere que a regra de jogo nao mudou.
# Uso: Godot [--headless] --path . res://tests/visual_overhaul3.tscn [-- --report=<arquivo>]
const Forge := preload("res://scenes/visuals/creature_forge.gd")
const WildDino := preload("res://scenes/enemies/wild_dino.gd")
var passed: Array[String] = []
var failed: Array[String] = []
var app

func check(ok: bool, label: String) -> void:
	(passed if ok else failed).append(label)
	print(("PASS: " if ok else "FAIL: ") + label)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func button(text: String) -> Button:
	for b in app.ui.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			return b
	return null

func _ready() -> void:
	var report := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report = arg.trim_prefix("--report=")
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await frames(30)
	await menu_checks()
	await world_checks()
	print("OVERHAUL3 RESULTS: %d passed; %d failed" % [passed.size(), failed.size()])
	if report != "":
		var f := FileAccess.open(report, FileAccess.WRITE)
		f.store_string(JSON.stringify({"passed": passed, "failed": failed}, "\t"))
		f.close()
	app.show_menu()
	get_tree().quit(0 if failed.is_empty() else 1)

# --- Menu e telas --------------------------------------------------------------
func menu_checks() -> void:
	var mark: Control = app.ui.find_child("TitleMark", true, false)
	var sub: Label = app.ui.find_child("Subtitle", true, false)
	check(app.screen == "menu" and mark != null and mark.get_meta("text") == "JADEFALL" and sub != null and sub.text == "GUARDIÕES DO REFÚGIO", "Marca JADEFALL e subtitulo GUARDIÕES DO REFÚGIO")
	var names := ["JOGAR", "TUTORIAL", "CONTROLES", "CONFIGURAÇÕES", "CRÉDITOS", "SAIR"]
	var all := names.all(func(n): return button(n) != null)
	check(all and button("CONTINUAR") == null, "Botoes reais presentes; sem CONTINUAR (nao ha save)")
	# World 6.0 (contrato alterado a pedido): opcoes centralizadas, todas do
	# mesmo tamanho; so JOGAR e maior (prioridade visual).
	var widths := []
	for n in names.slice(1):
		widths.append(button(n).size)
	check(widths.all(func(s): return s.is_equal_approx(widths[0])) and button("JOGAR").size.x > widths[0].x, "Hierarquia do menu: JOGAR maior; demais opcoes do mesmo tamanho")
	check(names.all(func(n): return button(n).has_meta("icon")), "Cada botao do menu tem icone proprio")
	var backdrop: Node3D = app.menu_backdrop
	var actors: Array = backdrop.find_children("*", "Node3D", false, false).filter(func(n): return n.get("showcase") != null and n.showcase != "")
	check(actors.size() >= 2 and backdrop.find_children("*", "CharacterBody3D", true, false).is_empty() and backdrop.find_children("*", "NavigationRegion3D", true, false).is_empty(), "Diorama com dinossauros em vitrine e sem gameplay (sem corpos nem navegacao)")
	app.show_menu()
	app.show_menu()
	await frames(3)
	var backdrops: Array = app.get_children().filter(func(n): return n.name.begins_with("MenuBackdrop") and not n.is_queued_for_deletion())
	check(backdrops.size() == 1, "show_menu() repetido mantem um unico fundo (bug corrigido)")
	app.show_settings(app._close_overlay)
	await frames(2)
	check(is_instance_valid(app.overlay) and app.overlay.find_child("Tablet", true, false) != null, "Configuracoes na tabua de pedra do 3.0")
	app._close_overlay()

# --- Mundo -------------------------------------------------------------------
func world_checks() -> void:
	app.start_game()
	await frames(20)
	var world: Node3D = app.world
	var player: CharacterBody3D = world.get_node("Player")
	player._invulnerable_left = INF
	# Cenario fossil: baixo, sem colisao.
	var fossils: Node3D = world.get_node_or_null("FossilArt")
	var low := true
	if fossils != null:
		var arrays: Array = (fossils.get_node("Fossils") as MeshInstance3D).mesh.surface_get_arrays(0)
		for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			low = low and v.y <= 0.3
	check(fossils != null and low and fossils.find_children("*", "CollisionObject3D", true, false).is_empty(), "FossilArt: nada acima de 0,3 m e sem colisao")
	check(fossils != null and fossils.has_node("RefugeSkulls"), "Cranios nos estandartes do Refugio")
	# Modelo do dinossauro.
	var wild: Array = world.get_node("EncounterSpawner").encounters
	var dino: Node3D = wild[0]
	var v: Node3D = dino.get_node("Visual")
	var parts := ["Body", "Belly", "Neck", "Head", "Jaw", "Tail", "Crest", "Collar", "Eye1", "Eye-1", "LegL", "LegR"]
	check(parts.all(func(p): return v.has_node(p)) and v.has_node("Jaw/TeethLow") and not v.get_node("Collar").visible, "Modelo novo com as partes nomeadas (paleta e testes)")
	check(v.get_node("Tail").position.is_equal_approx(Forge.TAIL_PIVOT) and (v.get_node("Body") as MeshInstance3D).mesh is ArrayMesh, "Cauda com pivo na raiz; corpo em malha esculpida")
	# Rig: a cabeca anima sem mover o corpo.
	dino.set_physics_process(false)
	var body_pos := dino.global_position
	var head0: Transform3D = v.get_node("Head").transform
	await frames(45)
	check(not v.get_node("Head").transform.is_equal_approx(head0) and dino.global_position.is_equal_approx(body_pos), "Cabeca/pescoco animam sem mover o corpo fisico")
	# Ornamentos por faccao.
	var guardians: Array = world.get_node("TerritoryManager").guardians.values().filter(func(d): return is_instance_valid(d))
	check(guardians.size() >= 1 and guardians.all(func(g): return g.get_node("Visual").has_node("GuardMask") and g.get_node("Visual").has_node("TotemBeads")), "Guardioes: mascara de osso e colar (silhueta propria)")
	var g0: Node3D = guardians[0]
	g0.domesticate()
	await frames(2)
	var gv: Node3D = g0.get_node("Visual")
	check(not gv.has_node("GuardMask") and gv.get_node("Collar").visible and g0.get_meta("ally_origin", "").begins_with("Ex-guardião"), "Guardiao domesticado: perde a mascara, ganha coleira; origem registrada")
	check(is_equal_approx(g0.hp, WildDino.MAX_HP) and g0.ally_state == WildDino.AllyState.FOLLOWING, "Domesticar continua com vida cheia e SEGUINDO (regra intacta)")
	# Rotulos contextuais: tres aliados juntos -> so o mais perto mostra o rotulo.
	var extra := []
	for i in 2:
		var d: Node3D = load("res://scenes/enemies/wild_dino.tscn").instantiate()
		world.add_child(d)
		d.domesticate()
		d.set_physics_process(false)
		extra.append(d)
	g0.set_physics_process(false)
	player.set_physics_process(false)
	player.global_position = Vector3(0, 0.1, -10)
	g0.global_position = Vector3(1.5, 0.5, -10)
	extra[0].global_position = Vector3(-1.6, 0.5, -10.4)
	extra[1].global_position = Vector3(0.2, 0.5, -8.0)
	await frames(6)
	var shown := [g0, extra[0], extra[1]].filter(func(a): return a.hp_label.visible)
	check(shown.size() == 1 and shown[0] == g0, "Aliados juntos: so o aliado em foco mostra o rotulo (%d visiveis)" % shown.size())
	extra[0].hp = 40.0
	await frames(3)
	check(extra[0].hp_label.visible and extra[0].hp_label.pixel_size < g0.hp_label.pixel_size, "Aliado ferido perto aparece, menor que o em foco")
	check(g0.hp_label.text.begins_with("ALIADO"), "Texto do rotulo inalterado (so visibilidade/tamanho)")
	# Dica com tecla desenhada.
	await frames(2)
	var key: Control = app.hud._hint_key
	check(app.hint.text.contains("F alterna") and key.visible and key.get_meta("text") == "F", "Dica perto do aliado com a tecla F desenhada")
	# Anel da torre: escondido de longe, discreto de perto.
	var slot = world.get_node("DefenseSlots/SlotRuinMeadow")
	var tower = slot.build()
	player.global_position = slot.global_position + Vector3(0, 0.1, 30.0)
	await frames(40)
	check(not tower.range_ring.visible and tower.ring_alpha_target() == 0.0, "Anel de alcance escondido longe da torre")
	player.global_position = slot.global_position + Vector3(4.0, 0.1, 4.0)
	await frames(40)
	check(tower.range_ring.visible and tower.range_ring.radius == tower.stats().range, "Anel visivel perto, com o raio real da torre")
	# Noite: invasor com espinhos e vinheta curta.
	DayNightManager.start_night()
	await frames(4)
	check(app.hud.has_node("NightVignette"), "Inicio da noite: vinheta violeta curta")
	await frames(60 * 4)
	var foes := get_tree().get_nodes_in_group("wave_enemy")
	check(foes.size() > 0 and foes[0].get_node("Visual").has_node("SpineBack") and (foes[0].get_node("Visual/SpineBack") as MeshInstance3D).material_override.resource_name.begins_with("night_"), "Invasor: espinhos dorsais na paleta noturna")
	await frames(60 * 2)
	check(not app.hud.has_node("NightVignette"), "Vinheta some sozinha")
	# Restos ao ser derrotado: copia so visual que afunda e some.
	var foe: Node3D = foes[0]
	var before := world.get_child_count()
	foe.get_node("Visual").defeated()
	var remains := world.get_children().filter(func(n): return n is Node3D and n.get_script() == null and n.has_node("Body"))
	check(world.get_child_count() > before and remains.size() == 1, "Derrota deixa restos visuais (sem script)")
	await frames(60 * 2)
	check(not is_instance_valid(remains[0]) or remains[0].is_queued_for_deletion(), "Restos somem sozinhos em ~1,3 s")
	# Player: explorador.
	var pv: Node3D = player.get_node("Visual")
	check(["Hat", "HatBand", "Cape", "Satchel", "LegL", "LegR", "ArmL", "ArmR", "HeadingMark"].all(func(p): return pv.has_node(p)), "Player: chapeu, capa, mochila, membros e marcador de direcao")
	# Conquista de territorio: coluna de luz.
	var marker: Node3D = get_tree().get_first_node_in_group("territory_marker")
	var n0 := world.find_children("*", "MeshInstance3D", true, false).size()
	marker.play_claim_effect()
	await frames(2)
	var pillar := world.find_children("*", "MeshInstance3D", true, false).filter(func(m): return m.mesh is CylinderMesh)
	check(pillar.size() >= 1 and world.find_children("*", "MeshInstance3D", true, false).size() > n0, "Conquista de territorio: coluna de luz jade")
