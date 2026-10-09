extends Node

const WORLD := preload("res://scenes/world/prototype_area.tscn")
const CREAM := Color("f2e8ce")
const GOLD := Color("e7ae58")
const JADE := Color("69be9b")
# Spec 008 (RF-UI-003): comandos reais do Input Map / scripts, fonte unica para
# as telas de Controles do menu principal e da pausa. T (debug) fica de fora.
const CONTROLS := [
	["WASD", "Mover (relativo à câmera)"],
	["Mouse", "Mirar"],
	["Clique esquerdo", "Atacar na direção do cursor"],
	["E (segurar 2 s)", "Domesticar a até 3 m · no marco: recuperar território (de dia)"],
	["F", "Seguir / ficar (somente de dia)"],
	["C", "Construir / melhorar torre (perto de um ponto, de dia)"],
	["I", "Inventário: Madeira, Pedra e receitas"],
	["B", "Construir estrutura (R gira · botão direito cancela)"],
	["H (segurar 3 s)", "Curar na Fogueira (+25, perto dela)"],
	["ESC", "Pausar / retomar"],
]
const DAWN_TOAST_TIME := 2.5 # Spec 008 (RF-UI-001): aviso de amanhecer, em segundos
const EMBER := Color("e0795a") # Spec 011: barra do jogador e tinta de dano
const MenuBackdrop := preload("res://scenes/ui/menu_backdrop.gd")
var menu_backdrop: Node3D
var world: Node3D
var ui: Control
var overlay: Control
var hud: Control
var audio: Node
var screen := "menu"
# Spec 013: fonte unica e o DayNightManager; mantido como leitura para a HUD/testes.
var victory_count: int:
	get: return DayNightManager.nights_defended
var was_command_rejected := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A camada raiz so organiza menus e HUD. Durante o jogo, eventos de mouse
	# devem atravessa-la para que a mira e o ataque recebam o input.
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	ui.theme = _theme()
	audio = preload("res://scenes/ui/audio_director.gd").new()
	add_child(audio)
	# Configuracoes salvas do jogador (volume, tela cheia, escala da interface).
	Settings.load_settings()
	Settings.apply(audio, get_window())
	DayNightManager.game_over.connect(_defeat)
	DayNightManager.day_started.connect(_victory)
	DayNightManager.night_warning.connect(_night_warning)
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
	audio_popup = null

func _cancel_channel() -> void:
	if is_instance_valid(world):
		world.get_node("Player/DomesticationChannel").reset_channel()

func show_menu() -> void:
	tutorial_mode = false
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
	# Fundo = o proprio vale do jogo (so arte), no lugar da ilustracao.
	menu_backdrop = MenuBackdrop.new()
	menu_backdrop.name = "MenuBackdrop"
	add_child(menu_backdrop)
	_build_main_menu()

func _free_menu_backdrop() -> void:
	if is_instance_valid(menu_backdrop):
		remove_child(menu_backdrop)
		menu_backdrop.queue_free()
	menu_backdrop = null

# ---------------------------------------------------------------------------
# Menu principal: logo + JOGAR como protagonistas, o resto discreto.
# Tudo em containers ancorados ao centro, para qualquer tamanho de janela.
# ---------------------------------------------------------------------------

func _display_font() -> Font:
	var heavy := SystemFont.new()
	heavy.font_names = PackedStringArray(["Segoe UI Black", "Arial Black", "Verdana"])
	heavy.font_weight = 900
	var font := FontVariation.new()
	font.base_font = heavy
	font.spacing_glyph = 2
	return font

func _menu_style(fill: Color, edge: Color, depth: int, radius: int, h: int, v: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(2)
	s.border_width_bottom = depth # "espessura" do botao
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, .35)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 5)
	s.content_margin_left = h
	s.content_margin_right = h
	s.content_margin_top = v
	s.content_margin_bottom = v
	return s

