extends Node

# Spec 015 — territorios controlados e expansao da base. Verificacao
# automatizada (headless ou com janela), pelos sistemas reais: guardiao morto ou
# domesticado de verdade, E segurado pela acao "domesticate", noite/amanhecer
# reais, construcao pelo BuildPlacer e caminhos da navmesh.
const Recipes := preload("res://scenes/world/build_recipes.gd")
const TM := preload("res://scenes/world/territory_manager.gd")
const WEST_SPOT := Vector3(-8, 0, 8) # chao aberto no bosque (sondado)
const EAST_SPOT := Vector3(10, 0, 10) # chao aberto na regiao rochosa
var passed: Array[String] = []
var failed: Array[String] = []
var app
var world: Node3D
var tm
var player
var dom
var placer
var stock
var economy
var wave
var claims: Array = [] # ids recebidos por `claimed`
var state_events: Array = [] # [id, state] recebidos por `state_changed`

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func seconds(s: float) -> void:
	await frames(int(round(s * 60.0)))

func check(ok: bool, label: String) -> void:
	(passed if ok else failed).append(label)
	print(("PASS: " if ok else "FAIL: ") + label)

func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func hold_e(on: bool) -> void:
	if on: Input.action_press("domesticate")
	else: Input.action_release("domesticate")

func release_e() -> void:
	hold_e(false)
	await frames(3)

func start() -> void:
	app.start_game()
	await frames(4)
	world = app.world
	tm = world.get_node("TerritoryManager")
	player = world.get_node("Player")
	player.set_process_unhandled_input(false)
	dom = player.get_node("DomesticationChannel")
	placer = world.get_node("BuildPlacer")
	placer.follow_cursor = false
	stock = world.get_node("ResourceStock")
	economy = world.get_node("DefenseEconomy")
	wave = world.get_node("WaveManager")
	claims.clear()
	state_events.clear()
	tm.claimed.connect(func(id, _n): claims.append(id))
	tm.state_changed.connect(func(id, s): state_events.append([id, s]))
	# Construcao valida exige a 1a sincronizacao da navmesh do mundo novo.
	var map: RID = world.get_world_3d().navigation_map
	for i in 300:
		var on := NavigationServer3D.map_get_closest_point(map, WEST_SPOT)
		if flat(on, WEST_SPOT) <= .35:
			break
		await frames(1)
	await frames(2)

func freeze_guardians() -> void:
	for id in tm.guardians:
		tm.guardians[id].set_physics_process(false)

func at_marker(id: StringName, dist := 1.5) -> void:
	player.global_position = tm.markers[id].global_position + Vector3(0, .1, dist)
	await frames(3)

## Noite completa e amanhecer, pelo caminho real do DayNightManager.
func night_and_dawn() -> void:
	DayNightManager.start_night()
	await frames(5)
	wave.cancel_wave()
	await frames(2)
	DayNightManager.report_wave_victory()
	await frames(5)

