extends Node

const WORLD := preload("res://scenes/world/prototype_area.tscn")
const CREAM := Color("f2e8ce")
const GOLD := Color("e7ae58")
const JADE := Color("69be9b")
var world: Node3D
var ui: Control
var overlay: Control
var hud: Control
var base_text: Label
var base_bar: ProgressBar
var wave_text: Label
var objective: Label
var phase_text: Label
var channel_bar: ProgressBar
var hint: Label
var audio: Node
var screen := "menu"
var victory_count := 0
var was_command_rejected := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A camada raiz so organiza menus e HUD. Durante o jogo, eventos de mouse
	# devem atravessa-la para que a camera e o ataque recebam o input.
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	ui.theme = _theme()
	audio = preload("res://scenes/ui/audio_director.gd").new()
	add_child(audio)
	DayNightManager.game_over.connect(_defeat)
	DayNightManager.day_started.connect(_victory)
	DayNightManager.night_started.connect(func(): audio.change_music("combat"))
	show_menu()

func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 19
	theme.set_color("font_color", "Label", CREAM)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("244d45") if state == "normal" else Color("47715a")
		style.border_color = GOLD if state == "focus" else Color("5d8169")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(7)
		style.content_margin_left = 22
		style.content_margin_right = 22
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		theme.set_stylebox(state, "Button", style)
	theme.set_color("font_color", "Button", CREAM)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("17332f")
	bg.set_corner_radius_all(5)
	var fg := StyleBoxFlat.new()
	fg.bg_color = JADE
	fg.set_corner_radius_all(5)
	theme.set_stylebox("background", "ProgressBar", bg)
	theme.set_stylebox("fill", "ProgressBar", fg)
	return theme

