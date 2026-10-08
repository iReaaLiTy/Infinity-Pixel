extends Node

# Evidencia visual da Spec 013B (nao e teste com assercoes): audio do menu,
# pontos na HUD, pontos de construcao, torre, ataque, +15 e Dia 2. Pela camera
# real de gameplay. Exige janela. Uso: -- --output=<pasta>
func shot(out: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + label + ".png")

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	var out := "user://spec013b-views/"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	var app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await wait(1.2)
	await shot(out, "01_menu_audio")
	var icon: Button = app.ui.find_child("AudioButton", true, false)
	icon.pressed.emit()
	await wait(.2)
	await shot(out, "02_menu_mudo")
	icon.pressed.emit()
	app.start_game()
	await get_tree().process_frame # o encontro nasce no quadro seguinte
	await get_tree().process_frame
	var world: Node3D = app.world
	var player = world.get_node("Player")
	player._invulnerable_left = INF # captura
	world.get_node("EncounterSpawner").current_encounter.set_physics_process(false)
	var slots = world.get_node("DefenseSlots")
	var slot: Node3D = world.get_node("DefenseSlots/SlotWestInner")
	player.global_position = slot.global_position + Vector3(0, .1, 1.8)
	await wait(1.2)
	await shot(out, "03_ponto_vazio_painel")
	slots.interact(slot)
	await wait(.6)
	await shot(out, "04_torre_construida")
	var sister: Node3D = world.get_node("DefenseSlots/SlotWestOuter")
	player.global_position = sister.global_position + Vector3(0, .1, 1.8)
	await wait(1.0)
	await shot(out, "05_sem_pontos")
	# Noite: Player perto da torre oeste, inimigo da rota oeste chegando
	player.global_position = slot.global_position + Vector3(3, .1, 3)
	DayNightManager.start_night()
	var wave = world.get_node("WaveManager")
	var hit := false
	var t := 0.0
	while not hit and t < 20.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		for foe in wave._active_wave_enemies.keys():
			if is_instance_valid(foe) and foe.hp < 80.0:
				hit = true
	await wait(.05)
	await shot(out, "06_torre_atacando")
	var economy = world.get_node("DefenseEconomy")
	while wave._spawned_count < wave.enemy_count:
		await get_tree().process_frame
	var foes: Array = wave._active_wave_enemies.keys()
	if not foes.is_empty():
		foes[0].take_damage(1000)
	await wait(.25)
	await shot(out, "07_mais15")
	for foe in wave._active_wave_enemies.keys():
		foe.take_damage(1000)
	await wait(1.0)
	player.global_position = slot.global_position + Vector3(0, .1, 1.8)
	await wait(1.6)
	await shot(out, "08_dia2_escolha_%d_pontos" % economy.points)
	slots.interact(slot)
	await wait(.6)
	await shot(out, "09_torre_nivel2")
	economy.add_points(45)
	slots.interact(slot)
	await wait(.6)
	await shot(out, "10_torre_nivel3")
	print("[SPEC013B] capturas salvas em " + out)
	app.show_menu()
	get_tree().quit.call_deferred()
