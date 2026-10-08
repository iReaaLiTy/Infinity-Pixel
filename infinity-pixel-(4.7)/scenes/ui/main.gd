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
var base_text: Label
var base_bar: ProgressBar
var player_text: Label # Spec 011 (RF-VID-006)
var player_bar: ProgressBar
var death_toast: Control
var death_text: Label
var wave_text: Label
var clock_text: Label # Spec 013
var countdown_text: Label
var objective: Label
var phase_text: Label
var channel_bar: ProgressBar
var hint: Label
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
	death_toast = null
	audio_popup = null

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
	var gap3 := Control.new()
	gap3.custom_minimum_size.y = 26
	column.add_child(gap3)
	_menu_button(column, "SAIR", 17, Color("2a3d37"), Color("15211d"), 5, 10, 22, 4, func(): get_tree().quit())
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

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	# Spec 013C (RF-HUD-001): HUD compacta em tres grupos separados — esquerda
	# (vida), centro (tempo), direita (recursos) — no lugar da faixa continua.
	# Esquerda: JOGADOR / REFUGIO, rotulo e valor na mesma linha, barra fina.
	var health := VBoxContainer.new()
	health.add_theme_constant_override("separation", 2)
	health.custom_minimum_size.x = 200
	player_text = _label("JOGADOR  100 / 100", 13, CREAM)
	health.add_child(player_text)
	player_bar = _hud_bar(health, EMBER)
	var gap := Control.new()
	gap.custom_minimum_size.y = 3
	health.add_child(gap)
	base_text = _label("REFÚGIO  100 / 100", 13, CREAM)
	health.add_child(base_text)
	base_bar = _hud_bar(health, JADE)
	var left := _hud_panel(hud, health)
	left.name = "HealthPanel"
	left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	left.position = Vector2(16, 14)
	# Centro: "DIA 1 • 08:58" / "PREPARAÇÃO · Noites: 0" (+ onda a noite).
	var phase := VBoxContainer.new()
	phase.add_theme_constant_override("separation", 0)
	var phase_row := HBoxContainer.new()
	phase_row.alignment = BoxContainer.ALIGNMENT_CENTER
	phase_row.add_theme_constant_override("separation", 8)
	phase.add_child(phase_row)
	phase_text = _label("DIA 1", 17, GOLD)
	phase_text.add_theme_font_override("font", _display_font())
	phase_row.add_child(phase_text)
	phase_row.add_child(_label("•", 15, GOLD))
	clock_text = _label("08:00", 17, CREAM)
	clock_text.add_theme_font_override("font", _display_font())
	phase_row.add_child(clock_text)
	wave_text = _label("PREPARAÇÃO  ·  Noites: 0", 12, CREAM)
	wave_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase.add_child(wave_text)
	onda_text = _label("", 12, Color("f0c9a0"))
	onda_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	onda_text.hide()
	phase.add_child(onda_text)
	countdown_text = _label("", 14, EMBER)
	countdown_text.add_theme_font_override("font", _display_font())
	countdown_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_text.hide()
	phase.add_child(countdown_text)
	var center := _hud_panel(hud, phase)
	center.name = "PhasePanel"
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.offset_top = 14
	center.offset_bottom = 14
	# Direita: Pontos de Defesa, Madeira e Pedra, icone + numero + legenda curta.
	_build_points_panel(hud)
	# Spec 008 (RF-UI-002): sem tutorial permanente. So objetivo atual + dica de
	# contexto (alvo/aliado proximo) + barra de canalizacao, num painel compacto
	# centralizado que cresce conforme o texto.
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	var panel := _panel(hud, bottom)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_top = -16
	panel.offset_bottom = -16
	objective = _label("", 17, GOLD)
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(objective)
	hint = _label("", 15)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(hint)
	channel_bar = ProgressBar.new()
	channel_bar.max_value = 1.0
	channel_bar.show_percentage = false
	channel_bar.custom_minimum_size = Vector2(320, 8)
	bottom.add_child(channel_bar)
	_build_defense_panel()
	_ignore_mouse(hud)
	# Spec 007 (RF-CAM-004): com o cursor visivel, clicar sobre os paineis da HUD
	# e clicar na interface — o painel consome o clique e o Player nao ataca.
	for p in hud.find_children("*", "PanelContainer", true, false):
		p.mouse_filter = Control.MOUSE_FILTER_STOP
	build_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_build_inventory_panels() # Spec 013D (depois do _ignore_mouse: botoes clicaveis)
	# Spec 013B: a HUD so exibe os pontos (fonte: DefenseEconomy do mundo).
	var economy = world.get_node("DefenseEconomy")
	economy.points_changed.connect(_on_points_changed)
	var stock = world.get_node("ResourceStock")
	stock.resources_changed.connect(_on_resources_changed)
	wood_text.text = str(stock.get_amount(&"wood"))
	stone_text.text = str(stock.get_amount(&"stone"))
	_on_points_changed(economy.points, 0)
	world.get_node("DefenseSlots").notice.connect(_show_defense_notice)
	# Spec 015: territorios (a HUD so exibe; fonte: TerritoryManager do mundo).
	var territories = world.get_node("TerritoryManager")
	territories.state_changed.connect(func(_id, _s): _update_territory_count())
	territories.claimed.connect(func(_id, title: String): _show_toast("TerritoryNotice", "%s RECUPERADA" % title, JADE))
	territories.region_entered.connect(_on_region_entered)
	territories.claim_cancelled.connect(func(reason: String): _show_toast("TerritoryNotice", "Recuperação cancelada (%s)" % reason, EMBER))
	_update_territory_count()
	# Spec 011 (RF-VID-006): a vida do jogador reage a sinais, sem consulta por quadro.
	var player = world.get_node("Player")
	player.health_changed.connect(_on_player_health)
	player.died.connect(_on_player_died)
	player.respawned.connect(_on_player_respawned)
	_on_player_health(player.current_hp, player.max_hp)

