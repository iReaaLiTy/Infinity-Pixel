extends Node

# Spec 011 — HP, dano, morte, respawn e HUD do Player, na cena real do jogo.
# Usa o contrato take_damage, a IA real do WildDino e a HUD real de main.gd.
const DINO := preload("res://scenes/enemies/wild_dino.tscn")
const CARNO := preload("res://scenes/enemies/carnotauro.tscn")
var passed: Array[String] = []
var failed: Array[String] = []
var app: Node
var world: Node3D
var player: CharacterBody3D
var died_count := 0
var respawned_count := 0
var died_at := 0
var respawned_at := 0

func check(ok: bool, title: String) -> void:
	(passed if ok else failed).append(title)
	print(("PASS: " if ok else "FAIL: ") + title)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

# Timer que roda mesmo com a arvore pausada (o teste e PROCESS_MODE_ALWAYS).
func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func key_e(pressed: bool) -> void:
	if pressed: Input.action_press("domesticate")
	else: Input.action_release("domesticate")
	key(KEY_E, pressed)

func hud_synced(hp: int) -> bool:
	return app.player_text.text == "JOGADOR  %d / 100" % hp and is_equal_approx(app.player_bar.value, player.current_hp) \
		and is_equal_approx(app.player_bar.max_value, 100.0)

func place_near_player(body: Node3D, offset: Vector3) -> void:
	body.global_position = player.global_position + offset
	body.velocity = Vector3.ZERO

