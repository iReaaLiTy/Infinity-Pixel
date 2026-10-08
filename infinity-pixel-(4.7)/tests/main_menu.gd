extends Node

# Menu principal redesenhado: cliques reais de mouse em cada botao, audio,
# redimensionamento, capturas e transicao para o jogo. Exige janela.
var passed: Array[String] = []
var failed: Array[String] = []
var app: Node
var out := "user://menu-shots/"

func check(ok: bool, title: String) -> void:
	(passed if ok else failed).append(title)
	print(("PASS: " if ok else "FAIL: ") + title)

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + label + ".png")

func button(text: String) -> Button:
	for b in app.ui.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			return b
	return null

func click(control: Control) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = control.get_global_rect().get_center()
		get_viewport().push_input(ev, true)
	await wait(.15)

func on_screen(control: Control) -> bool:
	return control != null and get_viewport().get_visible_rect().encloses(control.get_global_rect())

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("main_menu precisa de janela")
		get_tree().quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await wait(1.2)
	await shot("menu_1280x720")
	check(app.screen == "menu" and is_instance_valid(app.menu_backdrop), "Menu abre com o vale do jogo ao fundo")
	check(get_viewport().get_camera_3d() == app.menu_backdrop.camera, "Camera do fundo do menu ativa")
	var removed := true
	for l in app.ui.find_children("*", "Label", true, false):
		removed = removed and not ("AC1" in l.text or "acadêmico" in l.text or "precisa de você" in l.text)
	check(removed, "Textos institucionais fora da tela principal")
	var labels := []
	for l in app.ui.find_children("*", "Label", true, false): labels.append(l.text)
	check("JADEFALL" in labels and "REFÚGIO" in labels, "Logo JADEFALL presente")
	for t in ["JOGAR", "CONTROLES", "CRÉDITOS", "SAIR"]:
		check(on_screen(button(t)), "Botao %s visivel em 1280x720" % t)
	var play := button("JOGAR")
	check(play.get_global_rect().size.x > button("CONTROLES").get_global_rect().size.x and play.has_focus(), "JOGAR e o maior botao e tem o foco")

	# Controles: abre e volta
	await click(button("CONTROLES"))
	check(is_instance_valid(app.overlay) and app._is_showing_controls(), "CONTROLES abre a tela de controles")
	await shot("menu_controles")
	await click(button("Voltar"))
	check(not is_instance_valid(app.overlay), "Voltar fecha Controles")
	# Creditos: abre, mostra info academica, volta
	await click(button("CRÉDITOS"))
	var academic := false
	for l in app.overlay.find_children("*", "Label", true, false):
		academic = academic or "acadêmico" in l.text
	check(is_instance_valid(app.overlay) and academic, "CRÉDITOS abre e contem a informacao academica")
	await shot("menu_creditos")
	await click(button("Voltar"))
	check(not is_instance_valid(app.overlay), "Voltar fecha Creditos")
	# ESC tambem fecha
	await click(button("CRÉDITOS"))
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await wait(.15)
	esc.pressed = false
	Input.parse_input_event(esc)
	check(not is_instance_valid(app.overlay), "ESC fecha a tela secundaria")

	# Audio (013B): icone no canto e slider sempre visivel logo abaixo.
	var icon: Button = app.ui.find_child("AudioButton", true, false)
	var slider: HSlider = app.ui.find_child("VolumeSlider", true, false)
	check(on_screen(icon) and on_screen(slider) and slider.get_global_rect().position.y > icon.get_global_rect().end.y - 1, "Icone de audio no canto com o slider visivel abaixo")
	slider.value = 30
	var bus := AudioServer.get_bus_index("Music")
	check(is_equal_approx(app.audio.volume, .3) and is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(.3)), "Volume altera o bus de musica")
	await click(icon)
	check(app.audio.muted and AudioServer.is_bus_mute(bus) and slider.value == 0, "Clique no icone silencia o bus (slider 0)")
	await shot("menu_audio")
	await click(icon)
	check(not app.audio.muted and not AudioServer.is_bus_mute(bus) and slider.value == 30, "Segundo clique devolve o som em 30")
	slider.value = 55

	# Redimensionamento
	for size in [Vector2i(1920, 1080), Vector2i(1024, 768), Vector2i(960, 540)]:
		get_window().size = size
		await wait(.4)
		var fits := true
		for t in ["JOGAR", "CONTROLES", "CRÉDITOS", "SAIR"]:
			fits = fits and on_screen(button(t))
		fits = fits and on_screen(icon)
		check(fits, "Botoes e audio visiveis em %dx%d" % [size.x, size.y])
		await shot("menu_%dx%d" % [size.x, size.y])
	get_window().size = Vector2i(1280, 720)
	await wait(.4)

	# JOGAR -> jogo
	await click(button("JOGAR"))
	await wait(1.0)
	check(app.screen == "playing" and is_instance_valid(app.world), "JOGAR carrega o mapa")
	check(not is_instance_valid(app.menu_backdrop), "Fundo do menu liberado ao jogar")
	var player = app.world.get_node("Player")
	check(get_viewport().get_camera_3d() == player.get_node("StrategicCamera"), "Camera estrategica ativa no jogo")
	check(is_instance_valid(app.hud) and app.player_text.text == "JOGADOR  100 / 100", "HUD do jogo aparece")
	var start: Vector3 = player.global_position
	var key := InputEventKey.new()
	key.physical_keycode = KEY_S
	key.keycode = KEY_S
	key.pressed = true
	Input.parse_input_event(key)
	await wait(.6)
	key.pressed = false
	Input.parse_input_event(key)
	check(player.global_position.distance_to(start) > 2.0, "Player anda (gameplay ativo)")
	await shot("jogo_apos_jogar")
	# Volta ao menu e o fundo e recriado
	app.pause_game()
	app.show_menu()
	await wait(.6)
	check(app.screen == "menu" and is_instance_valid(app.menu_backdrop) and not is_instance_valid(app.world), "Menu volta com o fundo recriado")

	print("MENU RESULTS: %d passed; %d failed" % [passed.size(), failed.size()])
	var file := FileAccess.open(out + "main_menu.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "failed": failed}, "  "))
	file.close()
	# SAIR por ultimo: o processo deve encerrar sozinho.
	if not failed.is_empty():
		get_tree().quit(1)
		return
	print("Pressionando SAIR...")
	await click(button("SAIR"))
	await wait(1.0)
	print("FAIL: SAIR nao encerrou o jogo")
	get_tree().quit(2)