# ---------------------------------------------------------------------------
# Spec 013B — Pontos de Defesa e pontos de construcao (HUD so exibe/encaminha)
# ---------------------------------------------------------------------------
var points_text: Label
var points_box: Control
var build_panel: PanelContainer
var build_title: Label
var build_info: Label
var build_note: Label
var build_button: Button
var _build_slot: Node3D

var wood_text: Label # Spec 013C
var stone_text: Label
var territory_text: Label # Spec 015: "1/3"
var onda_text: Label
var _resource_items := {} # kind -> Control (posicao do "+N")

# Painel compacto (margens menores que _panel) para a HUD de jogo.
func _hud_panel(parent: Node, box: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.04, .12, .115, .82)
	style.border_color = Color("456c59")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 7
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	p.add_child(box)
	return p

func _hud_bar(parent: Node, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 6
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	var back := StyleBoxFlat.new()
	back.bg_color = Color("17332f")
	back.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	parent.add_child(bar)
	return bar

# Icones vetoriais pequenos: tora (madeira) e bloco (pedra).
func _resource_icon(kind: StringName, size: float) -> Control:
	if kind == &"defense":
		return _crystal(size)
	if kind == &"territory": # Spec 015: marco (pedestal + cristal)
		var m := Control.new()
		m.custom_minimum_size = Vector2(size, size)
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		m.draw.connect(func():
			var s := m.size
			m.draw_rect(Rect2(s.x * .2, s.y * .74, s.x * .6, s.y * .18), Color("8d9a8f"))
			m.draw_rect(Rect2(s.x * .36, s.y * .5, s.x * .28, s.y * .26), Color("7c8980"))
			m.draw_colored_polygon(PackedVector2Array([Vector2(s.x * .5, s.y * .04), Vector2(s.x * .7, s.y * .27), Vector2(s.x * .5, s.y * .5), Vector2(s.x * .3, s.y * .27)]), Color("7fe0b8")))
		return m
	var c := Control.new()
	c.custom_minimum_size = Vector2(size, size)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.draw.connect(func():
		var s := c.size
		if kind == &"wood":
			c.draw_rect(Rect2(s.x * .08, s.y * .3, s.x * .72, s.y * .42), Color("8a6440"))
			c.draw_circle(Vector2(s.x * .78, s.y * .51), s.y * .21, Color("d9b98a"))
			c.draw_arc(Vector2(s.x * .78, s.y * .51), s.y * .11, 0, TAU, 10, Color("8a6440"), 1.5)
		else:
			var pts := PackedVector2Array()
			for i in 6:
				var a := TAU * i / 6.0 + .3
				pts.append(s * .5 + Vector2(cos(a) * s.x * .42, sin(a) * s.y * .36))
			c.draw_colored_polygon(pts, Color("9aa79d"))
			c.draw_colored_polygon(PackedVector2Array([s * .5, s * .5 + Vector2(s.x * .3, -s.y * .2), s * .5 + Vector2(s.x * .1, s.y * .25)]), Color("6e8aa3")))
	return c

func _resource_item(row: Node, kind: StringName, caption: String, color: Color) -> Label:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", 5)
	item.add_child(_resource_icon(kind, 20))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -5)
	var value := _label("0", 16, color)
	value.add_theme_font_override("font", _display_font())
	col.add_child(value)
	col.add_child(_label(caption, 9, Color(CREAM, .75)))
	item.add_child(col)
	row.add_child(item)
	_resource_items[kind] = item
	return value