func _ready() -> void:
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	app.start_game()
	await frames(5)
	world = app.world
	player = world.get_node("Player")
	# Esta suite gira o Player a mao para atacar (vida/respawn, nao a mira). Com
	# janela, o cursor real sobre o jogo ativaria a mira continua e mudaria a
	# rotacao no meio do teste. A mira por clique e coberta por combat_collect.
	player.set_process_unhandled_input(false)
	player._aim_active = false
	var spawn: Vector3 = world.get_node("PlayerSpawn").global_position
	var camera: Camera3D = player.get_node("StrategicCamera")
	var channel = player.get_node("DomesticationChannel")
	var base = world.get_node("Territory")
	var encounter = world.get_node("EncounterSpawner").current_encounter
	encounter.set_physics_process(false) # parado: so serve de alvo de ataque/domesticacao
	player.died.connect(func(): died_count += 1; died_at = Engine.get_physics_frames())
	player.respawned.connect(func(): respawned_count += 1; respawned_at = Engine.get_physics_frames())

	# --- HP e HUD inicial
	check(player.max_hp == 100.0 and player.current_hp == 100.0, "HP inicial 100/100")
	check(hud_synced(100), "HUD mostra JOGADOR 100 / 100 com barra sincronizada")
	await frames(2)
	await get_tree().process_frame # a HUD do refugio atualiza em _process
	await get_tree().process_frame
	check(app.base_text.text == "REFÚGIO  100 / 100", "REFÚGIO 100 / 100 distinto do jogador")
	check(player.is_in_group("damageable") and player.has_method("take_damage"), "Player segue o contrato damageable/take_damage (ADR 0001)")

	# --- Dano e invulnerabilidade
	player.take_damage(15)
	check(player.current_hp == 85.0, "take_damage(15) reduz para 85")
	check(hud_synced(85), "HUD atualiza imediatamente apos dano")
	player.take_damage(15)
	player.take_damage(15)
	check(player.current_hp == 85.0, "Hits dentro da janela (1,0 s; era 0,6 s antes do balanceamento) sao ignorados")
	await wait(.3)
	player.take_damage(15)
	check(player.current_hp == 85.0, "Hit a 0,3 s ainda ignorado")
	await wait(.8) # balanceamento: janela de 1,0 s (era .4 com 0,6 s)
	player.take_damage(15)
	check(player.current_hp == 70.0, "Hit apos a janela volta a causar dano")
	await wait(1.1) # sai da janela de 1,0 s (era .7 com 0,6 s)
	for bad in [0.0, -10.0, NAN, INF]:
		player.take_damage(bad)
	check(player.current_hp == 70.0 and not player.is_invulnerable(), "Dano zero/negativo/NaN/infinito ignorado sem abrir janela")
	# Tres "criaturas" no mesmo quadro: so o primeiro hit vale.
	for i in 3:
		player.take_damage(15)
	check(player.current_hp == 55.0, "Tres hits simultaneos aplicam um so")
	await wait(.7)

	# --- Dano real do WildDino (IA, alcance e cooldown atuais)
	player.global_position = spawn + Vector3(6, 0, 4)
	var attacker = DINO.instantiate()
	world.add_child(attacker)
	place_near_player(attacker, Vector3(1.4, -.5, 0))
	var before: float = player.current_hp
	await wait(1.4)
	var real_loss: float = before - player.current_hp
	check(is_equal_approx(fmod(real_loss, 15.0), 0.0) and real_loss >= 15.0, "WildDino real causa 15 de dano de dia (valor preservado)")
	attacker.queue_free()
	await wait(.7)

	# --- Domesticacao em andamento + morte
	player.global_position = spawn + Vector3(6, 0, 4)
	encounter.hp = 20.0
	encounter._update_label()
	place_near_player(encounter, Vector3(1.5, -.5, 0))
	await frames(2)
	key_e(true)
	await wait(.6)
	check(channel.get_progress() > .1 and encounter.is_being_domesticated, "Canalizacao em andamento antes da morte")
	player.take_damage(1000)
	check(player.current_hp == 0.0 and player.is_dead, "HP chega a 0 sem ficar negativo e Player morre")
	check(died_count == 1, "Sinal died emitido uma vez")
	check(channel.get_progress() == 0.0 and not encounter.is_being_domesticated and encounter.is_in_group("wild_dino"), "Morte cancela a domesticacao sem domesticar")
	check(hud_synced(0), "HUD mostra JOGADOR 0 / 100 na morte")
	check(is_instance_valid(app.death_toast) and app.death_text.text.begins_with("VOCÊ CAIU"), "Aviso discreto de morte aparece")
	check(app.overlay == null and not get_tree().paused and app.screen == "playing", "Morte nao abre modal nem pausa")
	await wait(.4)
	check(channel.get_progress() == 0.0, "Morto nao inicia domesticacao (E segurado)")
	key_e(false)
	player.take_damage(50)
	player._die()
	check(died_count == 1 and player.current_hp == 0.0, "Morto nao recebe dano nem morre de novo")
	check(not player.is_in_group("player") and player.collision_layer == 0, "Morto sai do grupo player e nao e corpo solido")
	var dead_pos := player.global_position
	key(KEY_W, true)
	await frames(15)
	key(KEY_W, false)
	check(player.global_position.distance_to(dead_pos) < .01, "Morto nao anda")
	var enc_hp: float = encounter.hp
	place_near_player(encounter, Vector3(0, -.5, -1.2))
	player.rotation.y = 0
	await frames(3)
	player._try_attack()
	check(encounter.hp == enc_hp and player.attack_cooldown.is_stopped(), "Morto nao ataca")
	# Inimigo de onda perto do corpo troca de alvo (vai ao refugio).
	var hunter = DINO.instantiate()
	world.add_child(hunter)
	place_near_player(hunter, Vector3(-1.5, -.5, 0))
	await wait(.4)
	check(hunter._target != player, "IA nao fica mirando o Player morto")
	hunter.queue_free()
	await wait(.3)
	check(died_count == 1 and respawned_count == 0, "Um unico timer de respawn")

	# --- Respawn
	await get_tree().process_frame
	while respawned_count == 0:
		await get_tree().physics_frame
	var elapsed := (respawned_at - died_at) / float(Engine.physics_ticks_per_second) # tempo de jogo
	check(absf(elapsed - 2.0) < .15, "Respawn apos ~2 s (%.2f s)" % elapsed)
	check(player.current_hp == 100.0 and not player.is_dead, "Respawn restaura 100/100")
	check(player.global_position.distance_to(spawn) < .05, "Respawn no PlayerSpawn")
	check(player.is_in_group("player") and player.collision_layer == 2, "Respawn volta ao grupo player e a camada 2")
	check(hud_synced(100), "HUD atualiza apos respawn")
	await frames(1)
	check(not is_instance_valid(app.death_toast), "Aviso de morte some no respawn")

	# --- Protecao pos-respawn (1,5 s)
	await wait(1.0)
	player.take_damage(15)
	check(player.current_hp == 100.0, "Protecao de respawn ignora dano a 1,0 s")
	await wait(.6)
	player.take_damage(15)
	check(player.current_hp == 85.0, "Dano volta apos 1,5 s")
	await wait(.7)

	# --- Controles depois do respawn
	var start := player.global_position
	key(KEY_D, true)
	await frames(40)
	key(KEY_D, false)
	var moved := player.global_position - start
	var visual_fwd: Vector3 = -player.get_node("Visual").global_basis.z
	check(moved.x > 2.0, "Anda depois do respawn")
	check(visual_fwd.normalized().dot(camera.planar_direction(Vector3(1, 0, 0))) > .98, "Orientacao visual segue o movimento apos respawn")
	encounter.hp = 80.0
	place_near_player(encounter, Vector3(0, -.5, -1.2))
	player.rotation.y = 0
	await frames(3)
	player._try_attack()
	check(encounter.hp == 65.0, "Ataca (15 de dano, Spec 013C) depois do respawn")
	encounter.hp = 20.0
	encounter._update_label()
	place_near_player(encounter, Vector3(1.5, -.5, 0))
	await frames(2)
	key_e(true)
	await wait(2.3)
	key_e(false)
	check(encounter.is_in_group("domesticated") and encounter.hp == 80.0, "Domestica depois do respawn (vida cheia, Spec 013C)")
	var carno = CARNO.instantiate()
	world.add_child(carno)
	carno.hp = 20.0
	check(not carno.can_be_domesticated(), "Carnotauro continua nao domesticavel")
	carno.queue_free()

	# --- Camera
	var cam_basis := camera.global_basis
	player.rotation.y = 2.0
	await frames(2)
	check(camera.top_level and camera.global_basis.is_equal_approx(cam_basis), "Camera nao gira com o Player")

	# --- Pausa congela o respawn
	player.take_damage(1000)
	check(player.is_dead and died_count == 2, "Segunda morte registrada")
	app.pause_game()
	await wait(2.4)
	check(player.is_dead, "Respawn nao corre com o jogo pausado")
	app.resume_game()
	await wait(2.2)
	check(not player.is_dead and respawned_count == 2, "Respawn conclui apos retomar")

	# --- Noite -> dia continua
	DayNightManager.start_night()
	var waves = world.get_node("WaveManager")
	await wait(4.6)
	for dino in get_tree().get_nodes_in_group("wild_dino"):
		dino.take_damage(1000)
	await wait(.3)
	check(DayNightManager.is_day() and app.screen == "playing", "Noite vencida volta ao dia sem pausar")
	check(waves.snapshot().active == 0, "Onda sem inimigos ativos")

	# --- Refugio continua sendo a derrota
	base.take_damage(30)
	await frames(2)
	await get_tree().process_frame # a HUD do refugio atualiza em _process
	await get_tree().process_frame
	check(base.health == 70.0 and app.base_text.text == "REFÚGIO  70 / 100", "Refugio recebe dano e HUD atualiza")
	base.take_damage(1000)
	await frames(2)
	check(DayNightManager.is_game_over and app.screen == "defeat", "Refugio em 0 abre 'O refúgio caiu'")

	app.show_menu()
	await frames(3)
	var report := {"passed": passed, "failed": failed, "engine": Engine.get_version_info(), "display": DisplayServer.get_name()}
	var destination := "user://spec011-health.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			destination = argument.trim_prefix("--report=")
	var file := FileAccess.open(destination, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("SPEC011 RESULTS: %d passed; %d failed" % [passed.size(), failed.size()])
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)
