extends Node

# Spec 022 — tutorial jogavel. Roda o jogo real (main.tscn): cada etapa so
# avanca com a acao real (golpe, dano, domesticacao, coleta, inventario,
# construcao, torre, F no aliado, noite vencida). Confere tambem o isolamento
# (partida normal sem diretor, relogio solto ao sair, 3 inimigos na Noite 1,
# guardiao da Regiao Rochosa presente) e que nada trava se o selvagem, o
# aliado ou o jogador cairem.
# Uso: Godot [--headless] --path . res://tests/tutorial.tscn [-- --report=<arquivo>]
const Director := preload("res://scenes/world/tutorial_director.gd")
const Recipes := preload("res://scenes/world/build_recipes.gd")
var passed: Array[String] = []
var failed: Array[String] = []
var app
var world: Node3D
var tut

func check(ok: bool, label: String) -> void:
	(passed if ok else failed).append(label)
	print(("PASS: " if ok else "FAIL: ") + label)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func step_is(s: int) -> bool:
	return is_instance_valid(tut) and tut.step == s

## Espera ate `frames_max` quadros pelo passo `s`.
func until_step(s: int, frames_max := 90) -> bool:
	for i in frames_max:
		if step_is(s):
			return true
		await get_tree().physics_frame
	return step_is(s)

func player():
	return world.get_node("Player")

func begin_tutorial() -> void:
	app.start_tutorial()
	world = app.world
	tut = world.get_node("Tutorial")
	await frames(6)