func _build_points_panel(parent: Node) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	points_text = _resource_item(row, &"defense", "DEFESA", Color("aef0cf"))
	wood_text = _resource_item(row, &"wood", "MADEIRA", Color("e6c79a"))
	stone_text = _resource_item(row, &"stone", "PEDRA", Color("c9d3cc"))
	territory_text = _resource_item(row, &"territory", "TERRITÓRIOS", Color("9fe0c0")) # Spec 015
	points_box = _hud_panel(parent, row)
	points_box.name = "PointsPanel"
	points_box.tooltip_text = "Pontos de Defesa · Madeira · Pedra · Territórios recuperados"
	points_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	points_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	points_box.offset_right = -16
	points_box.offset_top = 14
	var esc := _label("ESC  pausa", 11, Color(CREAM, .85))
	esc.add_theme_color_override("font_outline_color", Color("10221e"))
	esc.add_theme_constant_override("outline_size", 4) # legivel em fundo claro
	esc.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	esc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	esc.offset_right = -20
	esc.offset_top = 66
	parent.add_child(esc)

func _on_points_changed(total: int, delta: int) -> void:
	if not is_instance_valid(points_text):
		return
	points_text.text = str(total)
	if delta > 0:
		_show_gain("PointsGain", &"defense", "+%d PONTOS" % delta, GOLD)

func _on_resources_changed(kind: StringName, total: int, delta: int) -> void:
	var label: Label = wood_text if kind == &"wood" else stone_text
	if not is_instance_valid(label):
		return
	label.text = str(total)
	if delta > 0:
		_show_gain("WoodGain" if kind == &"wood" else "StoneGain", kind, "+%d %s" % [delta, "MADEIRA" if kind == &"wood" else "PEDRA"], Color("e6c79a") if kind == &"wood" else Color("c9d3cc"))