# Botao de jogo: borda inferior grossa (profundidade), afunda ao clicar e
# cresce um pouco no hover.
func _menu_button(parent: Node, text: String, size: int, fill: Color, edge: Color, depth: int, radius: int, h: int, v: int, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var font := _display_font()
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", CREAM)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", edge.darkened(.35))
	b.add_theme_constant_override("outline_size", maxi(4, size / 6))
	var normal := _menu_style(fill, edge, depth, radius, h, v)
	var hover := _menu_style(fill.lightened(.12), edge, depth, radius, h, v)
	var pressed := _menu_style(fill.darkened(.08), edge, maxi(2, depth - 4), radius, h, v)
	pressed.content_margin_top = v + depth - maxi(2, depth - 4) # afunda o texto
	pressed.shadow_size = 2
	var focus := hover.duplicate() as StyleBoxFlat
	focus.border_color = Color("fff3cf")
	focus.draw_center = false
	focus.shadow_size = 0
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", focus)
	b.pressed.connect(action)
	b.resized.connect(func(): b.pivot_offset = b.size * .5)
	b.mouse_entered.connect(func(): _bounce(b, 1.06))
	b.mouse_exited.connect(func(): _bounce(b, 1.0))
	parent.add_child(b)
	return b

func _bounce(control: Control, target: float) -> void:
	if control.has_meta("breath"):
		var breath: Tween = control.get_meta("breath")
		if breath.is_valid(): breath.kill()
	var t := control.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(control, "scale", Vector2.ONE * target, .16)
	if target == 1.0 and control.has_meta("breathes"):
		t.tween_callback(_breathe.bind(control))

# JOGAR "respira" bem de leve enquanto ninguem passa o mouse.
func _breathe(control: Control) -> void:
	control.set_meta("breathes", true)
	var t := control.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	t.tween_property(control, "scale", Vector2.ONE * 1.03, 1.3)
	t.tween_property(control, "scale", Vector2.ONE, 1.3)
	control.set_meta("breath", t)

func _logo_word(text: String, size: int, color: Color, outline: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _display_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", size / 5)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .45))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", size / 11)
	l.add_theme_constant_override("shadow_outline_size", size / 5)
	return l