func _ready() -> void:
	var report := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report = arg.trim_prefix("--report=")
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame

	# --- Partida normal: sem diretor, relogio andando, 3 inimigos, 2 guardioes ---
	app.start_game()
	await frames(8)
	world = app.world
	var t0: float = DayNightManager.phase_elapsed
	await frames(30)
	check(not world.has_node("Tutorial") and not DayNightManager.clock_hold and DayNightManager.phase_elapsed > t0, "Partida normal: sem tutorial e relogio andando")
	check(world.get_node("WaveManager").enemy_count_for_night(1) == 3 and world.get_node("TerritoryManager").guardians.has(&"east"), "Partida normal: Noite 1 com 3 inimigos e guardiao da Regiao Rochosa")

	# --- Tutorial: instancia isolada ---
	await begin_tutorial()
	var held: float = DayNightManager.phase_elapsed
	await frames(40)
	check(is_instance_valid(tut) and DayNightManager.clock_hold and DayNightManager.phase_elapsed == held, "Tutorial: relogio segurado (%.2f s)" % DayNightManager.phase_elapsed)
	check(world.get_node("WaveManager").enemy_count_for_night(1) == 2, "Tutorial: primeira noite com 2 inimigos")
	check(not world.get_node("TerritoryManager").guardians.has(&"east") and tut.target != null and tut.target.guardian_of != "", "Tutorial: sem guardiao rochoso; alvo = guardiao da Floresta Oeste")
	check(app.hud.has_node("TutorialCard") and app.hud.objective_override.begins_with("TUTORIAL"), "Painel do tutorial e objetivo na HUD")
	check(step_is(Director.Step.MOVE), "Passo 1: andar")
	await frames(30)
	check(step_is(Director.Step.MOVE), "Sem andar, o passo 1 nao avanca sozinho")
	player().global_position += Vector3(3.0, 0, 0)
	check(await until_step(Director.Step.WALK), "Andar 3 m conclui o passo 1")
	player().global_position = Director.WALK_POINT + Vector3(0, 0.1, 0)
	check(await until_step(Director.Step.ATTACK), "Chegar ao sinal jade conclui o passo 2")
	await frames(20)
	check(step_is(Director.Step.ATTACK), "Sem golpe novo, o passo 3 nao avanca")
	player()._try_attack()
	check(await until_step(Director.Step.WEAKEN), "Um golpe real conclui o passo 3")

	# --- enfraquecer / domesticar (com queda do selvagem no meio) ---
	var first = tut.target
	first.set_physics_process(false)
	first.take_damage(80.0) # derrotado em vez de enfraquecido
	await frames(4)
	check(step_is(Director.Step.WEAKEN) and is_instance_valid(tut.target) and tut.target != first and tut.note != "", "Selvagem derrotado: outro aparece, sem travar")
	var dino = tut.target
	dino.set_physics_process(false)
	dino.take_damage(15.0)
	await frames(4)
	check(step_is(Director.Step.WEAKEN), "Um golpe so (65/80) ainda nao conclui o passo 4")
	dino.take_damage(45.0) # 20/80: elegivel
	check(await until_step(Director.Step.TAME), "Vida baixa (20/80) conclui o passo 4")
	dino.domesticate()
	check(await until_step(Director.Step.WOOD), "Domesticar conclui o passo 5")
	var hp_before: float = dino.hp
	check(dino.is_domesticated and hp_before == 80.0, "Domesticacao igual a partida normal (vida cheia)")

	# --- coleta: golpes reais nos coletaveis ---
	var stock = world.get_node("ResourceStock")
	var trees := get_tree().get_nodes_in_group("collectable").filter(func(c): return c.kind == "wood")
	var stones := get_tree().get_nodes_in_group("collectable").filter(func(c): return c.kind == "stone")
	trees[0].take_damage(30.0)
	await frames(3)
	check(step_is(Director.Step.WOOD) and stock.get_amount(&"wood") == 10, "10/20 Madeira: passo 6 continua")
	trees[1].take_damage(30.0)
	check(await until_step(Director.Step.STONE), "20 Madeira coletadas conclui o passo 6")
	stones[0].take_damage(45.0)
	stones[1].take_damage(45.0)
	check(await until_step(Director.Step.INVENTORY), "12 Pedra coletadas conclui o passo 7")
	app.toggle_inventory()
	check(await until_step(Director.Step.CAMPFIRE), "Abrir o inventario conclui o passo 8")
	app.toggle_inventory()

	# --- jogador cai no meio do tutorial: nada trava ---
	player().take_damage(999.0)
	await frames(10)
	check(step_is(Director.Step.CAMPFIRE), "Jogador caido: o tutorial continua no mesmo passo")
	await frames(60 * 3)
	check(not player().is_invulnerable() or player().current_hp > 0.0, "Jogador volta (respawn normal)")

	# --- construcao real da Fogueira ---
	var placer = world.get_node("BuildPlacer")
	player().global_position = Vector3(4.0, 0.1, -10.0)
	placer.begin(Recipes.CAMPFIRE)
	placer.follow_cursor = false
	placer.move_ghost_to(Vector3(5.0, 0, -12.5))
	await frames(2)
	placer.confirm()
	check(await until_step(Director.Step.TOWER), "Fogueira construida conclui o passo 9")
	var slots = world.get_node("DefenseSlots")
	var slot = slots.get_node("SlotRuinMeadow")
	player().global_position = slot.global_position + Vector3(1.2, 0.1, 0)
	await frames(3)
	slots.interact(slot)
	check(await until_step(Director.Step.ALLY), "Torre erguida conclui o passo 10")

	# --- aliado cai antes de ficar de guarda: novo selvagem, e volta ao passo 11 ---
	dino.take_damage(200.0)
	await frames(4)
	check(step_is(Director.Step.WEAKEN) and tut.target != dino, "Aliado caido: volta a enfraquecer outro selvagem")
	var second = tut.target
	second.set_physics_process(false)
	second.take_damage(60.0)
	await until_step(Director.Step.TAME)
	second.domesticate()
	check(await until_step(Director.Step.ALLY), "Depois de domesticar de novo, volta direto ao passo 11 (nao repete a coleta)")
	second.set_physics_process(true)
	player().global_position = second.global_position + Vector3(1.0, 0.1, 0)
	await frames(2)
	Input.action_press("command_stay")
	await frames(2)
	Input.action_release("command_stay")
	check(await until_step(Director.Step.NIGHT), "F no aliado (FICAR) conclui o passo 11")

	# --- noite do tutorial: 2 invasores ---
	await frames(5)
	check(DayNightManager.is_night() and not DayNightManager.clock_hold, "Noite do tutorial: relogio solto")
	var waves = world.get_node("WaveManager")
	check(waves.enemy_count == 2, "Noite do tutorial com 2 inimigos (%d)" % waves.enemy_count)
	for i in 600:
		for foe in waves._active_wave_enemies.keys():
			if is_instance_valid(foe) and foe.hp > 0.0:
				foe.take_damage(200.0)
		if step_is(Director.Step.DONE):
			break
		await get_tree().physics_frame
	check(step_is(Director.Step.DONE) and app.screen == "tutorial_done", "Noite vencida: tutorial concluido")

	# --- sair e voltar ao jogo normal: nada fica preso ---
	app.show_menu()
	await frames(3)
	check(not DayNightManager.clock_hold and not app.tutorial_mode, "Sair do tutorial solta o relogio")
	app.start_game()
	await frames(8)
	world = app.world
	var n0: float = DayNightManager.phase_elapsed
	await frames(30)
	check(not world.has_node("Tutorial") and DayNightManager.phase_elapsed > n0 and world.get_node("WaveManager").enemy_count_for_night(1) == 3, "Depois do tutorial: partida normal, relogio andando, 3 inimigos")

	# --- reiniciar o tutorial pela pausa ---
	await begin_tutorial()
	player().global_position += Vector3(3.0, 0, 0)
	await until_step(Director.Step.WALK)
	app.pause_game()
	app.restart()
	world = app.world
	tut = world.get_node("Tutorial")
	await frames(6)
	check(app.tutorial_mode and step_is(Director.Step.MOVE) and DayNightManager.clock_hold and not get_tree().paused, "Reiniciar repete o tutorial do passo 1")
	app.pause_game()
	app.show_menu()
	await frames(3)
	check(app.screen == "menu" and not DayNightManager.clock_hold, "Sair pela pausa volta ao menu")

	print("TUTORIAL RESULTS: %d passed; %d failed" % [passed.size(), failed.size()])
	if report != "":
		var f := FileAccess.open(report, FileAccess.WRITE)
		f.store_string(JSON.stringify({"passed": passed, "failed": failed}, "\t"))
		f.close()
	get_tree().quit(0 if failed.is_empty() else 1)