# RF-HUD-002: "+N" pequeno logo abaixo do item, ~1 s, sem mudar o painel.
func _show_gain(node_name: String, kind: StringName, text: String, color: Color) -> void:
	var gain := _label(text, 14, color)
	gain.add_theme_font_override("font", _display_font())
	gain.add_theme_color_override("font_outline_color", Color("10221e"))
	gain.add_theme_constant_override("outline_size", 4)
	gain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(gain)
	gain.name = node_name # depois do add_child, como os avisos (senao vira @Label@N)
	var item: Control = _resource_items.get(kind, points_box)
	# Abaixo do "ESC pausa" e nunca passando da borda direita da tela.
	var width := gain.get_minimum_size().x
	var x := minf(item.global_position.x, hud.size.x - width - 12.0)
	gain.global_position = Vector2(x, points_box.global_position.y + points_box.size.y + 34)
	var t := gain.create_tween().set_parallel()
	t.tween_property(gain, "position:y", gain.position.y - 14, 1.0)
	t.tween_property(gain, "modulate:a", 0.0, 1.0).set_delay(.4)
	t.chain().tween_callback(gain.queue_free)

# Painel contextual: so aparece perto de um ponto de defesa. Fica acima do
# painel de objetivo, nunca no centro da tela.
func _build_defense_panel() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	build_title = _label("TORRE DE DEFESA", 18, GOLD)
	build_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(build_title)
	build_info = _label("", 15)
	build_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(build_info)
	build_button = _menu_button(box, "CONSTRUIR", 18, Color("e9a23b"), Color("8a4f19"), 6, 12, 22, 4, func():
		if is_instance_valid(_build_slot):
			world.get_node("DefenseSlots").interact(_build_slot))
	build_button.focus_mode = Control.FOCUS_NONE # C e clique; nao rouba teclas
	build_note = _label("", 14, EMBER)
	build_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(build_note)
	build_panel = _panel(hud, box)
	build_panel.name = "DefensePanel"
	build_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	build_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	build_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	build_panel.offset_top = -120
	build_panel.offset_bottom = -120
	build_panel.hide()

func _update_defense_panel() -> void:
	var slots = world.get_node("DefenseSlots")
	_build_slot = slots.nearest_slot()
	build_panel.visible = _build_slot != null
	if _build_slot == null:
		return
	var reason: String = slots.block_reason(_build_slot)
	var cost: int = slots.action_cost(_build_slot)
	if _build_slot.is_empty():
		build_title.text = "PONTO DE CONSTRUÇÃO"
		build_info.text = "Torre de Defesa  ·  Custo: %d" % cost
		build_button.text = "[C]  CONSTRUIR"
	else:
		var tower = _build_slot.tower
		var s: Dictionary = tower.stats()
		build_title.text = "TORRE DE DEFESA  ·  NÍVEL %d" % tower.level
		build_info.text = "Dano: %d  ·  Alcance: %d" % [s.damage, s.range]
		build_button.text = "NÍVEL MÁXIMO" if tower.is_max_level() else "MELHORAR — %d  (C)" % cost
	build_button.disabled = reason != ""
	build_note.text = reason if reason != "NÍVEL MÁXIMO" else ""
	build_note.visible = build_note.text != ""

# ---------------------------------------------------------------------------
# Spec 013D — Inventario (I), menu de construcao (B) e posicionamento.
# A HUD so exibe: recursos vem do ResourceStock; regras/limites do BuildPlacer.
# ---------------------------------------------------------------------------
const BuildRecipes := preload("res://scenes/world/build_recipes.gd")
var inventory_panel: PanelContainer
var build_menu_panel: PanelContainer
var inv_wood_text: Label
var inv_stone_text: Label
var placement_panel: PanelContainer
var placement_title: Label
var placement_note: Label
var _recipe_rows := {} # painel -> {recipe_id: {"button", "status"}}

func _placer() -> Node:
	return world.get_node("BuildPlacer") if is_instance_valid(world) else null