func _label(text: String, size: int = 20, color: Color = CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _button(parent: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 46
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _clear_ui() -> void:
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	overlay = null
	hud = null

func _cancel_channel() -> void:
	if is_instance_valid(world):
		world.get_node("Player/DomesticationChannel").reset_channel()

func show_menu() -> void:
	_cancel_channel()
	get_tree().paused = false
	DayNightManager.reset_session(false)
	if is_instance_valid(world):
		world.get_node("WaveManager").cancel_wave()
		remove_child(world)
		world.queue_free()
	world = null
	screen = "menu"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear_ui()
	audio.change_music("calm")
	var bg := ColorRect.new()
	bg.color = Color("102b2a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bg)
	if ResourceLoader.exists("res://assets/ui/keyart.png"):
		var picture := TextureRect.new()
		picture.texture = load("res://assets/ui/keyart.png")
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ui.add_child(picture)
	var shade := ColorRect.new()
	shade.color = Color(.035,.10,.095,.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 500
	ui.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	margin.offset_left = 48
	margin.offset_right = 450
	margin.offset_top = 28
	margin.offset_bottom = -28
	ui.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	margin.add_child(box)
	var brand := HBoxContainer.new()
	brand.add_theme_constant_override("separation", 10)
	var mark := TextureRect.new()
	mark.texture = load("res://assets/ui/inity_mark.svg")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.custom_minimum_size = Vector2(24,24)
	brand.add_child(mark)
	brand.add_child(_label("ESTÚDIO INITY PIXEL  /  AC1", 16, JADE))
	box.add_child(brand)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18
	box.add_child(spacer)
	box.add_child(_label("INFINITY\nPIXEL", 47, CREAM))
	box.add_child(_label("DOMESTIQUE. POSICIONE. DEFENDA.", 16, GOLD))
	var desc := _label("O refúgio precisa de você.\nPrepare seus aliados antes do anoitecer.", 18)
	desc.custom_minimum_size.y = 65
	box.add_child(desc)
	_button(box, "Jogar", start_game).grab_focus()
	_button(box, "Controles", func(): show_info(false))
	_button(box, "Créditos", func(): show_info(true))
	_button(box, "Sair", func(): get_tree().quit())
	box.add_child(_label("MÚSICA", 13, JADE))
	_add_volume(box)
	box.add_child(_label("Protótipo acadêmico • Infinity Pixel\nArte e história propostas para aprovação do grupo", 13))

func _add_volume(box: Node) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 100
	volume.value = audio.volume * 100
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume.custom_minimum_size.y = 24
	volume.value_changed.connect(func(v): audio.set_volume(v / 100.0))
	row.add_child(volume)
	var mute := CheckButton.new()
	mute.text = "Mudo"
	mute.button_pressed = audio.muted
	mute.toggled.connect(audio.set_muted)
	row.add_child(mute)

func show_info(credits: bool) -> void:
	var box := _modal("Créditos" if credits else "Como defender o refúgio")
	var text := "Inity Pixel\nMurilo Cassetti • Heitor Crispim\nPedro Ferreira • Juan Carlos\n\nConceito, código, modelos e música: produção\nassistida por IA. Direção final: aprovação do grupo.\nGodot Engine — licença MIT.\n\nFunções individuais e Game Designer: a confirmar.\nCréditos e fontes: docs/ac1/ASSETS.md" if credits else "WASD · Mover     Mouse · Câmera\nClique esquerdo · Atacar (20 de dano)\nE por 2 segundos · Domesticar a até 3 metros\nF · Seguir / ficar (somente durante o dia)\nN · Iniciar noite     Esc · Pausar / retomar\n\nEncontre o selvagem à esquerda, atrás do início.\nTrês golpes deixam 20/80 HP; o quarto mata.\nPosicione um aliado no posto antes de iniciar a noite.\nO aliado mantém a vida: lute junto dele!\n\nProteja a base. O jogador ainda não possui HP."
	box.add_child(_label(text, 19))
	_button(box, "Voltar", _close_overlay).grab_focus()

func start_game() -> void:
	_cancel_channel()
	get_tree().paused = false
	DayNightManager.reset_session(true)
	if is_instance_valid(world):
		world.get_node("WaveManager").cancel_wave()
		remove_child(world)
		world.queue_free()
	_clear_ui()
	victory_count = 0
	screen = "playing"
	world = WORLD.instantiate()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_hud()
	audio.change_music("calm")

func _panel(parent: Node, box: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.04,.12,.115,.93)
	style.border_color = Color("456c59")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	p.add_child(box)
	return p

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 20
	top.add_theme_constant_override("separation", 14)
	hud.add_child(top)
	var health := VBoxContainer.new()
	health.custom_minimum_size.x = 240
	base_text = _label("REFÚGIO", 18)
	health.add_child(base_text)
	base_bar = ProgressBar.new()
	base_bar.custom_minimum_size.y = 10
	base_bar.show_percentage = false
	health.add_child(base_bar)
	_panel(top, health)
	var phase := VBoxContainer.new()
	phase_text = _label("DIA • PREPARAÇÃO", 18, GOLD)
	phase.add_child(phase_text)
	wave_text = _label("Prepare sua defesa sem limite de tempo", 15)
	phase.add_child(wave_text)
	_panel(top, phase)
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(filler)
	top.add_child(_label("ESC  PAUSA", 16))
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 9)
	var panel := _panel(hud, bottom)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = -140
	panel.offset_bottom = -20
	objective = _label("", 22, GOLD)
	bottom.add_child(objective)
	hint = _label("", 17)
	bottom.add_child(hint)
	channel_bar = ProgressBar.new()
	channel_bar.max_value = 1.0
	channel_bar.show_percentage = false
	channel_bar.custom_minimum_size.y = 9
	bottom.add_child(channel_bar)
	bottom.add_child(_label("WASD mover   ·   Mouse câmera   ·   Clique atacar   ·   E domesticar   ·   F seguir/ficar   ·   N iniciar noite", 14))
	var reticle := _label("·", 35, CREAM)
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(reticle)
	_ignore_mouse(hud)

func _ignore_mouse(control: Node) -> void:
	if control is Control:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in control.get_children():
		_ignore_mouse(c)

func _modal(title: String) -> VBoxContainer:
	_close_overlay()
	overlay = ColorRect.new()
	overlay.color = Color(.015,.045,.045,.82)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 540
	box.add_theme_constant_override("separation", 15)
	_panel(center, box)
	box.add_child(_label(title, 32, GOLD))
	return box

func _close_overlay() -> void:
	if is_instance_valid(overlay):
		ui.remove_child(overlay)
		overlay.queue_free()
	overlay = null

func pause_game() -> void:
	if screen != "playing":
		return
	_cancel_channel()
	screen = "paused"
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	audio.set_paused_mix(true)
	var box := _modal("Uma pausa no refúgio")
	box.add_child(_label("A arena e a domesticação estão pausadas.", 18))
	_button(box, "Retomar", resume_game).grab_focus()
	_add_volume(box)
	_button(box, "Reiniciar", start_game)
	_button(box, "Menu", show_menu)

func resume_game() -> void:
	_close_overlay()
	screen = "playing"
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	audio.set_paused_mix(false)

func _defeat() -> void:
	_result(false)

func _victory() -> void:
	victory_count += 1
	_result(true)

func _result(won: bool) -> void:
	_cancel_channel()
	screen = "victory" if won else "defeat"
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	audio.result(won)
	var box := _modal("Noite defendida" if won else "O refúgio caiu")
	box.add_child(_label("As três ameaças foram neutralizadas.\nO dia voltou. Seus aliados continuam com você." if won else "A base perdeu toda a vida.\nPrepare aliados e lute ao lado deles na próxima tentativa.", 20))
	if won:
		_button(box, "Continuar no dia", resume_game).grab_focus()
	_button(box, "Reiniciar", start_game)
	_button(box, "Menu", show_menu)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if screen == "playing": pause_game()
		elif screen == "paused": resume_game()
		elif screen == "menu": _close_overlay()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and screen == "playing":
		pause_game()

func _process(_delta: float) -> void:
	if not is_instance_valid(world) or not is_instance_valid(hud):
		return
	var base = world.get_node("Territory")
	base_bar.max_value = base.max_health
	base_bar.value = base.health
	base_text.text = "REFÚGIO  %d / %d" % [base.health, base.max_health]
	var wave: Dictionary = world.get_node("WaveManager").snapshot()
	phase_text.text = "NOITE • DEFESA" if DayNightManager.is_night() else "DIA • PREPARAÇÃO"
	wave_text.text = "%d/%d criados  ·  %d neutralizados  ·  %d ativos" % [wave.spawned, wave.total, wave.resolved, wave.active] if DayNightManager.is_night() else "Noites defendidas: %d  ·  Sem cronômetro" % victory_count
	var player = world.get_node("Player")
	var channel = player.get_node("DomesticationChannel")
	channel_bar.value = channel.get_progress()
	var allies := get_tree().get_nodes_in_group("domesticated")
	if DayNightManager.is_night():
		objective.text = "Defenda o refúgio — enfrente as três ameaças"
		hint.text = "Ajude seus aliados no combate. A noite termina após todos os spawns serem neutralizados."
	elif allies.is_empty():
		objective.text = "Encontre e domestique o selvagem na clareira lateral"
		hint.text = "Três golpes → 20/80 HP. Depois, segure E a até 3 metros. O quarto golpe mata."
		if not world.get_node("EncounterSpawner").is_encounter_wild():
			objective.text = "O encontro foi derrotado — N para defender ou Esc para reiniciar"
	else:
		objective.text = "Conduza seu aliado ao posto e pressione F. Depois, N para iniciar a noite."
		hint.text = "Aliados: %d  ·  A vida é preservada ao domesticar; proteja seus companheiros." % allies.size()
	for dino in get_tree().get_nodes_in_group("wild_dino"):
		if dino.global_position.distance_to(player.global_position) < 3.2:
			if dino.can_be_domesticated(): hint.text = "SEGURE E  ·  %.1f / 2.0 s  ·  Soltar ou afastar cancela" % (channel.get_progress()*2)
			elif not dino.is_domesticable: hint.text = "CARNOTAURO  ·  Esta variante não pode ser domesticada."
	for ally in allies:
		if ally.global_position.distance_to(player.global_position) < 3.3:
			hint.text = "ALIADO %d/80 HP  ·  %s  ·  %s" % [ally.hp, "SEGUINDO" if ally.ally_state == 0 else "DEFENDENDO POSTO", "F alterna seguir/ficar" if DayNightManager.is_day() else "Posicionamento bloqueado durante a noite"]
