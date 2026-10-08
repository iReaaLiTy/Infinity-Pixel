extends Node

# Evidencia visual da Spec 013C (nao e teste): previa e anel de alcance, dois
# dinos diurnos, golpe e coleta de arvore/pedra, "+N" e domesticacao 80/80.
# Pela camera real de gameplay. Exige janela. Uso: -- --output=<pasta>
var out := "user://spec013c-views/"
var app: Node
var player: CharacterBody3D

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + label + ".png")

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func go(pos: Vector3) -> void:
	player.global_position = pos + Vector3(0, .1, 0)
	await wait(1.4) # camera alcanca

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await wait(.4)
	app.start_game()
	await get_tree().process_frame
	await get_tree().process_frame
	var world: Node3D = app.world
	player = world.get_node("Player")
	player._invulnerable_left = INF
	var spawner = world.get_node("EncounterSpawner")
	for d in spawner.encounters: d.set_physics_process(false)
	# 1. previa do alcance no ponto vazio
	var slot = world.get_node("DefenseSlots/SlotRuinMeadow")
	await go(slot.global_position + Vector3(0, 0, 1.8))
	await shot("01_previa_alcance_ponto_vazio")
	# 2. torre construida com o anel real (8 m) de perto
	world.get_node("DefenseSlots").interact(slot)
	await wait(1.0)
	await shot("02_torre_anel_8m")
	# 3. de longe o anel fica discreto
	await go(slot.global_position + Vector3(0, 0, 14))
	await shot("03_torre_anel_discreto_longe")
	# 4. os dois dinos diurnos (bosque e pedras)
	await go(spawner.encounters[0].global_position + Vector3(2.5, 0, 3))
	await shot("04_dino_diurno_bosque")
	await go(spawner.encounters[1].global_position + Vector3(-2.5, 0, 3))
	await shot("05_dino_diurno_pedras")
	# 5. arvore: golpe e coleta
	var tree = world.get_node("Collectables/Tree1")
	await go(tree.global_position + Vector3(0, 0, 1.6))
	player.rotation.y = 0.0
	player.attack_cooldown.stop()
	player._try_attack()
	await wait(.08)
	await shot("06_arvore_golpe")
	await wait(.9)
	player.attack_cooldown.stop()
	player._try_attack()
	await wait(.3)
	await shot("07_arvore_cai_mais10_madeira")
	# 6. pedra: golpes e quebra
	var stone = world.get_node("Collectables/Stone1")
	await go(stone.global_position + Vector3(0, 0, 1.9))
	player.rotation.y = 0.0
	for i in 2:
		player.attack_cooldown.stop()
		player._try_attack()
		await wait(.5)
	await shot("08_pedra_golpeada")
	player.attack_cooldown.stop()
	player._try_attack()
	await wait(.12)
	await shot("09_pedra_quebra_mais6_pedra")
	# 7. domesticacao com vida cheia + "+15 PONTOS" de um inimigo da onda
	var dino = spawner.encounters[0]
	await go(dino.global_position + Vector3(0, 0, 1.6))
	dino.hp = 20.0
	dino._update_label()
	dino.domesticate()
	DayNightManager.start_night()
	await wait(.3)
	var foe = world.get_node("WaveManager")._active_wave_enemies.keys()[0]
	foe.take_damage(1000)
	await wait(.25)
	await shot("10_domesticado_80_mais15_pontos")
	print("[SPEC013C] capturas salvas em " + out)
	app.show_menu()
	get_tree().quit.call_deferred()