func _cost_line(parent: Node, wood: int, stone: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.add_child(_resource_icon(&"wood", 15))
	row.add_child(_label("%d Madeira" % wood, 13, Color("e6c79a")))
	row.add_child(_label("•", 13, Color(CREAM, .6)))
	row.add_child(_resource_icon(&"stone", 15))
	row.add_child(_label("%d Pedra" % stone, 13, Color("c9d3cc")))
	parent.add_child(row)

func _recipe_list(box: VBoxContainer, rows: Dictionary) -> void:
	for id in BuildRecipes.order():
		var r := BuildRecipes.get_recipe(id)
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 2)
		entry.add_child(_label(r.name, 15, GOLD))
		_cost_line(entry, r.wood, r.stone)
		var line := HBoxContainer.new()
		var status := _label("", 12, EMBER)
		status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(status)
		var button := _menu_button(line, "CONSTRUIR", 14, Color("e9a23b"), Color("8a4f19"), 5, 9, 14, 2, func(): _start_placement(id))
		button.focus_mode = Control.FOCUS_NONE
		entry.add_child(line)
		box.add_child(entry)
		rows[id] = {"button": button, "status": status}

func _side_panel(title: String, box: VBoxContainer) -> PanelContainer:
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size.x = 260
	var head := _label(title, 17, GOLD)
	head.add_theme_font_override("font", _display_font())
	box.add_child(head)
	box.move_child(head, 0)
	var p := _hud_panel(hud, box)
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.offset_right = -16
	p.offset_top = 112 # abaixo dos recursos e do "+N"; nao cresce a HUD do topo
	p.mouse_filter = Control.MOUSE_FILTER_STOP # clique no painel nao ataca
	p.hide()
	return p

func _build_inventory_panels() -> void:
	_recipe_rows = {} # a HUD e recriada a cada partida: nada da anterior (ja liberado)
	# INVENTARIO (I): recursos + receitas. Nao pausa o mundo.
	var inv := VBoxContainer.new()
	for kind in [&"wood", &"stone"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_resource_icon(kind, 20))
		var name_label := _label("MADEIRA" if kind == &"wood" else "PEDRA", 15)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var value := _label("0", 17, Color("e6c79a") if kind == &"wood" else Color("c9d3cc"))
		value.add_theme_font_override("font", _display_font())
		row.add_child(value)
		inv.add_child(row)
		if kind == &"wood": inv_wood_text = value
		else: inv_stone_text = value
	inv.add_child(_label("CONSTRUÇÕES", 12, JADE))
	var inv_rows := {}
	_recipe_list(inv, inv_rows)
	inv.add_child(_label("I fecha  ·  B constrói direto", 11, Color(CREAM, .6)))
	inventory_panel = _side_panel("INVENTÁRIO", inv)
	inventory_panel.name = "InventoryPanel"
	_recipe_rows[inventory_panel] = inv_rows
	# CONSTRUCAO (B): so as receitas, compacto.
	var bm := VBoxContainer.new()
	var bm_rows := {}
	_recipe_list(bm, bm_rows)
	bm.add_child(_label("B fecha", 11, Color(CREAM, .6)))
	build_menu_panel = _side_panel("CONSTRUIR", bm)
	build_menu_panel.name = "BuildMenuPanel"
	_recipe_rows[build_menu_panel] = bm_rows
	# Dica do posicionamento (mesmo lugar do painel de ponto de defesa).
	var pbox := VBoxContainer.new()
	pbox.add_theme_constant_override("separation", 2)
	placement_title = _label("", 16, GOLD)
	placement_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pbox.add_child(placement_title)
	var keys := _label("Clique: construir  ·  R: girar  ·  Botão direito / ESC: cancelar", 12)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pbox.add_child(keys)
	placement_note = _label("", 13, EMBER)
	placement_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pbox.add_child(placement_note)
	placement_panel = _hud_panel(hud, pbox)
	placement_panel.name = "PlacementPanel"
	placement_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	placement_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	placement_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	placement_panel.offset_top = -100
	placement_panel.offset_bottom = -100
	_ignore_mouse(placement_panel) # dica nunca bloqueia o clique de construir
	placement_panel.hide()
	var stock = world.get_node("ResourceStock")
	stock.resources_changed.connect(func(_k, _t, _d): _refresh_inventory()) # RF-INV-001: por sinal
	var placer := _placer()
	placer.notice.connect(func(text: String): _show_toast("BuildNotice", text, GOLD if text.ends_with("CONSTRUÍDA") else EMBER))
	placer.structure_built.connect(_on_structure_built)
	_refresh_inventory()

