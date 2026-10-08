extends Node

# Spec 013C — combate (1 clique = 1 golpe de 15), domesticacao com vida cheia,
# dois dinos diurnos, alcance das torres, coleta de madeira/pedra e economia.
# Cliques REAIS (InputEventMouseButton via viewport). Itens entre colchetes.
const DINO := preload("res://scenes/enemies/wild_dino.tscn")
var passed: Array[String] = []
var failed: Array[String] = []
var app: Node
var world: Node3D
var player: CharacterBody3D
var cam: Camera3D

func check(ok: bool, title: String) -> void:
	(passed if ok else failed).append(title)
	print(("PASS: " if ok else "FAIL: ") + title)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

# Cursor sobre o corpo do alvo e UM clique fisico (pressiona + solta).
func click_on(target: Node3D, height := 0.6) -> void:
	var pos := cam.unproject_position(target.global_position + Vector3(0, height, 0))
	var mv := InputEventMouseMotion.new()
	mv.position = pos
	mv.relative = Vector2(3, 0)
	get_viewport().push_input(mv, true)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		get_viewport().push_input(ev, true)

func ready_to_swing() -> void:
	while not player.attack_cooldown.is_stopped():
		await get_tree().physics_frame

# Vence a noite atual com a onda INTEIRA (a Noite N tem 3 + N - 1 inimigos,
# um a cada 2 s): espera todos nascerem antes de neutraliza-los.
func win_night(wave) -> void:
	while DayNightManager.is_night():
		if wave._spawned_count >= wave.enemy_count:
			for foe in wave._active_wave_enemies.keys(): foe.take_damage(1000)
		await get_tree().physics_frame
	await frames(2)

func place(body: Node3D, offset: Vector3) -> void:
	body.global_position = player.global_position + offset
	if body is CharacterBody3D:
		body.velocity = Vector3.ZERO

