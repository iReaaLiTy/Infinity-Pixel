extends Node

# Capturas do combate revisado (nao e teste): aliado em SEGUIR lutando contra
# um invasor (combate real, sem congelar), arco vermelho da preparacao da
# mordida e o rastro do golpe do jogador. Exige janela.
# Uso: res://tools/combat_capture.tscn -- --output=<pasta>
const WILD := preload("res://scenes/enemies/wild_dino.tscn")
var out := "user://combat-capture/"

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func shot(label: String) -> void:
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(out + label + ".png")
	print("[COMBATE] " + label)

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	var app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await frames(5)
	app.start_game()
	await frames(20)
	var world: Node3D = app.world
	var player = world.get_node("Player")
	player.set_process_unhandled_input(false)
	player.set_physics_process(false)
	player._invulnerable_left = INF
	player.get_node("StrategicCamera").follow_smoothing = 0.0
	for d in world.get_node("EncounterSpawner").encounters:
		if is_instance_valid(d): d.queue_free()
	player.global_position = Vector3(0, 0.1, -5)
	var ally = WILD.instantiate()
	world.add_child(ally)
	ally.global_position = Vector3(1.5, 0.5, -5)
	ally.domesticate()
	await frames(20)
	DayNightManager.state = DayNightManager.State.NIGHT
	world.get_node("DayNightVisual").shown_hour = 21.0
	world.get_node("DayNightVisual")._apply(true)
	var foe = WILD.instantiate()
	world.add_child(foe)
	foe.add_to_group("wave_enemy")
	foe.get_node("Visual").set_night_threat()
	foe._update_label()
	foe.global_position = Vector3(0, 0.5, 0)
	# 1. Combate real: espera a mordida comecar a ser preparada.
	for i in 600:
		if foe._windup_left > 0.2:
			break
		await get_tree().physics_frame
	await shot("60_preparacao_mordida_arco")
	# 2. Aliado em SEGUIR acertando o invasor.
	for i in 600:
		if not is_instance_valid(foe) or foe.hp < 60.0:
			break
		await get_tree().physics_frame
	await shot("61_aliado_seguir_ataca")
	# 3. Golpe do jogador: rastro na direcao do clique.
	player.rotation.y = PI * 0.25
	player.get_node("AttackCooldownTimer").stop()
	player._try_attack()
	await frames(4)
	await shot("62_golpe_rastro")
	app.show_menu()
	get_tree().quit.call_deferred()