func _refresh_inventory() -> void:
	if not is_instance_valid(inv_wood_text) or not is_instance_valid(world):
		return
	var stock = world.get_node("ResourceStock")
	inv_wood_text.text = str(stock.get_amount(&"wood"))
	inv_stone_text.text = str(stock.get_amount(&"stone"))
	var placer := _placer()
	for panel in _recipe_rows:
		for id in _recipe_rows[panel]:
			var reason: String = placer.recipe_block_reason(id)
			_recipe_rows[panel][id].status.text = reason
			_recipe_rows[panel][id].button.disabled = reason != ""

func toggle_inventory() -> void:
	build_menu_panel.hide()
	inventory_panel.visible = not inventory_panel.visible
	_refresh_inventory()

func toggle_build_menu() -> void:
	inventory_panel.hide()
	build_menu_panel.visible = not build_menu_panel.visible
	_refresh_inventory()

func _start_placement(id: StringName) -> void:
	inventory_panel.hide()
	build_menu_panel.hide()
	_placer().begin(id)

## ESC: fecha posicionamento/paineis antes de pausar. true = consumiu.
func _close_build_ui() -> bool:
	if not is_instance_valid(world) or not is_instance_valid(inventory_panel):
		return false
	if _placer().is_placing():
		_placer().cancel()
		return true
	if inventory_panel.visible or build_menu_panel.visible:
		inventory_panel.hide()
		build_menu_panel.hide()
		return true
	return false

func _update_build_ui() -> void:
	if not is_instance_valid(placement_panel):
		return
	var placer := _placer()
	placement_panel.visible = placer.is_placing()
	if placer.is_placing():
		build_panel.hide() # o painel de torre nao disputa o mesmo lugar
		placement_title.text = "POSICIONANDO: %s" % BuildRecipes.get_recipe(placer.recipe_id).name
		placement_note.text = "" if placer.ghost_valid else placer.ghost_reason
	if inventory_panel.visible or build_menu_panel.visible:
		_refresh_inventory() # status (dia/noite, limite) so com o painel aberto

func _on_structure_built(id: StringName, node: Node3D) -> void:
	_refresh_inventory()
	if id == BuildRecipes.CAMPFIRE:
		node.heal_completed.connect(func(amount): _show_toast("HealNotice", "CURADO  +%d" % amount, JADE))
		node.heal_cancelled.connect(func(reason): _show_toast("HealNotice", "Cura cancelada (%s)" % reason, EMBER))

# Spec 015 (RF-TER-012): "TERRITORIOS 1/3" no painel da direita.
func _update_territory_count() -> void:
	var territories = world.get_node_or_null("TerritoryManager")
	if territories == null or not is_instance_valid(territory_text):
		return
	territory_text.text = "%d/%d" % [territories.controlled_count(), territories.total_count()]

# Spec 015 (RF-TER-011): nome da regiao + estado, pequeno e temporario.
func _on_region_entered(_id: StringName, title: String, state: int) -> void:
	var controlled: bool = state == 2
	_show_toast("RegionNotice", "%s  ·  %s" % [title, "Território controlado" if controlled else ("Pronto para ser recuperado" if state == 1 else "Território selvagem")], JADE if controlled else (GOLD if state == 1 else CREAM))

func _show_defense_notice(text: String) -> void:
	_show_toast("DefenseNotice", text, EMBER)

func _on_player_health(current: float, maximum: float) -> void:
	if not is_instance_valid(player_bar):
		return
	var hurt := current < player_bar.value and player_bar.max_value == maximum
	player_bar.max_value = maximum
	player_bar.value = current
	player_text.text = "JOGADOR  %d / %d" % [ceili(current), int(maximum)]
	if hurt: # tinta breve na barra e no texto; nada na camera
		for node in [player_bar, player_text]:
			node.modulate = Color(1.0, .45, .4)
			node.create_tween().tween_property(node, "modulate", Color.WHITE, .35)