func _ready() -> void:
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	app.start_game()
	await get_tree().process_frame
	await get_tree().process_frame
	world = app.world
	player = world.get_node("Player")
	player._invulnerable_left = INF # mede combate/coleta, nao a vida do Player
	cam = player.get_node("StrategicCamera")
	var economy = world.get_node("DefenseEconomy")
	var stock = world.get_node("ResourceStock")
	var spawner = world.get_node("EncounterSpawner")
	var wave = world.get_node("WaveManager")
	for d in spawner.encounters: d.set_physics_process(false)
	var dino = spawner.encounters[0]
	player.global_position = Vector3(0, .1, -2)
	await frames(60) # camera assenta no Player

	# --- Economia inicial [AI]
	check(economy.points == 40 and stock.get_amount(&"wood") == 0 and stock.get_amount(&"stone") == 0, "[AI][AH] Novo jogo: 40 Pontos, 0 Madeira, 0 Pedra")
	# --- Combate [A]-[E]
	check(dino.hp == 80.0 and dino.MAX_HP == 80.0 and player.ATTACK_DAMAGE == 15.0, "[A][D] WildDino 80/80; golpe do Player = 15")
	place(dino, Vector3(1.4, .4, 1.0))
	await frames(3)
	var swings: int = player.attack_count
	click_on(dino)
	await frames(2)
	check(dino.hp == 65.0, "[B] Primeiro clique valido causa dano (80 -> %d)" % dino.hp)
	check(player.attack_count == swings + 1, "[C] Um clique = exatamente um golpe")
	# Clique duplo no mesmo instante: so um golpe
	await ready_to_swing()
	swings = player.attack_count
	click_on(dino)
	click_on(dino)
	await frames(2)
	check(dino.hp == 50.0 and player.attack_count == swings + 1, "[C] Dois cliques no mesmo quadro = um golpe (sem golpe duplo)")
	var seq := [dino.hp]
	for i in 2:
		await ready_to_swing()
		click_on(dino)
		await frames(2)
		seq.append(dino.hp)
	check(seq == [50.0, 35.0, 20.0], "[E] Sequencia 80 -> 65 -> 50 -> 35 -> 20 %s" % [seq])
	# [F] elegivel em 20
	check(dino.can_be_domesticated(), "[F] Em 20/80 continua elegivel para domesticacao")
	# Regressao da CAUSA: clique cedo (dino fora do alcance) + clique no alcance
	var other = DINO.instantiate()
	world.add_child(other)
	other.set_physics_process(false)
	place(other, Vector3(-3.4, .4, 0)) # fora do alcance (~3,4 m)
	await ready_to_swing()
	await frames(3)
	swings = player.attack_count
	click_on(other)
	await frames(2)
	check(other.hp == 80.0 and player.attack_cooldown.time_left <= player.WHIFF_COOLDOWN + .01, "Golpe no vazio: sem dano e recuperacao curta (%.2f s)" % player.attack_cooldown.time_left)
	place(other, Vector3(-1.6, .4, 0)) # o dino chega
	await frames(3)
	click_on(other) # clique ainda durante a recuperacao: guardado, nao perdido
	await wait(.5)
	check(other.hp == 65.0 and player.attack_count == swings + 2, "Clique logo apos um golpe no vazio nao se perde: 2 cliques = 2 golpes, 1 dano")
	# [I] o golpe segue o cursor (alvo a esquerda, mira no corpo)
	var yaw_err := absf(rad_to_deg(angle_difference(player.last_attack_yaw, atan2(-(other.global_position.x - player.global_position.x), -(other.global_position.z - player.global_position.z)))))
	check(yaw_err < 8.0, "[I] O golpe sai na direcao do alvo sob o cursor (erro %.1f graus)" % yaw_err)
	other.queue_free()
	# [G] domesticacao pelo canal real (E por 2 s) restaura 80/80
	place(dino, Vector3(1.4, .4, 1.0))
	Input.action_press("domesticate")
	var e := InputEventKey.new()
	e.physical_keycode = KEY_E
	e.keycode = KEY_E
	e.pressed = true
	Input.parse_input_event(e)
	await wait(2.3)
	Input.action_release("domesticate")
	e.pressed = false
	Input.parse_input_event(e)
	check(dino.is_domesticated and dino.hp == 80.0, "[G] Domesticacao completa: 20/80 -> %d/80" % dino.hp)
	dino.take_damage(15)
	check(dino.hp == 65.0, "[H] Aliado volta a perder vida normalmente (80 -> 65)")
	# [J] WASD continua orientando o visual
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	await frames(40)
	key.pressed = false
	Input.parse_input_event(key)
	var fwd: Vector3 = -player.get_node("Visual").global_basis.z
	check(fwd.normalized().dot(cam.planar_direction(Vector3(1, 0, 0))) > .98, "[J] WASD continua controlando a orientacao visual")

	# --- Dinos diurnos [K]-[Q]
	var wild2 = spawner.encounters[1]
	check(spawner.encounters.size() == 2 and spawner._is_wild(wild2), "[K] Dois encontros selvagens diurnos (o 2o ainda selvagem)")
	check(flat(spawner.spawn_points()[0], spawner.spawn_points()[1]) > 15.0 and flat(dino.home_position, wild2.home_position) > 15.0, "[L] Encontros em regioes diferentes, nao sobrepostos (%.1f m)" % flat(dino.home_position, wild2.home_position))
	check(wild2.territorial and wild2.is_domesticable and not wild2.is_in_group("wave_enemy"), "[O] 2o encontro: territorial, domesticavel, fora da onda")
	player.global_position = wild2.global_position + Vector3(0, .1, -1.6)
	await frames(40)
	await ready_to_swing()
	click_on(wild2)
	await frames(2)
	check(wild2.hp == 65.0, "[M] 2o encontro pode ser atacado (80 -> 65)")
	wild2.hp = 20.0
	wild2.domesticate()
	check(wild2.is_domesticated and wild2.hp == 80.0, "[N] 2o encontro pode ser domesticado (vida cheia)")
	# Amanhecer repoe os dois pontos, sem duplicar
	var points_before: int = economy.points
	DayNightManager.start_night()
	await wait(4.5)
	var in_wave := false
	for foe in wave._active_wave_enemies.keys(): in_wave = in_wave or spawner.encounters.has(foe)
	check(wave._active_wave_enemies.size() == 3 and not in_wave, "[O] Noite 1 com 3 inimigos de onda; nenhum e encontro diurno")
	await win_night(wave)
	check(DayNightManager.is_day() and economy.points == points_before + 45, "[P][AK] Onda vencida (+3 x 15) sem depender dos encontros diurnos")
	var wild_now: Array = spawner.wild_encounters()
	check(wild_now.size() == 2, "Amanhecer repoe 2 encontros selvagens (aliados mantidos)")
	DayNightManager.start_night()
	await win_night(wave)
	var all_wild := get_tree().get_nodes_in_group("wild_dino").filter(func(d): return d.territorial)
	check(spawner.wild_encounters().size() == 2 and all_wild.size() == 2, "Novo amanhecer nao duplica encontros (%d territoriais)" % all_wild.size())
	# [Q][AL] morte de selvagem diurno nao paga
	points_before = economy.points
	for d in spawner.wild_encounters(): d.take_damage(1000)
	await frames(2)
	check(economy.points == points_before, "[Q][AL] Selvagens diurnos mortos nao concedem Pontos de Defesa")

	# --- Torre [R]-[W]
	var slots = world.get_node("DefenseSlots")
	var slot = world.get_node("DefenseSlots/SlotRuinMeadow")
	player.global_position = slot.global_position + Vector3(0, .1, 1.8)
	await frames(10)
	check(slot.preview_ring.radius == slot.DefenseTower.LEVELS[0].range and slot.preview_ring.radius == 8.0, "[V] Previa do ponto vazio usa 8 m (mesmo valor da tabela)")
	await wait(.4)
	check(slot.preview_ring.visible, "[V] Previa visivel ao considerar construir aqui")
	economy.add_points(200)
	var spent_before: int = economy.points
	check(slots.interact(slot) and economy.points == spent_before - 30, "[AJ] Torre continua custando 30")
	var tower = slot.tower
	var radii := []
	for lvl in 3:
		radii.append([tower.stats().range, tower.range_ring.radius])
		if lvl < 2: slots.interact(slot)
	check(radii == [[8.0, 8.0], [9.0, 9.0], [10.0, 10.0]], "[R][S][T][U] Alcance L1/L2/L3 = 8/9/10 e o anel usa o mesmo valor %s" % [radii])
	await wait(.4)
	check(tower.range_ring.visible and not slot.preview_ring.visible, "Anel da torre visivel de perto; previa some depois de construir")
	# [W] aquisicao no limite do alcance (L3 = 10 m)
	DayNightManager.start_night()
	await wait(.3)
	var foes: Array = wave._active_wave_enemies.keys()
	for f in foes:
		f.set_physics_process(false)
		f.global_position = Vector3(0, .5, 40)
	var probe = foes[0]
	probe.global_position = tower.global_position + Vector3(10.4, .3, 0)
	await wait(.5)
	var outside: bool = tower.target == null and probe.hp == 80.0
	probe.global_position = tower.global_position + Vector3(9.6, .3, 0)
	await wait(.9)
	check(outside and tower.target == probe and probe.hp < 80.0, "[W] Torre adquire alvo a 9,6 m e ignora a 10,4 m (L3)")
	await win_night(wave)

	# --- Recursos [X]-[AH], [AM][AN]
	var trees := []
	var stones := []
	for c in world.get_node("Collectables").get_children():
		(trees if c.kind == "wood" else stones).append(c)
	check(trees.size() == 8 and stones.size() == 6, "8 arvores e 6 pedras coletaveis")
	var tree = trees[0]
	check(tree.hp == 30.0 and tree.max_hp == 30.0, "[X] Arvore = 30 HP")
	var pts: int = economy.points
	# fora do alcance nao coleta
	player.global_position = tree.global_position + Vector3(0, .1, 6)
	await frames(40)
	await ready_to_swing()
	click_on(tree, 1.2)
	await frames(2)
	check(tree.hp == 30.0, "Arvore a 6 m: o golpe nao alcanca")
	player.global_position = tree.global_position + Vector3(0, .1, 1.5)
	await frames(40)
	await ready_to_swing()
	swings = player.attack_count
	click_on(tree, 1.2)
	await frames(2)
	var tree_after_one: float = tree.hp
	await ready_to_swing()
	click_on(tree, 1.2)
	await frames(2)
	check(tree_after_one == 15.0 and tree.depleted and player.attack_count == swings + 2, "[Y] Arvore: 2 golpes de 15 (30 -> 15 -> 0)")
	check(stock.get_amount(&"wood") == 10, "[Z] Arvore concede +10 Madeira")
	tree.take_damage(15)
	tree.take_damage(15)
	await frames(2)
	check(stock.get_amount(&"wood") == 10 and tree.collision_layer == 0, "[AD] Arvore esgotada nao paga de novo e deixa de ser solida")
	var gains: Array = app.hud.get_children().filter(func(c): return String(c.name).begins_with("WoodGain"))
	check(not gains.is_empty() and gains[0].text == "+10 MADEIRA" and app.wood_text.text == "10", "HUD: '+10 MADEIRA' e Madeira 10")
	var stone = stones[0]
	check(stone.hp == 45.0, "[AA] Pedra = 45 HP")
	player.global_position = stone.global_position + Vector3(0, .1, 1.9)
	await frames(40)
	var hps := []
	for i in 3:
		await ready_to_swing()
		click_on(stone, .6)
		await frames(2)
		hps.append(stone.hp)
	check(hps == [30.0, 15.0, 0.0] and stone.depleted, "[AB] Pedra: 3 golpes (45 -> 30 -> 15 -> 0) %s" % [hps])
	stone.take_damage(15)
	check(stock.get_amount(&"stone") == 6, "[AC][AD] Pedra concede +6 Pedra uma unica vez")
	check(economy.points == pts, "[AE][AM][AN] Arvore e pedra nao concedem Pontos de Defesa")
	# [AF] voltam no proximo amanhecer; [AG] estoque persiste
	DayNightManager.start_night()
	await wait(.3)
	check(tree.depleted and stone.depleted, "Recursos continuam esgotados durante a noite")
	await win_night(wave)
	await frames(2)
	check(DayNightManager.is_day() and not tree.depleted and tree.hp == 30.0 and tree.collision_layer != 0 and not stone.depleted and stone.hp == 45.0, "[AF] Arvore e pedra voltam no amanhecer (mesmos nos)")
	check(world.get_node("Collectables").get_child_count() == 14, "Restauracao reutiliza os mesmos nos (14, sem duplicar)")
	check(stock.get_amount(&"wood") == 10 and stock.get_amount(&"stone") == 6, "[AG] Madeira e Pedra persistem entre dias")
	# Navegacao: recursos fora das trilhas e com obstaculo de avoidance
	var regions: Node = world.get_node("WorldRegions")
	var on_trail := []
	for c in trees + stones:
		var p := Vector2(c.global_position.x, c.global_position.z)
		for trail in regions.get_node("NightRoutes").get_children() + [regions.get_node("WildZone/GladeTrail"), regions.get_node("WildZone/HeathTrail")]:
			for stretch in trail.get_children():
				if not String(stretch.name).begins_with("Stretch"): continue
				var faces: PackedVector3Array = stretch.mesh.get_faces()
				for fi in range(0, faces.size(), 3):
					if Geometry2D.point_is_inside_triangle(p, Vector2(faces[fi].x, faces[fi].z), Vector2(faces[fi+1].x, faces[fi+1].z), Vector2(faces[fi+2].x, faces[fi+2].z)):
						on_trail.append(c.name)
	check(on_trail.is_empty(), "Recursos fora das trilhas e rotas noturnas %s" % [on_trail])
	# [AH] Reiniciar zera recursos
	app.start_game()
	await get_tree().process_frame
	await get_tree().process_frame
	var fresh: Node3D = app.world
	check(fresh.get_node("ResourceStock").get_amount(&"wood") == 0 and fresh.get_node("ResourceStock").get_amount(&"stone") == 0 and fresh.get_node("DefenseEconomy").points == 40, "[AH] Reiniciar: Madeira 0, Pedra 0, 40 Pontos")

	app.show_menu()
	await get_tree().process_frame
	var report := {"passed": passed, "failed": failed, "display": DisplayServer.get_name()}
	var destination := "user://spec013c.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): destination = argument.trim_prefix("--report=")
	var file := FileAccess.open(destination, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("SPEC013C RESULTS: %d passed; %d failed" % [passed.size(), failed.size()])
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)
