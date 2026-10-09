extends Node

# Bug do playtest (09/10/2026): "o aliado nao causa dano aos inimigos".
# Jogo real (main.tscn). Torres ausentes e jogador invulneravel e parado: toda
# perda de vida dos hostis vem dos aliados. Conferido em SEGUIR e FICAR, alvo
# fora do alcance, troca de alvo, 2 aliados x 3 inimigos, cooldown, ausencia de
# fogo amigo e recompensa da onda preservada.
# Uso: Godot [--headless] --path . res://tests/ally_combat.tscn [-- --report=<arquivo>]
const WILD := preload("res://scenes/enemies/wild_dino.tscn")
var passed: Array[String] = []
var failed: Array[String] = []
var app
var world: Node3D
var player

func check(ok: bool, label: String) -> void:
	(passed if ok else failed).append(label)
	print(("PASS: " if ok else "FAIL: ") + label)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func fresh_game() -> void:
	app.start_game()
	await frames(8)
	world = app.world
	player = world.get_node("Player")
	player._invulnerable_left = INF
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	# Encontros diurnos fora do caminho (nao interferem).
	for d in world.get_node("EncounterSpawner").encounters:
		if is_instance_valid(d):
			d.queue_free()
	await frames(2)

func make_ally(pos: Vector3, stay: bool):
	var d = WILD.instantiate()
	world.add_child(d)
	d.global_position = pos
	d.domesticate()
	if stay:
		d.ally_state = 1 # AllyState.STAYING
		d._stay_position = pos
	return d

func hostile(pos: Vector3, wave := false):
	var d = WILD.instantiate()
	world.add_child(d)
	d.global_position = pos
	if wave:
		d.add_to_group("wave_enemy")
		d.get_node("Visual").set_night_threat()
	return d

## Quadros ate o hostil perder vida (ou o limite).
func until_hurt(foe, limit: int) -> int:
	for i in limit:
		if not is_instance_valid(foe) or foe.hp < 80.0:
			return i
		await get_tree().physics_frame
	return limit