# RF-VID-007: aviso pequeno e passageiro, sem modal e sem pausar.
func _on_player_died() -> void:
	if not is_instance_valid(hud):
		return
	var box := VBoxContainer.new()
	death_text = _label("", 19, EMBER)
	box.add_child(death_text)
	death_toast = _panel(hud, box)
	death_toast.name = "DeathToast"
	death_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	death_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	death_toast.offset_top = 170
	death_toast.offset_bottom = 170
	_ignore_mouse(death_toast)
	_update_death_toast()

func _update_death_toast() -> void:
	if not is_instance_valid(death_toast) or not is_instance_valid(world):
		return
	var left: float = world.get_node("Player").respawn_time_left()
	death_text.text = "VOCÊ CAIU  ·  retornando ao ponto inicial em %d…" % maxi(ceili(left), 1)

func _on_player_respawned() -> void:
	if is_instance_valid(death_toast):
		death_toast.queue_free()
	death_toast = null

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
	_show_pause_menu()

# Monta so o modal; a pausa da arvore ja foi feita em pause_game().
func _show_pause_menu() -> void:
	_controls_back = Callable()
	var box := _modal("Uma pausa no refúgio")
	box.add_child(_label("A arena e a domesticação estão pausadas.", 18))
	_button(box, "Retomar", resume_game).grab_focus()
	_button(box, "Controles", func(): show_controls(_show_pause_menu))
	_add_volume(box)
	_button(box, "Reiniciar", start_game)
	_button(box, "Menu", show_menu)

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
	_button(box, "Reiniciar", start_game).grab_focus()
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

func _show_toast(toast_name: String, text: String, color: Color) -> void:
	if not is_instance_valid(hud):
		return
	var box := VBoxContainer.new()
	box.add_child(_label(text, 20, color))
	var toast := _panel(hud, box)
	toast.name = toast_name
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.offset_top = 112
	toast.offset_bottom = 112
	_ignore_mouse(toast) # aviso nunca bloqueia cliques no mundo
	var fade := toast.create_tween()
	fade.tween_interval(DAWN_TOAST_TIME)
	fade.tween_property(toast, "modulate:a", 0.0, 0.5)
	fade.tween_callback(toast.queue_free)

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