# Cristal facetado (o mesmo verde-agua do refugio), desenhado em vetor.
func _crystal(size: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(size * .62, size)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.draw.connect(func():
		var w := c.size.x
		var h := c.size.y
		var top := Vector2(w * .5, 0)
		var left := Vector2(0, h * .38)
		var right := Vector2(w, h * .38)
		var bottom := Vector2(w * .5, h)
		var mid := Vector2(w * .5, h * .38)
		c.draw_colored_polygon(PackedVector2Array([top, left, bottom, right]), Color("123a33"))
		var inset := func(p: Vector2) -> Vector2: return p.lerp(Vector2(w * .5, h * .45), .16)
		c.draw_colored_polygon(PackedVector2Array([inset.call(top), inset.call(left), inset.call(mid)]), Color("bff5dc"))
		c.draw_colored_polygon(PackedVector2Array([inset.call(top), inset.call(mid), inset.call(right)]), Color("7fd8b0"))
		c.draw_colored_polygon(PackedVector2Array([inset.call(left), inset.call(bottom), inset.call(mid)]), Color("4fae8c"))
		c.draw_colored_polygon(PackedVector2Array([inset.call(mid), inset.call(bottom), inset.call(right)]), Color("2f7f68")))
	return c

func _build_logo(parent: Node) -> Control:
	var logo := VBoxContainer.new()
	logo.alignment = BoxContainer.ALIGNMENT_CENTER
	logo.add_theme_constant_override("separation", -26)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(logo)
	logo.add_child(_logo_word("JADEFALL", 92, Color("f6bd52"), Color("3b2412")))
	# "PIXEL" sobre uma faixa de pedra inclinada, entre dois cristais.
	var band := PanelContainer.new()
	band.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var stone := StyleBoxFlat.new()
	stone.bg_color = Color("5f7468")
	stone.border_color = Color("2c3b34")
	stone.set_border_width_all(3)
	stone.border_width_bottom = 9
	stone.set_corner_radius_all(14)
	stone.skew = Vector2(.12, 0)
	stone.shadow_color = Color(0, 0, 0, .35)
	stone.shadow_size = 8
	stone.shadow_offset = Vector2(0, 6)
	stone.content_margin_left = 34
	stone.content_margin_right = 34
	stone.content_margin_top = 0
	stone.content_margin_bottom = 4
	band.add_theme_stylebox_override("panel", stone)
	logo.add_child(band)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	band.add_child(row)
	row.add_child(_crystal(52))
	row.add_child(_logo_word("REFÚGIO", 58, Color("aef0cf"), Color("123a33")))
	row.add_child(_crystal(52))
	return logo

func _build_main_menu() -> void:
	# Vinheta: escurece so as bordas para dar leitura, sem painel lateral.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(.02, .07, .06, 0))
	gradient.set_color(1, Color(.02, .07, .06, .62))
	var vignette_tex := GradientTexture2D.new()
	vignette_tex.gradient = gradient
	vignette_tex.fill = GradientTexture2D.FILL_RADIAL
	vignette_tex.fill_from = Vector2(.5, .45)
	vignette_tex.fill_to = Vector2(1.1, 1.0)
	var vignette := TextureRect.new()
	vignette.texture = vignette_tex
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(vignette)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(column)
	var logo := _build_logo(column)
	var tagline := _logo_word("DOMESTIQUE  •  POSICIONE  •  DEFENDA", 19, CREAM, Color("1b2c26"))
	tagline.add_theme_constant_override("shadow_offset_y", 2)
	column.add_child(tagline)
	var gap := Control.new()
	gap.custom_minimum_size.y = 34
	column.add_child(gap)
	var play := _menu_button(column, "JOGAR", 46, Color("e9a23b"), Color("8a4f19"), 10, 20, 78, 12, start_game)
	play.name = "PlayButton"
	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 22
	column.add_child(gap2)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	_menu_button(row, "CONTROLES", 22, Color("5f7468"), Color("2c3b34"), 7, 13, 26, 8, func(): show_info(false))
	_menu_button(row, "CRÉDITOS", 22, Color("5f7468"), Color("2c3b34"), 7, 13, 26, 8, func(): show_info(true))
	# Spec 022: tutorial jogavel (mesmo jogo, instancia isolada).
	_menu_button(row, "TUTORIAL", 22, Color("3f8f73"), Color("1e4d3f"), 7, 13, 26, 8, start_tutorial).name = "TutorialButton"
	var gap3 := Control.new()
	gap3.custom_minimum_size.y = 26
	column.add_child(gap3)
	var small := HBoxContainer.new()
	small.alignment = BoxContainer.ALIGNMENT_CENTER
	small.add_theme_constant_override("separation", 14)
	column.add_child(small)
	_menu_button(small, "CONFIGURAÇÕES", 17, Color("2a3d37"), Color("15211d"), 5, 10, 22, 4, func(): show_settings(_close_overlay)).name = "SettingsButton"
	_menu_button(small, "SAIR", 17, Color("2a3d37"), Color("15211d"), 5, 10, 22, 4, func(): get_tree().quit())
	_build_audio_corner()
	play.grab_focus()
	# Entrada suave do logo e "respiracao" do JOGAR.
	logo.modulate.a = 0.0
	var intro := logo.create_tween().set_trans(Tween.TRANS_SINE)
	intro.tween_property(logo, "modulate:a", 1.0, .7)
	play.set_meta("breathes", true)
	_breathe(play)

# Audio: so um icone no canto; o clique abre volume + mudo (mesmos controles
# de _add_volume, usados tambem na pausa).
var audio_popup: Control

func _build_audio_corner() -> void:
	var corner := VBoxContainer.new()
	corner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corner.offset_right = -24
	corner.offset_bottom = -22
	corner.alignment = BoxContainer.ALIGNMENT_END
	corner.add_theme_constant_override("separation", 8)
	ui.add_child(corner)
	audio_popup = null # 013B: sem popup; o slider fica sempre visivel abaixo do icone
	var icon := Button.new()
	icon.name = "AudioButton"
	icon.tooltip_text = "Som ligado/mudo"
	icon.custom_minimum_size = Vector2(58, 58)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var disc := _menu_style(Color("2a3d37"), Color("15211d"), 5, 29, 0, 0)
	icon.add_theme_stylebox_override("normal", disc)
	icon.add_theme_stylebox_override("hover", _menu_style(Color("3b544b"), Color("15211d"), 5, 29, 0, 0))
	icon.add_theme_stylebox_override("pressed", _menu_style(Color("223330"), Color("15211d"), 3, 29, 0, 0))
	icon.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	icon.draw.connect(func(): _draw_speaker(icon))
	corner.add_child(icon)
	# Slider 0–100 logo abaixo. Regra unica: slider 0 <=> mudo (icone e audio).
	var slider := HSlider.new()
	slider.name = "VolumeSlider"
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.custom_minimum_size = Vector2(130, 22)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(v: float):
		audio.set_volume(v / 100.0)
		audio.set_muted(v <= 0.0)
		icon.queue_redraw())
	corner.add_child(slider)
	# Estado inicial coerente: mudo vindo da pausa aparece como slider 0.
	slider.value = 0.0 if audio.muted else audio.volume * 100.0
	# Icone: com som -> mudo (slider 0); mudo -> volta ao ultimo volume (> 0).
	icon.pressed.connect(func():
		if slider.value > 0.0:
			slider.value = 0.0
		else:
			slider.value = maxf(audio.last_nonzero_volume, 0.01) * 100.0)

