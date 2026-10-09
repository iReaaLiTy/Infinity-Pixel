extends Node

# Configuracoes (playtest 09/10/2026): cada opcao funciona de verdade e fica
# salva. No fim restaura o padrao e apaga o arquivo (nao vaza para outros testes).
# Uso: Godot [--headless] --path . res://tests/settings_ui.tscn [-- --report=<arquivo>]
const Settings := preload("res://scenes/ui/settings.gd")
var passed: Array[String] = []
var failed: Array[String] = []
var app

func check(ok: bool, label: String) -> void:
	(passed if ok else failed).append(label)
	print(("PASS: " if ok else "FAIL: ") + label)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func bus_db(bus: String) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))

func esc() -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.physical_keycode = KEY_ESCAPE
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await get_tree().process_frame
	await frames(2)

func _ready() -> void:
	var report := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report = arg.trim_prefix("--report=")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await frames(3)
	check(app.ui.find_child("SettingsButton", true, false) != null, "Menu principal tem CONFIGURACOES")
	app.show_settings(app._close_overlay)
	await frames(2)
	var c: Dictionary = app.settings_controls
	check(c.has("master") and c.has("music") and c.has("sfx") and c.has("fullscreen") and c.has("ui_scale"), "Tela de configuracoes com volume geral, musica, efeitos, tela cheia e escala")
	c.master.value = 50
	c.music.value = 20
	c.sfx.value = 0
	await frames(1)
	check(absf(bus_db("Master") - linear_to_db(0.5)) < 0.05, "Volume geral muda o barramento Master")
	check(is_equal_approx(app.audio.volume, 0.2), "Musica muda o volume da musica (%.2f)" % app.audio.volume)
	check(bus_db("SFX") < -60.0, "Efeitos a 0 silencia o barramento SFX")
	c.ui_scale.select(2)
	c.ui_scale.item_selected.emit(2)
	await frames(1)
	check(is_equal_approx(get_window().content_scale_factor, 1.15), "Escala da interface 115% aplicada")
	c.fullscreen.button_pressed = true
	await frames(1)
	var cfg := ConfigFile.new()
	var loaded := cfg.load(Settings.PATH) == OK
	check(loaded and is_equal_approx(cfg.get_value("jogador", "master"), 0.5) and cfg.get_value("jogador", "fullscreen") == true and is_equal_approx(cfg.get_value("jogador", "ui_scale"), 1.15), "Mudancas salvas em user://settings.cfg")
	# Persistencia: recarregar le os mesmos valores.
	Settings.values = Settings.DEFAULTS.duplicate()
	Settings.load_settings()
	check(is_equal_approx(Settings.values.music, 0.2) and is_equal_approx(Settings.values.ui_scale, 1.15), "Recarregar mantem as configuracoes")
	await esc()
	check(not is_instance_valid(app.overlay), "ESC fecha as configuracoes no menu")
	# Pela pausa: abre e volta para a pausa.
	app.start_game()
	await frames(5)
	app.pause_game()
	app.show_settings(app._show_pause_menu)
	await frames(2)
	await esc()
	check(get_tree().paused and app.screen == "paused" and is_instance_valid(app.overlay) and not app._is_showing_controls(), "Na pausa, ESC volta ao menu de pausa")
	app.resume_game()
	# Restaurar padrao.
	Settings.reset(app.audio, get_window())
	check(is_equal_approx(get_window().content_scale_factor, 1.0) and is_equal_approx(app.audio.volume, 0.55) and absf(bus_db("Master")) < 0.05, "Restaurar padrao volta tudo ao normal")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))
	print("SETTINGS RESULTS: %d passed; %d failed" % [passed.size(), failed.size()])
	if report != "":
		var f := FileAccess.open(report, FileAccess.WRITE)
		f.store_string(JSON.stringify({"passed": passed, "failed": failed}, "\t"))
		f.close()
	get_tree().quit(0 if failed.is_empty() else 1)