func _process(_delta: float) -> void:
	if not is_instance_valid(world) or not is_instance_valid(hud):
		return
	_update_death_toast() # so a contagem do aviso; nada roda sem o aviso aberto
	_update_defense_panel() # Spec 013B: painel contextual do ponto de defesa
	var base = world.get_node("Territory")
	base_bar.max_value = base.max_health
	base_bar.value = base.health
	base_text.text = "REFÚGIO  %d / %d" % [base.health, base.max_health]
	var wave: Dictionary = world.get_node("WaveManager").snapshot()
	var day: int = DayNightManager.day_number
	phase_text.text = ("NOITE %d" if DayNightManager.is_night() else "DIA %d") % day # 013C: "DIA 1 • 08:58"
	clock_text.text = DayNightManager.clock_text()
	if DayNightManager.is_night():
		wave_text.text = "DEFESA  ·  Noites: %d" % victory_count
		onda_text.text = "%d/%d criados  ·  %d neutralizados  ·  %d ativos" % [wave.spawned, wave.total, wave.resolved, wave.active]
		onda_text.show()
	else:
		wave_text.text = "PREPARAÇÃO  ·  Noites: %d" % victory_count
		onda_text.hide()
	# RF-CIC-002: ultimos segundos antes das 18:00, sem modal nem bloqueio.
	var left: float = DayNightManager.seconds_until_night()
	countdown_text.visible = DayNightManager.is_day() and left > 0.0 and left <= DayNightManager.night_countdown_seconds
	if countdown_text.visible:
		countdown_text.text = "ANOITECE EM %d" % ceili(left)
	var player = world.get_node("Player")
	var channel = player.get_node("DomesticationChannel")
	channel_bar.value = channel.get_progress()
	var allies := get_tree().get_nodes_in_group("domesticated")
	# Spec 008 (RF-UI-002): objetivo curto + dica so quando ha contexto (alvo ou
	# aliado proximo). Instrucoes de controle ficam na tela Controles.
	hint.text = ""
	if DayNightManager.is_night():
		objective.text = "Defenda o refúgio"
	elif allies.is_empty():
		objective.text = "Domestique o selvagem da clareira lateral"
		if not world.get_node("EncounterSpawner").is_encounter_wild():
			objective.text = "Encontro derrotado — prepare-se para a noite"
	else:
		objective.text = "Posicione aliados (F) antes do anoitecer  ·  Aliados: %d" % allies.size()
	# Spec 015: guardiao neutralizado -> o objetivo do dia aponta o marco.
	if DayNightManager.is_day():
		var terr = world.get_node("TerritoryManager")
		for id in terr.markers:
			if terr.state_of(id) == 1:
				objective.text = "%s pronta: segure E no marco para recuperar" % terr.info(id).name
				break
	for dino in get_tree().get_nodes_in_group("wild_dino"):
		if dino.global_position.distance_to(player.global_position) < 3.2:
			if dino.can_be_domesticated(): hint.text = "SEGURE E  ·  %.1f / 2.0 s  ·  Soltar ou afastar cancela" % (channel.get_progress()*2)
			elif not dino.is_domesticable: hint.text = "CARNOTAURO  ·  Esta variante não pode ser domesticada."
	for ally in allies:
		if ally.global_position.distance_to(player.global_position) < 3.3:
			hint.text = "ALIADO %d/80 HP  ·  %s  ·  %s" % [ally.hp, "SEGUINDO" if ally.ally_state == 0 else "DEFENDENDO POSTO", "F alterna seguir/ficar" if DayNightManager.is_day() else "Posicionamento bloqueado durante a noite"]
	# Spec 013D: Fogueira de Cura — dica de uso e barra "CURANDO..."
	var fire = get_tree().get_first_node_in_group("healing_campfire")
	var healing := 0.0
	if fire != null and fire.player_in_range():
		healing = fire.progress()
		var why: String = fire.block_reason()
		if healing > 0.0:
			hint.text = "CURANDO...  %.1f / 3.0 s  ·  Sair do alcance, apanhar ou soltar H cancela" % (healing * 3.0)
		elif why != "":
			hint.text = "FOGUEIRA  ·  %s  ·  Cargas %d/2" % [why, fire.charges]
		else:
			hint.text = "FOGUEIRA  ·  Segure H para curar (+25)  ·  Cargas %d/2" % fire.charges
	# Spec 015: marco territorial — barra "RECUPERANDO..." e dica perto do marco.
	var territories = world.get_node("TerritoryManager")
	var claim: float = territories.claim_progress()
	if claim > 0.0:
		hint.text = "RECUPERANDO TERRITÓRIO...  %.1f / 2.0 s  ·  Soltar E ou afastar cancela" % (claim * 2.0)
	elif hint.text == "":
		var near: StringName = territories.marker_near(3.0)
		if near != &"":
			var title: String = territories.info(near).name
			match territories.state_of(near):
				0: hint.text = "%s  ·  Marco inativo  ·  Derrote ou domestique o guardião" % title
				1: hint.text = ("TERRITÓRIO PRONTO PARA SER RECUPERADO  ·  Segure E para ativar" if DayNightManager.is_day() else "TERRITÓRIO PRONTO  ·  Recupere durante o dia")
				_: hint.text = "%s  ·  Território controlado" % title
	hint.visible = hint.text != ""
	channel_bar.visible = channel.get_progress() > 0.0 or healing > 0.0 or claim > 0.0
	if healing > 0.0:
		channel_bar.value = healing
	if claim > 0.0:
		channel_bar.value = claim
	_update_build_ui()