func _draw_speaker(icon: Button) -> void:
	var c := icon.size * .5 + Vector2(-5, -2)
	var col := CREAM
	icon.draw_colored_polygon(PackedVector2Array([c + Vector2(-11, -6), c + Vector2(-4, -6), c + Vector2(5, -14),
		c + Vector2(5, 14), c + Vector2(-4, 6), c + Vector2(-11, 6)]), col)
	if audio.muted or audio.volume <= 0.0:
		icon.draw_line(c + Vector2(10, -7), c + Vector2(22, 7), EMBER, 3.5)
		icon.draw_line(c + Vector2(10, 7), c + Vector2(22, -7), EMBER, 3.5)
	else:
		icon.draw_arc(c + Vector2(5, 0), 8, -.9, .9, 10, col, 3)
		icon.draw_arc(c + Vector2(5, 0), 15, -.9, .9, 12, col, 3)

func _add_volume(box: Node) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(_label("Música", 18))
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
	if not credits:
		show_controls(_close_overlay, "Dois selvagens rondam o vale de dia: no bosque e nas pedras.\nQuatro golpes (15 cada) deixam 20/80 HP; domesticar devolve a vida cheia.\nBata em árvores e pedras de coleta para juntar Madeira e Pedra.\nPosicione aliados e torres antes do anoitecer (18:00).\n\nProteja a base. Se você cair, volta em 2 s;\nsó a queda do refúgio encerra a partida.")
		return
	var box := _modal("Créditos")
	var brand := HBoxContainer.new()
	brand.add_theme_constant_override("separation", 10)
	var mark := TextureRect.new()
	mark.texture = load("res://assets/ui/inity_mark.svg")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.custom_minimum_size = Vector2(24, 24)
	brand.add_child(mark)
	brand.add_child(_label("ESTÚDIO INITY PIXEL  /  AC1", 16, JADE))
	box.add_child(brand)
	var text := "Inity Pixel\nMurilo Cassetti • Heitor Crispim\nPedro Ferreira • Juan Carlos\n\nConceito, código, modelos e música: produção\nassistida por IA. Direção final: aprovação do grupo.\nGodot Engine — licença MIT.\n\nFunções individuais e Game Designer: a confirmar.\nCréditos e fontes: docs/ac1/ASSETS.md"
	box.add_child(_label(text, 19))
	box.add_child(_label("Protótipo acadêmico • Jadefall: Guardiões do Refúgio\nArte e história propostas para aprovação do grupo", 14, JADE))
	_button(box, "Voltar", _close_overlay).grab_focus()

