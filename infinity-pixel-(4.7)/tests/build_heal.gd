extends Node

# Spec 013D — inventario (I), construcao (B: fantasma, validacao, posicionamento),
# Fogueira de Cura e Armadilha de Espinhos, na cena real. Itens entre colchetes.
# No fim, uma partida curta junta coleta -> construcao -> noite -> cura -> armadilha.
const Recipes := preload("res://scenes/world/build_recipes.gd")
var passed: Array[String] = []
var failed: Array[String] = []
var app: Node
var world: Node3D
var player: CharacterBody3D
var stock: Node
var placer: Node
var wave: Node

func check(ok: bool, title: String) -> void:
	(passed if ok else failed).append(title)
	print(("PASS: " if ok else "FAIL: ") + title)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

# Espera em TEMPO DE JOGO (passos de fisica), a mesma base da recarga/canalizacao
# da Fogueira e das armadilhas. Com janela e quadros perdidos, um timer de parede
# correria na frente do jogo e o teste mediria errado.
func wait(seconds: float) -> void:
	for i in int(round(seconds * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame

func key(code: Key, pressed := true) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)

# parse_input_event e entregue no proximo QUADRO DE PROCESSO. Com janela e quadros
# perdidos varios passos de fisica cabem num quadro; esperar so fisica nao basta.
func tap(code: Key) -> void:
	key(code, true)
	await get_tree().process_frame
	await get_tree().process_frame
	await frames(1)
	key(code, false)
	await get_tree().process_frame
	await get_tree().process_frame

func mouse(button: MouseButton) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = pressed
		ev.position = Vector2(640, 360)
		get_viewport().push_input(ev, true)
	await frames(2)

func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func give(wood: int, stone: int) -> void:
	stock.add(&"wood", wood)
	stock.add(&"stone", stone)

func set_resources(wood: int, stone: int) -> void:
	stock.spend_resources(stock.get_amount(&"wood"), stock.get_amount(&"stone"))
	give(wood, stone)

# Posiciona a receita num ponto e confirma com um CLIQUE ESQUERDO real.
func build_at(id: StringName, pos: Vector3) -> Node3D:
	placer.begin(id)
	placer.follow_cursor = false
	placer.move_ghost_to(pos)
	var before: int = world.get_node("Structures").get_child_count()
	await mouse(MOUSE_BUTTON_LEFT)
	var kids: Array = world.get_node("Structures").get_children()
	return kids.back() if kids.size() > before else null

func hold_heal(seconds: float) -> void:
	Input.action_press("heal_interact")
	await wait(seconds)
	Input.action_release("heal_interact")
	await frames(2)

# Congela cada inimigo assim que nasce (nao anda ate as armadilhas) e vence a
# noite quando a onda inteira nasceu.
func win_night() -> void:
	while DayNightManager.is_night():
		for f in wave._active_wave_enemies.keys(): f.set_physics_process(false)
		if wave._spawned_count >= wave.enemy_count:
			for foe in wave._active_wave_enemies.keys(): foe.take_damage(1000)
		await get_tree().physics_frame
	await frames(3)

func route_point_near(from: Vector3, trail_name: String) -> Vector3:
	# Ponto na linha central da rota mais proximo de `from` (a partir dos trechos).
	var best := Vector3.INF
	for stretch in world.get_node("WorldRegions/NightRoutes/" + trail_name).get_children():
		if not String(stretch.name).begins_with("Stretch"): continue
		var corners := {}
		for f in stretch.mesh.get_faces(): corners[Vector2(snappedf(f.x, .01), snappedf(f.z, .01))] = true
		var pts: Array = corners.keys()
		var a: Vector2 = (pts[0] + pts[3]) * .5
		var b: Vector2 = (pts[1] + pts[2]) * .5
		var c := Geometry2D.get_closest_point_to_segment(Vector2(from.x, from.z), a, b)
		if best == Vector3.INF or c.distance_to(Vector2(from.x, from.z)) < Vector2(best.x, best.z).distance_to(Vector2(from.x, from.z)):
			best = Vector3(c.x, 0, c.y)
	return best

func _ready() -> void:
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	app.start_game()
	await frames(3)
	world = app.world
	player = world.get_node("Player")
	player.set_process_unhandled_input(false) # sem mira por mouse real (janela)
	stock = world.get_node("ResourceStock")
	placer = world.get_node("BuildPlacer")
	wave = world.get_node("WaveManager")
	for d in world.get_node("EncounterSpawner").encounters: d.set_physics_process(false)
	var build_zone: Vector3 = world.get_node("WorldRegions/SafeZone/BuildZone").global_position
	player.global_position = build_zone + Vector3(-3, .1, 5)
	await frames(30)

	# ---------------- Inventario [A]-[I]
	await tap(KEY_I)
	check(app.inventory_panel.visible, "[A] I abre o inventario")
	var clock_before: float = DayNightManager.phase_elapsed
	await wait(.5)
	check(not get_tree().paused and DayNightManager.phase_elapsed > clock_before + .3, "[C] Inventario aberto nao pausa (relogio andando)")
	check(app.inv_wood_text.text == str(stock.get_amount(&"wood")) and app.inv_stone_text.text == str(stock.get_amount(&"stone")), "[D][E] Madeira e Pedra exibidas = ResourceStock")
	give(40, 18)
	check(app.inv_wood_text.text == "40" and app.inv_stone_text.text == "18" and app.wood_text.text == "40", "[F] Ganhar recurso atualiza o inventario no mesmo quadro (sinal)")
	stock.spend_resources(5, 2)
	check(app.inv_wood_text.text == "35" and app.inv_stone_text.text == "16", "[G] Gastar recurso atualiza o inventario")
	check(not stock.spend_resources(100, 0) and stock.get_amount(&"wood") == 35 and stock.get_amount(&"wood") >= 0, "[H] Gasto maior que o estoque falha e nunca fica negativo")
	set_resources(20, 6)
	check(not stock.spend_resources(20, 12) and stock.get_amount(&"wood") == 20 and stock.get_amount(&"stone") == 6, "[I] Receita 20/12 com 20/6: falha atomica, nada e retirado")
	await tap(KEY_I)
	check(not app.inventory_panel.visible, "[B] I fecha o inventario")

	# ---------------- Construcao [J]-[U] + Fogueira [V][W]
	set_resources(60, 30)
	await tap(KEY_B)
	check(app.build_menu_panel.visible, "[J] B abre o menu de construcao")
	var fire_button: Button = app._recipe_rows[app.build_menu_panel][Recipes.CAMPFIRE].button
	fire_button.pressed.emit()
	check(placer.is_placing() and placer.recipe_id == Recipes.CAMPFIRE and is_instance_valid(placer.ghost) and not app.build_menu_panel.visible, "[K] Escolher a Fogueira mostra o fantasma")
	placer.follow_cursor = false
	var fire_pos := build_zone + Vector3(1.5, 0, -2)
	placer.move_ghost_to(fire_pos)
	await frames(2)
	check(placer.ghost_valid and flat(placer.ghost.global_position, fire_pos) < .01, "[L] Fantasma acompanha o ponto e fica valido na BuildZone")
	placer.move_ghost_to(Vector3(0, 0, 2))
	check(not placer.ghost_valid and placer.ghost_reason == "Fora da área permitida", "[M][Q] Fora da BuildZone: invalido (%s)" % placer.ghost_reason)
	await frames(2)
	check(app.placement_panel.visible and app.placement_note.text == "Fora da área permitida", "Painel de posicionamento mostra o motivo")
	var tree = world.get_node("Collectables/Tree1")
	check(placer.validate(Recipes.CAMPFIRE, tree.global_position) != "", "Nao constroi sobre arvore coletavel")
	# [S] cancelar nao gasta
	var w0: int = stock.get_amount(&"wood")
	await mouse(MOUSE_BUTTON_RIGHT)
	check(not placer.is_placing() and stock.get_amount(&"wood") == w0, "[S] Botao direito cancela sem gastar")
	placer.begin(Recipes.CAMPFIRE)
	await tap(KEY_ESCAPE)
	check(not placer.is_placing() and not get_tree().paused and app.screen == "playing", "ESC cancela o posicionamento antes de pausar")
	# [R][T][V] construir com clique: gasta exatamente 20/12 e nao ataca
	var attacks: int = player.attack_count
	var fire := await build_at(Recipes.CAMPFIRE, fire_pos)
	check(fire != null and fire.is_in_group("healing_campfire"), "Fogueira construida com clique esquerdo")
	check(player.attack_count == attacks, "[R] O clique de construir nao gera ataque")
	check(stock.get_amount(&"wood") == 40 and stock.get_amount(&"stone") == 18, "[T][V] Fogueira custa exatamente 20 Madeira + 12 Pedra (60/30 -> 40/18)")
	check(app.hud.get_children().any(func(c): return String(c.name).begins_with("BuildNotice") and c.get_child(0).get_child(0).text == "FOGUEIRA CONSTRUÍDA"), "Aviso 'FOGUEIRA CONSTRUÍDA'")
	check(placer.recipe_block_reason(Recipes.CAMPFIRE) == "LIMITE ATINGIDO" and not placer.begin(Recipes.CAMPFIRE), "[W] Maximo de 1 Fogueira (LIMITE ATINGIDO)")
	# Armadilhas [AL][AM] + validacoes [N][O][P]
	var west_slot: Node3D = world.get_node("DefenseSlots/SlotWestInner")
	var t1_pos := route_point_near(Vector3(0, 0, 6), "RuinRoad") + Vector3(0, 0, -2) # estrada, campina
	var t2_pos := route_point_near(Vector3(-17, 0, 1), "WestTrail")
	var t3_pos := route_point_near(Vector3(17, 0, 1), "EastTrail")
	var w1: int = stock.get_amount(&"wood")
	var s1: int = stock.get_amount(&"stone")
	var trap1 := await build_at(Recipes.TRAP, t1_pos)
	check(trap1 != null and stock.get_amount(&"wood") == w1 - 15 and stock.get_amount(&"stone") == s1 - 6, "[AL] Armadilha custa 15 Madeira + 6 Pedra")
	check(placer.validate(Recipes.TRAP, t1_pos + Vector3(.4, 0, .4)) == "Local ocupado", "[N] Nao constroi sobre outra estrutura")
	check(placer.validate(Recipes.TRAP, world.get_node("Territory").global_position + Vector3(0, 0, 1.5)) == "Muito perto do refúgio", "[O] Nao constroi sobre o refugio")
	var near_slot := route_point_near(west_slot.global_position, "WestTrail").lerp(west_slot.global_position, .55)
	check(placer.validate(Recipes.TRAP, near_slot) == "Ocupado por ponto de defesa", "[P] Nao constroi sobre ponto de defesa/torre (%s)" % placer.validate(Recipes.TRAP, near_slot))
	check(placer.validate(Recipes.TRAP, build_zone) == "Coloque sobre uma rota de ataque", "Armadilha fora das rotas: recusada")
	player.global_position = t2_pos + Vector3(0, .1, .3)
	await frames(3)
	check(placer.validate(Recipes.TRAP, t2_pos) == "Local ocupado", "Nao constroi em cima do Player")
	player.global_position = build_zone + Vector3(-3, .1, 5)
	await frames(3)
	give(30, 12)
	var trap2 := await build_at(Recipes.TRAP, t2_pos)
	var trap3 := await build_at(Recipes.TRAP, t3_pos)
	check(trap2 != null and trap3 != null and get_tree().get_nodes_in_group("spike_trap").size() == 3, "3 armadilhas, uma por rota")
	give(15, 6)
	check(placer.recipe_block_reason(Recipes.TRAP) == "LIMITE ATINGIDO" and not placer.begin(Recipes.TRAP), "[AM] Maximo de 3 armadilhas")
	check(trap1.charges == 3, "[AS] Armadilha comeca com 3 cargas")
	var trap_bodies := trap1.find_children("*", "CollisionObject3D", true, false).filter(func(c): return c is PhysicsBody3D)
	check(trap_bodies.is_empty() and trap1.find_children("*", "NavigationObstacle3D", true, false).is_empty(), "[AU] Armadilha sem corpo solido e sem obstaculo de navegacao")

	# ---------------- Fogueira: cura [X]-[AK]
	check(fire.charges == 2, "[AF] Fogueira comeca com 2 cargas")
	player.current_hp = 50.0
	player.global_position = fire.global_position + Vector3(0, .1, 4.0)
	await frames(3)
	await hold_heal(1.0)
	check(fire.progress() == 0.0 and player.current_hp == 50.0, "[X] Fora do alcance (4 m) H nao cura")
	player.global_position = fire.global_position + Vector3(0, .1, 1.8)
	await frames(3)
	Input.action_press("heal_interact")
	await wait(2.7)
	var mid_hp: float = player.current_hp
	var mid_progress: float = fire.progress()
	await wait(.5)
	Input.action_release("heal_interact")
	await frames(2)
	check(mid_hp == 50.0 and mid_progress > .85 and player.current_hp == 75.0, "[Y][Z] 3 s de canalizacao (sem cura aos 2,7 s); +25 (50 -> 75)")
	check(fire.charges == 1 and absf(fire.cooldown_left - 25.0) < .7, "[AE][AI] Cura consome 1 carga e inicia recarga de 25 s (%.1f)" % fire.cooldown_left)
	await hold_heal(1.0)
	check(fire.progress() == 0.0 and player.current_hp == 75.0 and fire.block_reason().begins_with("Recarregando"), "[AI] Durante a recarga H nao cura")
	await wait(23.0)
	check(fire.cooldown_left > 0.0, "[AI] Recarga ainda ativa aos ~24 s")
	await wait(1.5)
	check(fire.cooldown_left == 0.0, "[AI] Recarga termina aos 25 s")
	# [AB] afastar cancela
	Input.action_press("heal_interact")
	await wait(1.0)
	player.global_position = fire.global_position + Vector3(0, .1, 4.0)
	await frames(3)
	var after_move: float = fire.progress()
	await wait(2.5)
	Input.action_release("heal_interact")
	check(after_move == 0.0 and player.current_hp == 75.0 and fire.charges == 1, "[AB] Sair do alcance cancela sem curar nem gastar carga")
	# [AC] dano cancela
	player.global_position = fire.global_position + Vector3(0, .1, 1.8)
	await frames(3)
	Input.action_press("heal_interact")
	await wait(1.0)
	player._invulnerable_left = 0.0
	player.take_damage(5)
	await frames(2)
	var after_hit: float = fire.progress()
	await wait(2.5)
	Input.action_release("heal_interact")
	await frames(2)
	# Com H ainda segurado, uma canalizacao NOVA pode recomecar do zero no quadro
	# seguinte; o que importa e descartar a anterior (~0,33) e nao curar parcialmente.
	check(after_hit < 0.05 and player.current_hp == 70.0 and fire.charges == 1, "[AC] Sofrer dano cancela (progresso descartado, 70, sem cura parcial)")
	# atacar cancela
	await wait(.3)
	Input.action_press("heal_interact")
	await wait(1.0)
	var before_attack: float = fire.progress()
	player.attack_cooldown.stop()
	player._try_attack()
	await frames(2)
	var after_attack: float = fire.progress()
	Input.action_release("heal_interact")
	await frames(2)
	check(before_attack > .25 and after_attack < 0.05 and player.current_hp == 70.0 and fire.charges == 1, "Atacar cancela a cura (%.2f -> %.2f, sem cura parcial)" % [before_attack, after_attack])
	# pausar cancela (ao voltar, recomeca do zero)
	await wait(.8)
	Input.action_press("heal_interact")
	await wait(1.0)
	var before_pause: float = fire.progress()
	get_tree().paused = true
	await frames(3)
	var during_pause: float = fire.progress()
	Input.action_release("heal_interact")
	get_tree().paused = false
	await frames(3)
	check(before_pause > .25 and during_pause == 0.0 and fire.progress() == 0.0 and player.current_hp == 70.0 and fire.charges == 1, "Pausar cancela a cura (%.2f -> %.2f, sem cura parcial)" % [before_pause, during_pause])
	# [AA] nunca passa de 100
	player.current_hp = 90.0
	await wait(.7)
	await hold_heal(3.3)
	check(player.current_hp == 100.0 and fire.charges == 0, "[AA] 90 -> 100 (nao passa do maximo); 2a carga usada")
	# [AG] terceira cura no ciclo recusada; [AK] 100/100 nao gasta
	player.current_hp = 60.0
	fire.cooldown_left = 0.0 # isola a regra de cargas da recarga
	await hold_heal(3.3)
	check(player.current_hp == 60.0 and fire.block_reason() == "Sem cargas até amanhecer", "[AG] Terceira cura no mesmo ciclo recusada")
	# [AD][AJ] morte cancela e morto nao usa
	DayNightManager.start_night()
	await win_night()
	check(fire.charges == 2, "[AH] Amanhecer restaura 2 cargas (Dia %d)" % DayNightManager.day_number)
	player.current_hp = 100.0
	player.global_position = fire.global_position + Vector3(0, .1, 1.8)
	await frames(3)
	await hold_heal(3.3)
	check(fire.charges == 2 and fire.block_reason() == "Vida cheia", "[AK] Com 100/100 nao canaliza nem gasta carga")
	player.current_hp = 40.0
	Input.action_press("heal_interact")
	await wait(1.0)
	player._invulnerable_left = 0.0
	player.take_damage(1000)
	await frames(2)
	check(player.is_dead and fire.progress() == 0.0 and fire.charges == 2, "[AD] Morrer cancela a cura")
	check(fire.block_reason() == "Indisponível", "[AJ] Morto nao pode usar a Fogueira")
	Input.action_release("heal_interact")
	await wait(2.5)
	check(not player.is_dead and player.current_hp == 100.0, "Respawn intacto (100/100)")
	check(flat(player.global_position, world.get_node("PlayerSpawn").global_position) < .2, "Respawn no mesmo ponto no plano (Fogueira nao revive)")

	# ---------------- Construcao a noite [U] e armadilha [AN]-[AV]
	DayNightManager.start_night()
	await wait(.3)
	set_resources(50, 50)
	check(not placer.begin(Recipes.TRAP) and placer.recipe_block_reason(Recipes.CAMPFIRE) == "LIMITE ATINGIDO" and placer.validate(Recipes.TRAP, t1_pos) == "Construa durante o dia", "[U] Construcao bloqueada a noite")
	# Espera 3 inimigos nascerem, congelando cada um ao nascer (longe das armadilhas).
	while wave._active_wave_enemies.size() < 3:
		for f in wave._active_wave_enemies.keys(): f.set_physics_process(false)
		await get_tree().physics_frame
	var foes: Array = wave._active_wave_enemies.keys()
	for f in foes:
		f.set_physics_process(false)
		f.global_position = Vector3(foes.find(f) * 2.0, .5, 40)
	await frames(2)
	check(trap1.charges == 3, "Armadilha intacta antes do teste de ativacao (cargas 3)")
	var foe = foes[0]
	foe.global_position = Vector3(0, .5, 40)
	await frames(2)
	foe.global_position = trap1.global_position + Vector3(0, .5, 0)
	await frames(4)
	check(foe.hp == 65.0 and trap1.charges == 2, "[AN][AR] Inimigo da onda sobre a armadilha: -15 e -1 carga")
	await wait(1.2)
	check(foe.hp == 65.0 and trap1.charges == 2, "[AV] Mesma passagem: no maximo 1 golpe (parado em cima 1,2 s)")
	foe.global_position = Vector3(0, .5, 40)
	await frames(4)
	# [AO] Player, [AP] aliado, [AQ] selvagem diurno: nunca
	player._invulnerable_left = 0.0
	var php: float = player.current_hp
	player.global_position = trap1.global_position + Vector3(0, .1, 0)
	await wait(.6)
	check(player.current_hp == php and trap1.charges == 2, "[AO] Player sobre a armadilha: sem dano")
	player.global_position = world.get_node("PlayerSpawn").global_position
	var ally = world.get_node("EncounterSpawner").encounters[0]
	ally.hp = 20.0
	ally.domesticate()
	ally.global_position = trap1.global_position + Vector3(0, .5, 0)
	await wait(.6)
	check(ally.hp == 80.0 and trap1.charges == 2, "[AP] Aliado domesticado sobre a armadilha: sem dano")
	ally.global_position = build_zone + Vector3(0, .5, 4)
	var day_wild = world.get_node("EncounterSpawner").encounters[1]
	day_wild.global_position = trap1.global_position + Vector3(0, .5, 0)
	await wait(.6)
	check(day_wild.hp == 80.0 and trap1.charges == 2, "[AQ] Selvagem diurno sobre a armadilha: sem dano")
	day_wild.global_position = Vector3(13, .5, 22)
	# [AV] dois inimigos no mesmo quadro: 1 golpe; o outro so depois do intervalo
	var a = foes[1]
	var b = foes[2]
	a.global_position = trap1.global_position + Vector3(.3, .5, 0)
	b.global_position = trap1.global_position + Vector3(-.3, .5, 0)
	await frames(2)
	await frames(2) # sobreposicao da Area3D e calculada no passo de fisica
	var hit_now := int(a.hp < 80.0) + int(b.hp < 80.0)
	await wait(.6)
	var hit_later := int(a.hp < 80.0) + int(b.hp < 80.0)
	check(hit_now == 1 and hit_later == 2 and trap1.charges == 0, "[AV] Dois no mesmo quadro: 1 golpe, o 2o apos o intervalo (cargas 0)")
	await wait(.6)
	check(not is_instance_valid(trap1) and get_tree().get_nodes_in_group("spike_trap").size() == 2, "[AT] 3 ativacoes: armadilha esgota e some (limite libera)")
	await win_night()
	check(is_instance_valid(trap2) and trap2.charges == 3 and get_tree().get_nodes_in_group("spike_trap").size() == 2, "Armadilha com cargas continua no dia seguinte")

	# [AU] navegacao: inimigo real atravessa uma armadilha na estrada e chega ao refugio
	set_resources(15, 6)
	var road_trap := await build_at(Recipes.TRAP, route_point_near(Vector3(0, 0, 4), "RuinRoad"))
	check(road_trap != null, "Armadilha na estrada (campina) para o teste de passagem")
	player.remove_from_group("player")
	player.collision_layer = 0
	player.global_position = Vector3(0, .1, -40)
	world.get_node("Territory").health = 1000.0 # fixture: o refugio aguenta a travessia
	DayNightManager.start_night()
	var walker: Node3D = null
	while walker == null:
		await get_tree().physics_frame
		for f in wave._active_wave_enemies.keys():
			if flat(f.global_position, Vector3(0, 0, 23)) < 3.0: walker = f
	var t := 0.0
	while t < 20.0 and flat(walker.global_position, world.get_node("Territory").global_position) > 2.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
	check(walker.hp == 65.0 and road_trap.charges < 3 and flat(walker.global_position, world.get_node("Territory").global_position) <= 2.0, "[AU] Inimigo da Ruina passa POR CIMA da armadilha (um golpe, -15) e chega ao refugio (%.1f s)" % t)
	world.get_node("Territory").health = 100.0
	player.add_to_group("player")
	player.collision_layer = 2
	await win_night()

	# ---------------- Partida curta: coleta -> construcao -> noite -> cura -> armadilha
	app.start_game()
	await frames(3)
	world = app.world
	player = world.get_node("Player")
	player.set_process_unhandled_input(false)
	stock = world.get_node("ResourceStock")
	placer = world.get_node("BuildPlacer")
	wave = world.get_node("WaveManager")
	for d in world.get_node("EncounterSpawner").encounters: d.set_physics_process(false)
	check(stock.get_amount(&"wood") == 0 and world.get_node("DefenseEconomy").points == 40 and world.get_node("Structures").get_child_count() == 0 and DayNightManager.day_number == 1, "Reiniciar: 0 Madeira, 40 Pontos, sem estruturas, Dia 1")
	for i in 4:
		var tr: Node3D = world.get_node("Collectables/Tree%d" % (i + 1))
		player.global_position = tr.global_position + Vector3(0, .1, 1.5)
		player.rotation.y = 0.0
		await frames(3)
		for hit in 2:
			player.attack_cooldown.stop()
			player._try_attack()
			await frames(2)
	for i in 3:
		var st: Node3D = world.get_node("Collectables/Stone%d" % (i + 1))
		player.global_position = st.global_position + Vector3(0, .1, 1.9)
		player.rotation.y = 0.0
		await frames(3)
		for hit in 3:
			player.attack_cooldown.stop()
			player._try_attack()
			await frames(2)
	check(stock.get_amount(&"wood") == 40 and stock.get_amount(&"stone") == 18, "Dia 1: coletou 40 Madeira + 18 Pedra (4 arvores, 3 pedras)")
	bz_pos_build(build_zone)
	var g_fire := await build_at(Recipes.CAMPFIRE, build_zone + Vector3(1.5, 0, -2))
	var g_trap := await build_at(Recipes.TRAP, route_point_near(Vector3(0, 0, 4), "RuinRoad"))
	var trap_hits := [0] # array: lambdas copiam variaveis locais
	if g_trap != null: g_trap.triggered.connect(func(_e): trap_hits[0] += 1) # antes da noite
	check(g_fire != null and g_trap != null and stock.get_amount(&"wood") == 5 and stock.get_amount(&"stone") == 0, "Construiu Fogueira + Armadilha: sobram 5 Madeira, 0 Pedra")
	world.get_node("DefenseSlots").interact(world.get_node("DefenseSlots/SlotRuinArch"))
	var g_tower = world.get_node("DefenseSlots/SlotRuinArch").tower
	DayNightManager.start_night()
	player._invulnerable_left = 0.0
	player.take_damage(45) # ferido na batalha
	await frames(2)
	var hurt: float = player.current_hp
	player.global_position = g_fire.global_position + Vector3(0, .1, 1.8) # recua para a base
	await frames(3)
	await hold_heal(3.3)
	check(hurt == 55.0 and player.current_hp == 80.0, "Noite 1: ferido (55) recua e cura na Fogueira (+25 -> 80)")

	var tower_hit := false

	var seen_hp := {}
	t = 0.0
	while (trap_hits[0] == 0 or not tower_hit) and t < 25.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if is_instance_valid(g_tower.target): tower_hit = true
	check(trap_hits[0] > 0 and tower_hit, "Noite 1: inimigo passa pela armadilha e a torre continua atacando")
	await win_night()
	check(DayNightManager.is_day() and DayNightManager.day_number == 2, "Noite vencida com construcoes + torre + Player")

	app.show_menu()
	await get_tree().process_frame
	var report := {"passed": passed, "failed": failed, "display": DisplayServer.get_name()}
	var destination := "user://spec013d.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): destination = argument.trim_prefix("--report=")
	var file := FileAccess.open(destination, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("SPEC013D RESULTS: %d passed; %d failed" % [passed.size(), failed.size()])
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)

func bz_pos_build(_bz: Vector3) -> void:
	pass # ponto de leitura: a construcao do cenario usa a BuildZone real
