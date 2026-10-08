extends Node

# Evidencia visual da Spec 013 (nao e teste com assercoes): joga um ciclo com
# dia acelerado e captura menu, Dia 1, aviso, contagem, noite e amanhecer pela
# camera real de gameplay. Exige janela. Uso: -- --output=<pasta>
func shot(out: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + label + ".png")

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	var out := "user://spec013-views/"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	DayNightManager.day_duration_seconds = 20.0 # so para a captura
	DayNightManager.night_duration_seconds = 30.0
	DayNightManager.night_warning_seconds = 9.0
	DayNightManager.night_countdown_seconds = 5.0
	var app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await wait(1.2)
	await shot(out, "01_menu")
	app.start_game() # mesmo caminho do botao JOGAR
	var player = app.world.get_node("Player")
	player._invulnerable_left = INF # captura: o Player nao deve morrer no meio
	await wait(2.0)
	await shot(out, "02_dia1")
	await wait(9.5)
	await shot(out, "03_aviso_anoitecer")
	await wait(5.5)
	await shot(out, "04_contagem_final")
	while not DayNightManager.is_night():
		await get_tree().process_frame
	await wait(2.0)
	await shot(out, "05_noite1_inicio")
	await wait(4.5)
	await shot(out, "06_noite1_inimigos")
	var wave = app.world.get_node("WaveManager")
	while wave._spawned_count < wave.enemy_count:
		await get_tree().process_frame
	for foe in wave._active_wave_enemies.keys():
		foe.take_damage(1000)
	await wait(.6)
	await shot(out, "07_amanhecer_dia2")
	print("[SPEC013] capturas salvas em " + out)
	app.show_menu()
	get_tree().quit.call_deferred()