# Spec 008 (RF-UI-003): tela so informativa, sem remapeamento. `back` decide para
# onde "Voltar" leva (menu principal fecha o modal; pausa volta ao menu de pausa).
var _controls_back := Callable()

func show_controls(back: Callable, tips: String = "") -> void:
	var box := _modal("Controles")
	_controls_back = back
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 8)
	for row in CONTROLS:
		grid.add_child(_label(row[0], 19, GOLD))
		grid.add_child(_label(row[1], 19))
	box.add_child(grid)
	if tips != "":
		box.add_child(_label(tips, 16))
	_button(box, "Voltar", _leave_controls).grab_focus()

func _leave_controls() -> void:
	var back := _controls_back
	_controls_back = Callable()
	if back.is_valid():
		back.call()

func _is_showing_controls() -> bool:
	return _controls_back.is_valid() and is_instance_valid(overlay)

func start_game() -> void:
	tutorial_mode = false # start_tutorial() liga de novo depois
	_cancel_channel()
	get_tree().paused = false
	DayNightManager.reset_session(true)
	if is_instance_valid(world):
		world.get_node("WaveManager").cancel_wave()
		remove_child(world)
		world.queue_free()
	_clear_ui()
	_free_menu_backdrop()
	screen = "playing"
	world = WORLD.instantiate()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Spec 007: cursor livre para mirar
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
	overlay.modulate.a = 0.0 # transicao discreta de entrada
	overlay.create_tween().tween_property(overlay, "modulate:a", 1.0, 0.15)
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
	_show_pause_menu()

# Monta so o modal; a pausa da arvore ja foi feita em pause_game().
func _show_pause_menu() -> void:
	_controls_back = Callable()
	var box := _modal("Uma pausa no refúgio")
	box.add_child(_label("A arena e a domesticação estão pausadas.", 18))
	_button(box, "Retomar", resume_game).grab_focus()
	_button(box, "Controles", func(): show_controls(_show_pause_menu))
	_button(box, "Configurações", func(): show_settings(_show_pause_menu))
	_add_volume(box)
	_button(box, "Reiniciar", restart)
	_button(box, "Sair do tutorial" if tutorial_mode else "Menu", show_menu)

func resume_game() -> void:
	_controls_back = Callable()
	_close_overlay()
	screen = "playing"
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Spec 007: cursor livre para mirar
	audio.set_paused_mix(false)

# RF-AGE-016: a derrota continua encerrando a sessao com tela propria.
func _defeat() -> void:
	_cancel_channel()
	_controls_back = Callable()
	screen = "defeat"
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	audio.result(false)
	var box := _modal("O refúgio caiu")
	box.add_child(_label("A base perdeu toda a vida.\nPrepare aliados e lute ao lado deles na próxima tentativa.", 20))
	_button(box, "Reiniciar", restart).grab_focus()
	_button(box, "Menu", show_menu)

# Spec 008 (RF-UI-001): vencer a noite nao pausa nem abre modal. O estado ja
# voltou a DIA (DayNightManager); aqui so ha o jingle e um aviso passageiro.
func _victory() -> void:
	audio.result(true)
	_show_toast("DawnToast", "AMANHECEU  ·  DIA %d" % DayNightManager.day_number, GOLD)

# Spec 013 (RF-CIC-002): um unico aviso, 20 s antes das 18:00. Nao pisca, nao
# pausa, some sozinho; a contagem final fica no painel de fase.
func _night_warning() -> void:
	_show_toast("NightWarningToast", "A NOITE SE APROXIMA", EMBER)