func _ready() -> void:
	var report := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report = arg.trim_prefix("--report=")
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame

	# 1. FICAR contra um inimigo noturno que entra no raio de defesa.
	await fresh_game()
	player.global_position = Vector3(0, 0.1, -16)
	var stay = make_ally(Vector3(-4, 0.5, -2), true)
	var foe = hostile(Vector3(-4, 0.5, 4), true)
	var t := await until_hurt(foe, 360)
	check(is_instance_valid(foe) and foe.hp < 80.0, "FICAR: aliado causa dano real a um inimigo noturno (%d quadros)" % t)

	# 2. SEGUIR: um hostil ataca o jogador/aliado; o aliado seguindo reage.
	await fresh_game()
	player.global_position = Vector3(0, 0.1, -4)
	var follower = make_ally(Vector3(1.5, 0.5, -4), false)
	await frames(30)
	var foe2 = hostile(Vector3(0, 0.5, 2), true)
	t = await until_hurt(foe2, 360)
	check(is_instance_valid(foe2) and foe2.hp < 80.0, "SEGUIR: aliado ataca a ameaca perto do jogador (%d quadros)" % t)
	check(follower.ally_state == 0, "SEGUIR continua SEGUIR depois de lutar (estado preservado)")

	# 2b. Selvagem comum (fora da onda) atacando o jogador: o aliado ajuda a
	# enfraquecer, mas para no limiar da domesticacao (nunca o mata).
	await fresh_game()
	player.global_position = Vector3(0, 0.1, -4)
	var helper = make_ally(Vector3(1.5, 0.5, -4), false)
	await frames(30)
	var wild = hostile(Vector3(0, 0.5, 1), false)
	for i in 60 * 10:
		if not is_instance_valid(wild) or wild.hp <= 20.0:
			break
		await get_tree().physics_frame
	await frames(120)
	check(is_instance_valid(wild) and wild.hp == 20.0 and wild.can_be_domesticated(), "Aliado enfraquece o selvagem ate 20 HP e nao o mata (domesticavel)")

	# 3. Alvo fora do alcance: FICAR nao abandona o posto para cacar longe.
	await fresh_game()
	player.global_position = Vector3(0, 0.1, -16)
	var guard = make_ally(Vector3(-10, 0.5, -5), true)
	var far = hostile(Vector3(12, 0.5, 18), false)
	far.territorial = true
	far.home_position = far.global_position
	await frames(180)
	check(far.hp == 80.0 and guard.global_position.distance_to(Vector3(-10, 0.5, -5)) < 1.5, "Alvo fora do raio: sem dano e aliado no posto")

	# 4. Alvo eliminado -> troca para o proximo.
	await fresh_game()
	player.global_position = Vector3(0, 0.1, -16)
	var duo = make_ally(Vector3(0, 0.5, -3), true)
	var a1 = hostile(Vector3(-1.5, 0.5, -1), true)
	var a2 = hostile(Vector3(2.0, 0.5, 1), true)
	a1.hp = 15.0
	for i in 600:
		if not is_instance_valid(a1) and is_instance_valid(a2) and a2.hp < 80.0:
			break
		await get_tree().physics_frame
	check(not is_instance_valid(a1) and is_instance_valid(a2) and a2.hp < 80.0, "Alvo eliminado: o aliado troca para o proximo inimigo")


	# 5. Dois aliados x dois inimigos da noite: vencem e a recompensa da onda sai.
	await fresh_game()
	player.global_position = Vector3(0, 0.1, -14)
	var allies := [make_ally(Vector3(-2, 0.5, -6), true), make_ally(Vector3(2, 0.5, -6), true)]
	DayNightManager.state = DayNightManager.State.NIGHT
	var economy = world.get_node("DefenseEconomy")
	var points0: int = economy.points
	var wave = world.get_node("WaveManager")
	var pair := [hostile(Vector3(-2, 0.5, -2), true), hostile(Vector3(2, 0.5, -2), true)]
	for f in pair:
		wave._active_wave_enemies[f] = true
		f.died.connect(wave._neutralize_wave_enemy.bind("morreu"))
	for i in 60 * 20:
		if pair.all(func(f): return not is_instance_valid(f)):
			break
		await get_tree().physics_frame
	check(pair.all(func(f): return not is_instance_valid(f)), "2 aliados x 2 inimigos da noite: os aliados vencem")
	check(economy.points > points0, "Inimigo da onda eliminado por aliado paga a recompensa (%d -> %d)" % [points0, economy.points])
	check(allies.any(func(a): return is_instance_valid(a) and a.is_in_group("domesticated")), "Pelo menos um aliado sobrevive e segue aliado")

	# 5b. Dois aliados x tres inimigos: dividem os alvos (nao ficam todos num so).
	await fresh_game()
	player.global_position = Vector3(0, 0.1, -14)
	allies = [make_ally(Vector3(-3, 0.5, -6), true), make_ally(Vector3(3, 0.5, -6), true)]
	DayNightManager.state = DayNightManager.State.NIGHT
	var trio := [hostile(Vector3(-3, 0.5, -2), true), hostile(Vector3(3, 0.5, -2), true), hostile(Vector3(0, 0.5, 0), true)]
	var hurt := {}
	for i in 60 * 8:
		for f in trio:
			if not is_instance_valid(f) or f.hp < 80.0:
				hurt[f] = true
		await get_tree().physics_frame
	check(hurt.size() >= 2, "2 aliados x 3 inimigos: ferem inimigos diferentes (%d/3)" % hurt.size())

	# 6. Cooldown: um golpe por segundo (dano 15).
	await fresh_game()
	player.global_position = Vector3(0, 0.1, -16)
	var hitter = make_ally(Vector3(0, 0.5, -3), true)
	var bag = hostile(Vector3(0, 0.5, -1.6), false)
	bag.set_physics_process(false) # parado ao alcance: so conta golpes
	bag.hp = 1000.0
	await frames(30)
	var h0: float = bag.hp
	await frames(60 * 3)
	var hits := int(round((h0 - bag.hp) / 20.0)) # golpe do aliado: 20
	check(hits >= 2 and hits <= 4, "Cooldown de 1 s respeitado (%d golpes em 3 s)" % hits)

	# 7. Sem fogo amigo: aliados, jogador e Refugio intactos sem hostis.
	await fresh_game()
	player._invulnerable_left = 0.0
	player.global_position = Vector3(0, 0.1, -6)
	var b1 = make_ally(Vector3(1, 0.5, -6), false)
	var b2 = make_ally(Vector3(-1, 0.5, -6), true)
	var base = world.get_node("Territory")
	await frames(60 * 3)
	check(b1.hp == 80.0 and b2.hp == 80.0 and player.current_hp == player.max_hp and base.health == base.max_health, "Sem fogo amigo (aliados, jogador e Refugio intactos)")
	check(not b1._target is Node or b1._target == null, "Aliado nao mira jogador nem aliados")

	print("ALLY RESULTS: %d passed; %d failed" % [passed.size(), failed.size()])
	if report != "":
		var f := FileAccess.open(report, FileAccess.WRITE)
		f.store_string(JSON.stringify({"passed": passed, "failed": failed}, "\t"))
		f.close()
	get_tree().quit(0 if failed.is_empty() else 1)