func _ready() -> void:
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	var dnm = DayNightManager
	await start()
	var signals0 := [dnm.day_started.get_connections().size(), dnm.night_started.get_connections().size()] # com 1 mundo vivo
	player._invulnerable_left = INF
	freeze_guardians()

	# [1–4] manager e estado inicial.
	check(tm != null and tm.is_in_group("territory_manager") and tm.total_count() == 3, "[1] TerritoryManager existe com 3 territorios")
	check(tm.state_of(&"center") == TM.CONTROLLED, "[2] Centro (refugio) comeca CONTROLLED")
	check(tm.state_of(&"west") == TM.WILD, "[3] Floresta Oeste comeca WILD")
	check(tm.state_of(&"east") == TM.WILD, "[4] Regiao Rochosa comeca WILD")
	check(TM.territory_at(Vector3(0, 0, -15)) == &"center" and TM.territory_at(Vector3(-10, 0, 10)) == &"west" and TM.territory_at(Vector3(13, 0, 22)) == &"east" and TM.territory_at(Vector3(0, 0, 20)) == &"", "Regioes do mapa: refugio, bosque, rochosa; corredor da ruina fora (area futura)")
	check(app.territory_text.text == "1/3", "[26] HUD comeca em TERRITORIOS 1/3")
	var gw = tm.guardians.get(&"west")
	var ge = tm.guardians.get(&"east")
	var spawner = world.get_node("EncounterSpawner")
	check(gw != null and ge != null and gw == spawner.encounters[0] and ge == spawner.encounters[1], "Guardioes = os 2 encontros diurnos existentes (sem especie nova)")
	check(gw.guardian_of == "FLORESTA OESTE" and gw.hp_label.text.begins_with("GUARDIÃO") and gw.is_domesticable, "Guardiao identificado (rotulo GUARDIAO) e domesticavel")
	check(not gw.is_in_group("wave_enemy") and not ge.is_in_group("wave_enemy") and wave._active_wave_enemies.is_empty(), "[10] Guardioes nao sao inimigos da onda")
	for id in tm.markers:
		check(tm.markers[id].state == TM.WILD and placer._route_distance(tm.markers[id].global_position) > 3.5, "Marco %s apagado e longe das rotas noturnas" % id)

	# [29][31] construcao recusada em territorio selvagem; corredor sempre fora.
	check(placer.validate(Recipes.CAMPFIRE, WEST_SPOT) == "Território selvagem: recupere o marco primeiro", "[29] Fogueira no Oeste selvagem recusada")
	check(placer.validate(Recipes.CAMPFIRE, EAST_SPOT) == "Território selvagem: recupere o marco primeiro", "[31] Fogueira no Leste selvagem recusada")
	check(placer.validate(Recipes.CAMPFIRE, Vector3(3.5, 0, 20)) == "Fora da área permitida", "Corredor da ruina (area futura) continua fora")
	check(placer.validate(Recipes.CAMPFIRE, world.get_node("WorldRegions/SafeZone/BuildZone").global_position + Vector3(1.5, 0, -2)) == "", "BuildZone original continua valida (013D)")

	# [19] marco WILD: E nao faz nada.
	await at_marker(&"west")
	hold_e(true)
	await seconds(0.6)
	check(tm.claim_progress() == 0.0 and tm.state_of(&"west") == TM.WILD, "Marco selvagem nao ativa com E")
	await release_e()

	# [7][5][9] derrotar o guardiao Oeste.
	var points_before: int = economy.points
	var snap_before: Dictionary = wave.snapshot()
	gw.take_damage(gw.MAX_HP)
	await frames(3)
	check(tm.state_of(&"west") == TM.READY_TO_CLAIM and tm.markers[&"west"].state == TM.READY_TO_CLAIM, "[5][7] Derrotar o guardiao: Oeste WILD -> READY_TO_CLAIM; marco aceso")
	check(economy.points == points_before, "[9] Guardiao derrotado nao da Pontos de Defesa (%d)" % economy.points)
	check(wave.snapshot() == snap_before, "[10] Guardiao derrotado nao conta na onda")
	check(not tm.guardians.has(&"west") and state_events.size() == 1, "Neutralizacao registrada uma vez")

	# Cancelamentos (sem progresso parcial salvo).
	await at_marker(&"west")
	hold_e(true)
	await seconds(0.7)
	var p1: float = tm.claim_progress()
	await release_e()
	check(p1 > 0.25 and tm.claim_progress() == 0.0 and tm.state_of(&"west") == TM.READY_TO_CLAIM, "[15] Soltar E cancela (%.2f -> 0)" % p1)
	hold_e(true)
	await seconds(0.7)
	player.global_position = tm.markers[&"west"].global_position + Vector3(0, .1, 4.0)
	await frames(3)
	check(tm.claim_progress() == 0.0 and tm.state_of(&"west") == TM.READY_TO_CLAIM, "[14] Sair do alcance cancela")
	await release_e()
	await at_marker(&"west")
	hold_e(true)
	await seconds(0.7)
	player.attack_cooldown.stop()
	player._try_attack()
	await frames(3)
	check(tm.claim_progress() == 0.0, "Atacar cancela a recuperacao")
	await release_e()
	stock.add(&"wood", 15) # o posicionamento so comeca com recursos
	stock.add(&"stone", 6)
	hold_e(true)
	await seconds(0.7)
	placer.begin(Recipes.TRAP)
	await frames(3)
	check(tm.claim_progress() == 0.0, "Iniciar posicionamento de construcao cancela")
	placer.cancel()
	await release_e()
	hold_e(true)
	await seconds(0.7)
	app.pause_game()
	for i in 30: await get_tree().process_frame
	check(tm.claim_progress() == 0.0 and tm.state_of(&"west") == TM.READY_TO_CLAIM, "[17] Pausar cancela")
	app.resume_game()
	await frames(6)
	check(tm.claim_progress() < 0.15, "[17] Ao despausar com E segurado recomeca do zero (%.2f)" % tm.claim_progress())
	await release_e()
	player._invulnerable_left = 0.0
	hold_e(true)
	await seconds(0.7)
	player.take_damage(1000.0)
	await frames(3)
	check(player.is_dead and tm.claim_progress() == 0.0, "[16] Morrer cancela")
	await release_e()
	await seconds(3.0)
	check(not player.is_dead and tm.state_of(&"west") == TM.READY_TO_CLAIM, "[24] Depois do respawn o Oeste continua pronto")
	player._invulnerable_left = INF
	await at_marker(&"west")
	hold_e(true)
	await seconds(0.7)
	DayNightManager.start_night()
	await frames(3)
	check(tm.claim_progress() == 0.0 and tm.state_of(&"west") == TM.READY_TO_CLAIM, "[18] Comeco da noite cancela")
	await release_e()
	hold_e(true)
	await seconds(0.8)
	check(tm.claim_progress() == 0.0, "[19] A noite nao da para iniciar a recuperacao")
	await release_e()
	wave.cancel_wave()
	await frames(2)
	DayNightManager.report_wave_victory()
	await frames(5)

	# [23][24 da spec] amanhecer: Oeste segue pronto; o novo encontro do bosque e
	# selvagem comum; o guardiao do Leste (vivo) nao foi duplicado.
	var new_west = spawner.encounters[0]
	check(dnm.day_number == 2 and tm.state_of(&"west") == TM.READY_TO_CLAIM and tm.state_of(&"east") == TM.WILD, "[23] Estados atravessam a noite (Dia 2)")
	check(is_instance_valid(new_west) and new_west != gw and new_west.guardian_of == "" and not tm.guardians.has(&"west"), "Amanhecer recria o encontro do bosque como selvagem comum (sem guardiao duplicado)")
	var day_wild := get_tree().get_nodes_in_group("wild_dino").filter(func(d): return not d.is_in_group("wave_enemy") and not d.is_queued_for_deletion())
	check(tm.guardians.get(&"east") == ge and spawner.encounters[1] == ge and day_wild.size() == 2, "Guardiao vivo do Leste nao e recriado nem duplicado (%d selvagens diurnos: %s)" % [day_wild.size(), day_wild.map(func(d): return d.name)])
	new_west.set_physics_process(false)

	# [11][13] E perto de um selvagem elegivel E do marco pronto: so domestica.
	new_west.hp = 20.0
	await at_marker(&"west")
	new_west.global_position = player.global_position + Vector3(1.8, .4, 0)
	await frames(2)
	hold_e(true)
	await seconds(2.3)
	check(new_west.is_domesticated and tm.claim_progress() == 0.0 and tm.state_of(&"west") == TM.READY_TO_CLAIM, "[11] E com alvo domesticavel valido domestica (prioridade sobre o marco)")
	await seconds(1.0)
	check(tm.claim_progress() == 0.0 and tm.state_of(&"west") == TM.READY_TO_CLAIM, "[13] A mesma segurada de E nao ativa o marco depois de domesticar")
	await release_e()
	new_west.global_position = Vector3(-3, .5, -9)

	# [12][13][20][21] marco: segurar E 2 s; um selvagem elegivel que chega no meio
	# nao e domesticado nessa segurada.
	ge.hp = 20.0
	await at_marker(&"west")
	hold_e(true)
	await seconds(1.0)
	var mid: float = tm.claim_progress()
	ge.global_position = player.global_position + Vector3(-1.8, .4, 0)
	await seconds(0.6)
	check(mid > 0.4 and dom.get_progress() == 0.0 and not ge.is_domesticated, "[13] Durante a recuperacao, E nao comeca domesticacao")
	await seconds(0.6)
	check(tm.state_of(&"west") == TM.CONTROLLED and tm.markers[&"west"].state == TM.CONTROLLED, "[12][20] E no marco por 2 s: Oeste CONTROLLED")
	await seconds(1.0)
	check(dom.get_progress() == 0.0 and not ge.is_domesticated, "[13] A segurada que recuperou o territorio nao domestica depois")
	await release_e()
	check(claims == [&"west"] and app.territory_text.text == "2/3", "[21][27] Conquista uma vez; HUD 2/3")
	hold_e(true)
	await seconds(0.8)
	check(tm.claim_progress() == 0.0 and claims.size() == 1, "[21] Marco ja recuperado nao conquista de novo")
	await release_e()
	check(world.get_node("TerritoryManager").get_children().any(func(c): return c is MeshInstance3D), "Limite discreto do territorio existe")

	# [30][33] construcao no Oeste recuperado.
	stock.add(&"wood", 80)
	stock.add(&"stone", 40)
	check(placer.validate(Recipes.CAMPFIRE, WEST_SPOT) == "", "[30] Oeste recuperado aceita Fogueira em local livre")
	var tree_pos := Vector3.ZERO
	for c in get_tree().get_nodes_in_group("collectable"):
		if c.kind == "wood" and TM.territory_at(c.global_position) == &"west":
			tree_pos = c.global_position
			break
	check(tree_pos != Vector3.ZERO and placer.validate(Recipes.CAMPFIRE, tree_pos) == "Local ocupado", "[33] Arvore no Oeste recuperado continua invalidando")
	check(placer.validate(Recipes.CAMPFIRE, tm.markers[&"west"].global_position) == "Local ocupado", "[33] Nao constroi sobre o marco")
	check(placer.validate(Recipes.TRAP, WEST_SPOT) == "Coloque sobre uma rota de ataque", "Armadilha continua so nas rotas noturnas")
	var wood0: int = stock.get_amount(&"wood")
	var stone0: int = stock.get_amount(&"stone")
	placer.begin(Recipes.CAMPFIRE)
	placer.move_ghost_to(WEST_SPOT)
	var fire = placer.confirm()
	check(fire != null and stock.get_amount(&"wood") == wood0 - 20 and stock.get_amount(&"stone") == stone0 - 12, "[30] Fogueira construida no Oeste (custo 20/12)")
	check(placer.validate(Recipes.CAMPFIRE, EAST_SPOT) == "Limite atingido", "Limite de 1 Fogueira continua valendo")

	# [8][6][22] domesticar o guardiao Leste; a morte posterior do aliado nao muda nada.
	ge.global_position = Vector3(13, .5, 22)
	player.global_position = Vector3(13, .1, 20.2)
	await frames(3)
	var points_east: int = economy.points
	hold_e(true)
	await seconds(2.3)
	await release_e()
	check(ge.is_domesticated and tm.state_of(&"east") == TM.READY_TO_CLAIM and ge.hp == ge.MAX_HP, "[6][8] Domesticar o guardiao: Leste READY_TO_CLAIM (aliado normal, vida cheia)")
	check(economy.points == points_east and ge.guardian_of == "" and ge.hp_label.text.begins_with("ALIADO"), "[9] Domesticar nao paga; vira ALIADO comum")
	var events_before := state_events.size()
	ge.take_damage(500.0)
	await frames(3)
	check(not is_instance_valid(ge) or ge.is_queued_for_deletion(), "Aliado (antigo guardiao) derrotado depois")
	check(tm.state_of(&"east") == TM.READY_TO_CLAIM and state_events.size() == events_before and not tm.guardians.has(&"east"), "[22] Morte posterior do aliado nao altera o territorio")

	# [20][28][32] recuperar o Leste e construir la.
	await at_marker(&"east")
	hold_e(true)
	await seconds(2.2)
	await release_e()
	check(tm.state_of(&"east") == TM.CONTROLLED and app.territory_text.text == "3/3" and claims == [&"west", &"east"], "[20][28] Leste CONTROLLED; HUD 3/3")
	fire.queue_free()
	await frames(2)
	placer.begin(Recipes.CAMPFIRE)
	placer.move_ghost_to(EAST_SPOT)
	fire = placer.confirm()
	check(fire != null, "[32] Leste recuperado aceita Fogueira")

	# [23][24] persistencia: mais uma noite e uma morte.
	await night_and_dawn()
	check(dnm.day_number == 3 and tm.controlled_count() == 3, "[23] Territorios continuam recuperados no Dia 3")
	check(tm.guardians.is_empty() and spawner.encounters.all(func(d): return not is_instance_valid(d) or d.guardian_of == ""), "Encontros recriados depois nao viram guardioes")
	player._invulnerable_left = 0.0
	player.take_damage(1000.0)
	await seconds(3.0)
	check(not player.is_dead and tm.controlled_count() == 3, "[24] Morte/respawn nao perde territorio")
	player._invulnerable_left = INF

	# [34] rotas noturnas navegaveis da entrada ate o refugio.
	var map: RID = world.get_world_3d().navigation_map
	var target := Vector3(0, 0, -11)
	var routes_ok := true
	for entry in ["RuinEntry", "WestEntry", "EastEntry"]:
		var from: Vector3 = world.get_node("WorldRegions/NightRoutes/" + entry).global_position
		var path := NavigationServer3D.map_get_path(map, from, target, true)
		routes_ok = routes_ok and path.size() > 1 and flat(path[path.size() - 1], target) < 1.0
	check(routes_ok, "[34] As 3 rotas noturnas continuam com caminho ate o refugio")

	# [35–38] valores intactos.
	check(fire.HEAL_AMOUNT == 25.0 and fire.CHANNEL_TIME == 3.0 and fire.RANGE == 2.5 and fire.MAX_CHARGES == 2 and fire.COOLDOWN == 25.0 and Recipes.RECIPES[Recipes.CAMPFIRE].wood == 20 and Recipes.RECIPES[Recipes.CAMPFIRE].stone == 12, "[35] Fogueira: 20/12, +25, 3 s, 2,5 m, 2 cargas, 25 s")
	var Trap := load("res://scenes/world/spike_trap.gd")
	check(Trap.DAMAGE == 15.0 and Trap.MAX_CHARGES == 3 and Recipes.RECIPES[Recipes.TRAP].wood == 15 and Recipes.RECIPES[Recipes.TRAP].stone == 6 and Recipes.RECIPES[Recipes.TRAP].limit == 3, "[36] Armadilha: 15/6, 15 de dano, 3 cargas, maximo 3")
	var tower = world.get_node("DefenseSlots/SlotRuinMeadow").build()
	await frames(2)
	check(tower.stats() == tower.LEVELS[0] and economy.reward_per_wave_enemy == 15, "[37] Torre e recompensa da onda inalteradas")
	var Collect := load("res://scenes/world/collectable_resource.gd")
	check(Collect.KINDS[&"wood"].reward == 10 and Collect.KINDS[&"stone"].reward == 6 and Collect.KINDS[&"wood"].hp == 30.0 and Collect.KINDS[&"stone"].hp == 45.0, "[38] Coleta: arvore +10 (30 HP), pedra +6 (45 HP)")
	var any_tree = null
	for c in get_tree().get_nodes_in_group("collectable"):
		if c.kind == "wood" and not c.depleted:
			any_tree = c
			break
	var wood_before: int = stock.get_amount(&"wood")
	any_tree.take_damage(any_tree.max_hp)
	await frames(2)
	check(stock.get_amount(&"wood") == wood_before + 10, "[38] Coleta real continua +10 Madeira")

	# [39] Spec 014 intacta, e o marco tambem brilha mais a noite.
	var visual = world.get_node("DayNightVisual")
	var day_emit: float = tm.markers[&"west"]._crystal_mat.emission_energy_multiplier
	DayNightManager.state = DayNightManager.State.NIGHT
	DayNightManager.phase_elapsed = 11.25
	visual.snap()
	await frames(2)
	var night_emit: float = tm.markers[&"west"]._crystal_mat.emission_energy_multiplier
	check(visual.sky_material.get_shader_parameter("stars") > 0.99 and visual.night_glow == 1.0 and night_emit > day_emit, "[39] Ciclo visual da 014 intacto; marco visivel a noite (%.2f -> %.2f)" % [day_emit, night_emit])
	DayNightManager.state = DayNightManager.State.DAY
	DayNightManager.phase_elapsed = 10.0
	visual.snap()

	# [25][40] Reiniciar volta ao inicio sem acumular sinais.
	await start()
	check(tm.state_of(&"center") == TM.CONTROLLED and tm.state_of(&"west") == TM.WILD and tm.state_of(&"east") == TM.WILD and tm.markers[&"west"].state == TM.WILD, "[25] Reiniciar: Centro CONTROLLED, Oeste e Leste WILD")
	check(app.territory_text.text == "1/3" and tm.guardians.size() == 2, "[25] Reiniciar: HUD 1/3 e 2 guardioes novos")
	check(placer.validate(Recipes.CAMPFIRE, WEST_SPOT) == "Território selvagem: recupere o marco primeiro", "[25] Reiniciar: Oeste volta a recusar construcao")
	check([dnm.day_started.get_connections().size(), dnm.night_started.get_connections().size()] == signals0, "[40] Reinicios nao acumulam conexoes no DayNightManager")
	await start()
	check([dnm.day_started.get_connections().size(), dnm.night_started.get_connections().size()] == signals0, "[40] Segundo reinicio: mesmas conexoes")

	app.show_menu()
	await frames(3)
	var report_path := "user://territory.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
	var report := FileAccess.open(report_path, FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": passed, "failed": failed, "display": DisplayServer.get_name()}, "  "))
	report.close()
	print("SPEC015 RESULTS: %d passed; %d failed" % [passed.size(), failed.size()])
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)