func _input(event: InputEvent) -> void:
	# Spec 013D: I = inventario, B = construcao (nao pausam o mundo).
	if screen == "playing" and is_instance_valid(inventory_panel) and not event.is_echo():
		if event.is_action_pressed("inventory_toggle"):
			toggle_inventory()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("build_menu"):
			if _placer().is_placing(): _placer().cancel()
			else: toggle_build_menu()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		# Spec 013D: ESC fecha primeiro a construcao/inventario; so depois pausa.
		if screen == "playing" and _close_build_ui(): pass
		elif screen == "playing": pause_game()
		elif screen == "paused" and _is_showing_controls(): _leave_controls()
		elif screen == "paused": resume_game()
		elif screen == "menu":
			_close_overlay()
			if is_instance_valid(audio_popup): audio_popup.hide()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and screen == "playing":
		pause_game()

# ---------------------------------------------------------------------------
# HUD da partida: scenes/ui/hud.gd (uma nova a cada partida). Os campos abaixo
# so encaminham para ela, para que menus, testes e ferramentas continuem lendo
# app.wood_text, app.build_panel etc. como antes da extracao.
# ---------------------------------------------------------------------------
const GameHud := preload("res://scenes/ui/hud.gd")

func _build_hud() -> void:
	hud = GameHud.new()
	ui.add_child(hud)
	hud.build(self, world)

func _hud_field(field: StringName) -> Variant:
	return hud.get(field) if is_instance_valid(hud) else null

var base_text: Label:
	get: return _hud_field(&"base_text")
var base_bar: ProgressBar:
	get: return _hud_field(&"base_bar")
var player_text: Label:
	get: return _hud_field(&"player_text")
var player_bar: ProgressBar:
	get: return _hud_field(&"player_bar")
var death_toast: Control:
	get: return _hud_field(&"death_toast")
var death_text: Label:
	get: return _hud_field(&"death_text")
var wave_text: Label:
	get: return _hud_field(&"wave_text")
var clock_text: Label:
	get: return _hud_field(&"clock_text")
var countdown_text: Label:
	get: return _hud_field(&"countdown_text")
var objective: Label:
	get: return _hud_field(&"objective")
var phase_text: Label:
	get: return _hud_field(&"phase_text")
var channel_bar: ProgressBar:
	get: return _hud_field(&"channel_bar")
var hint: Label:
	get: return _hud_field(&"hint")
var points_text: Label:
	get: return _hud_field(&"points_text")
var points_box: Control:
	get: return _hud_field(&"points_box")
var build_panel: PanelContainer:
	get: return _hud_field(&"build_panel")
var build_title: Label:
	get: return _hud_field(&"build_title")
var build_info: Label:
	get: return _hud_field(&"build_info")
var build_note: Label:
	get: return _hud_field(&"build_note")
var build_button: Button:
	get: return _hud_field(&"build_button")
var wood_text: Label:
	get: return _hud_field(&"wood_text")
var stone_text: Label:
	get: return _hud_field(&"stone_text")
var territory_text: Label:
	get: return _hud_field(&"territory_text")
var onda_text: Label:
	get: return _hud_field(&"onda_text")
var inventory_panel: PanelContainer:
	get: return _hud_field(&"inventory_panel")
var build_menu_panel: PanelContainer:
	get: return _hud_field(&"build_menu_panel")
var inv_wood_text: Label:
	get: return _hud_field(&"inv_wood_text")
var inv_stone_text: Label:
	get: return _hud_field(&"inv_stone_text")
var placement_panel: PanelContainer:
	get: return _hud_field(&"placement_panel")
var placement_title: Label:
	get: return _hud_field(&"placement_title")
var placement_note: Label:
	get: return _hud_field(&"placement_note")
var _recipe_rows: Dictionary:
	get: return hud._recipe_rows if is_instance_valid(hud) else {}

func toggle_inventory() -> void:
	hud.toggle_inventory()

func toggle_build_menu() -> void:
	hud.toggle_build_menu()

func _start_placement(id: StringName) -> void:
	hud._start_placement(id)

func _close_build_ui() -> bool:
	return is_instance_valid(hud) and hud._close_build_ui()

func _placer() -> Node:
	return world.get_node("BuildPlacer") if is_instance_valid(world) else null

func _show_toast(toast_name: String, text: String, color: Color) -> void:
	if is_instance_valid(hud):
		hud._show_toast(toast_name, text, color)

# ---------------------------------------------------------------------------
# Spec 022 — Tutorial jogavel: a mesma partida, com um TutorialDirector so
# neste mundo. Reiniciar repete o modo atual; Menu/JOGAR voltam ao jogo normal
# (DayNightManager.reset_session() solta o relogio).
# ---------------------------------------------------------------------------
const TutorialDirector := preload("res://scenes/world/tutorial_director.gd")
var tutorial_mode := false
var tutorial: Node

func start_tutorial() -> void:
	start_game()
	tutorial_mode = true
	tutorial = TutorialDirector.new()
	tutorial.name = "Tutorial"
	world.add_child(tutorial)
	tutorial.setup(self, world)

func restart() -> void:
	if tutorial_mode:
		start_tutorial()
	else:
		start_game()

func tutorial_finished() -> void:
	_cancel_channel()
	_controls_back = Callable()
	screen = "tutorial_done"
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	audio.result(true)
	var box := _modal("Tutorial concluído!")
	box.add_child(_label("Você andou, lutou, domesticou, coletou, construiu,\nergueu uma torre, posicionou um aliado e defendeu o Refúgio.\n\nA partida normal começa com 2 guardiões, 3 invasores\nna primeira noite e o relógio correndo desde as 08:00.", 18))
	_button(box, "Jogar partida", start_game).grab_focus()
	_button(box, "Menu", show_menu)

# ---------------------------------------------------------------------------
# Configuracoes (menu principal e pausa). Cada mudanca vale na hora e e salva.
# ESC/Voltar retornam para quem abriu (mesmo mecanismo da tela de Controles).
# ---------------------------------------------------------------------------
const Settings := preload("res://scenes/ui/settings.gd")
var settings_controls := {} # nome -> controle (testes)

func _settings_slider(box: Node, title: String, key: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := _label(title, 19)
	label.custom_minimum_size.x = 190
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = float(Settings.values[key]) * 100.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(260, 26)
	var value := _label("%d%%" % int(slider.value), 17, GOLD)
	value.custom_minimum_size.x = 56
	slider.value_changed.connect(func(v):
		value.text = "%d%%" % int(v)
		Settings.set_value(key, v / 100.0, audio, get_window()))
	row.add_child(slider)
	row.add_child(value)
	box.add_child(row)
	settings_controls[key] = slider
	return slider

func show_settings(back: Callable) -> void:
	var box := _modal("Configurações")
	_controls_back = back
	settings_controls = {}
	box.add_child(_label("ÁUDIO", 15, JADE))
	_settings_slider(box, "Volume geral", "master").grab_focus()
	_settings_slider(box, "Música", "music")
	_settings_slider(box, "Efeitos", "sfx")
	box.add_child(_label("TELA", 15, JADE))
	var full := CheckButton.new()
	full.text = "Tela cheia"
	full.add_theme_font_size_override("font_size", 19)
	full.button_pressed = bool(Settings.values.fullscreen)
	full.toggled.connect(func(on): Settings.set_value("fullscreen", on, audio, get_window()))
	box.add_child(full)
	settings_controls["fullscreen"] = full
	var scale_row := HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 16)
	var scale_label := _label("Escala da interface", 19)
	scale_label.custom_minimum_size.x = 190
	scale_row.add_child(scale_label)
	var scale := OptionButton.new()
	for s in Settings.UI_SCALES:
		scale.add_item("%d%%" % int(round(s * 100.0)))
	scale.selected = maxi(0, Settings.UI_SCALES.find(float(Settings.values.ui_scale)))
	scale.item_selected.connect(func(i): Settings.set_value("ui_scale", Settings.UI_SCALES[i], audio, get_window()))
	scale_row.add_child(scale)
	box.add_child(scale_row)
	settings_controls["ui_scale"] = scale
	box.add_child(_label("As mudanças valem na hora e ficam salvas.", 14, Color(CREAM, .6)))
	_button(box, "Restaurar padrão", func():
		Settings.reset(audio, get_window())
		show_settings(back))
	_button(box, "Voltar", _leave_controls)
