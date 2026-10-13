extends Node

const WORLD := preload("res://scenes/world/prototype_area.tscn")
const CREAM := Color("f2e8ce")
const GOLD := Color("e7ae58")
const JADE := Color("69be9b")
# Spec 008 (RF-UI-003): comandos reais do Input Map / scripts, fonte unica para
# as telas de Controles do menu principal e da pausa. T (debug) fica de fora.
const CONTROLS := [
	["WASD", "Mover (relativo à câmera)"],
	["Mouse", "Posicionar a prévia de construção"],
	["Clique esquerdo", "Atacar para onde está olhando · WASD orienta"],
	["E (segurar 2 s)", "Domesticar a até 3 m · no marco: recuperar território (de dia)"],
	["F", "Seguir / ficar (somente de dia)"],
	["C", "Construir / melhorar torre (perto de um ponto, de dia)"],
	["I", "Mochila: recursos, construções e companheiros (abas 1, 2, 3)"],
	["B", "Construir estrutura (R gira · botão direito cancela)"],
	["H (segurar 3 s)", "Curar na Fogueira (+25, perto dela)"],
	["G", "Elixir de Jade: curar aliado ferido a até 3 m"],
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
	DayNightManager.night_started.connect(func():
		audio.change_music("combat")
		audio.play("wave_start") # 4.0: trompa grave anuncia a onda
		audio.set_ambience("night"))
	show_menu()

const UiArt := preload("res://scenes/ui/ui_art.gd")

# Visual Overhaul 3.0: tema unico "pedra e jade" para todos os menus e modais
# (botoes de pedra talhada com borda jade no hover, foco de teclado em ambar).
func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 19
	theme.set_color("font_color", "Label", CREAM)
	var styles := UiArt.button_styles(UiArt.STONE, UiArt.STONE_EDGE, 5, 9, 22, 9)
	for state in styles:
		theme.set_stylebox(state, "Button", styles[state])
		theme.set_stylebox(state, "OptionButton", styles[state])
	theme.set_color("font_color", "Button", CREAM)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", UiArt.JADE_LIGHT)
	theme.set_color("font_color", "OptionButton", CREAM)
	theme.set_color("font_color", "CheckButton", CREAM)
	theme.set_color("font_hover_color", "CheckButton", Color.WHITE)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("0d1f1a")
	bg.border_color = Color("24413b")
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = UiArt.JADE
	fg.set_corner_radius_all(4)
	theme.set_stylebox("background", "ProgressBar", bg)
	theme.set_stylebox("fill", "ProgressBar", fg)
	# Sliders: trilho de pedra, preenchimento jade, pegador de cristal.
	var track := StyleBoxFlat.new()
	track.bg_color = Color("0d1f1a")
	track.border_color = Color("2f5547")
	track.set_border_width_all(1)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = UiArt.JADE_DEEP
	filled.border_color = UiArt.JADE
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	theme.set_icon("grabber", "HSlider", _grabber_texture(false))
	theme.set_icon("grabber_highlight", "HSlider", _grabber_texture(true))
	theme.set_color("font_color", "TooltipLabel", CREAM)
	return theme

## Pegador do slider: losango de jade (gerado uma vez em imagem pequena).
func _grabber_texture(lit: bool) -> Texture2D:
	var img := Image.create(18, 22, false, Image.FORMAT_RGBA8)
	for y in 22:
		for x in 18:
			var d := absf(x - 8.5) / 9.0 + absf(y - 10.5) / 11.0
			if d <= 1.0:
				var c := UiArt.JADE_LIGHT if lit else UiArt.JADE
				img.set_pixel(x, y, c.darkened(0.35) if d > 0.78 else (c.lightened(0.25) if y < 10 else c))
	return ImageTexture.create_from_image(img)

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
	b.add_theme_font_override("font", _display_font())
	b.add_theme_font_size_override("font_size", 18)
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
	sync_cursor()
	_clear_ui()
	audio.change_music("principal") # 4.0: tema principal (composicao original, antes sem uso)
	audio.set_ambience("day")
	# Fundo = diorama 3D do Refugio (so arte). Libera o anterior: chamar
	# show_menu() com o menu ja aberto empilhava fundos (e sois) antes do 3.0.
	_free_menu_backdrop()
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
# Menu principal (Visual Overhaul 3.0 — "Expedição Pré-histórica"): coluna de
# pedra a esquerda com a marca JADEFALL e os botoes; o diorama 3D do Refugio
# (menu_backdrop.gd) fica livre a direita. Tudo ancorado, para qualquer janela.
# ---------------------------------------------------------------------------

var _font_cache: Font

## 4.0: fonte de exibicao EMBUTIDA no projeto (Lilita One, SIL Open Font
## License 1.1 — assets/fonts/OFL.txt). Antes era SystemFont (Segoe UI Black),
## que muda ou some em maquinas sem essa fonte instalada.
const DISPLAY_FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")

func _display_font() -> Font:
	if _font_cache == null:
		var font := FontVariation.new()
		font.base_font = DISPLAY_FONT
		# MSDF (na importacao da fonte): o titulo e os rotulos ficam nitidos em
		# qualquer tamanho e resolucao, com um so cache de glifos.
		font.spacing_glyph = 1
		_font_cache = font
	return _font_cache

# Botao de jogo (HUD, inventario): pedra talhada com a cor pedida, borda jade
# no hover, afunda ao clicar. Assinatura antiga mantida (HUD e inventario).
func _menu_button(parent: Node, text: String, size: int, fill: Color, edge: Color, depth: int, radius: int, h: int, v: int, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_override("font", _display_font())
	b.add_theme_font_size_override("font_size", size)
	var light := fill.get_luminance() > 0.45
	var ink := UiArt.INK if light else CREAM
	b.add_theme_color_override("font_color", ink)
	b.add_theme_color_override("font_hover_color", ink if light else Color.WHITE)
	b.add_theme_color_override("font_pressed_color", ink)
	b.add_theme_color_override("font_focus_color", ink if light else Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(CREAM, .38))
	var styles := UiArt.button_styles(fill, edge, depth, mini(radius, 10), h, v)
	for state in styles:
		b.add_theme_stylebox_override(state, styles[state])
	b.pressed.connect(action)
	parent.add_child(b)
	return b

## Marca JADEFALL desenhada: letras talhadas (extrusao em camadas escuras +
## contorno + preenchimento ambar) e o cristal do Refugio como emblema.
func _title_mark(size: int) -> Control:
	var c := Control.new()
	c.name = "TitleMark"
	c.set_meta("text", "JADEFALL")
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := _display_font()
	var text_size := font.get_string_size("JADEFALL", HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var emblem := size * 0.62
	c.custom_minimum_size = Vector2(emblem + 14 + text_size.x, size * 1.18)
	c.draw.connect(func():
		var base := size * 0.96
		var x0 := emblem + 14
		var ci := c.get_canvas_item()
		# brilho e cristal (emblema a esquerda)
		UiArt.crystal(c, Rect2(Vector2(2, size * .1), Vector2(emblem * .82, size * .98)), 1.0)
		for k in range(9, 0, -1):
			font.draw_string(ci, Vector2(x0, base + k), "JADEFALL", HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("2a160a").lerp(Color("5a3414"), 1.0 - k / 9.0))
		font.draw_string_outline(ci, Vector2(x0, base), "JADEFALL", HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(6, size / 11), Color("2a160a"))
		font.draw_string(ci, Vector2(x0, base), "JADEFALL", HORIZONTAL_ALIGNMENT_LEFT, -1, size, UiArt.AMBER_LIGHT)
		# rachaduras discretas na pedra (dao textura sem poluir)
		var crack := Color("2a160a", 0.55)
		c.draw_polyline(PackedVector2Array([Vector2(x0 + text_size.x * .18, base - size * .62), Vector2(x0 + text_size.x * .2, base - size * .44), Vector2(x0 + text_size.x * .185, base - size * .3)]), crack, 2.0)
		c.draw_polyline(PackedVector2Array([Vector2(x0 + text_size.x * .71, base - size * .7), Vector2(x0 + text_size.x * .69, base - size * .52), Vector2(x0 + text_size.x * .705, base - size * .4)]), crack, 2.0))
	return c

## Cristal facetado do Refugio (icone da HUD e das telas).
func _crystal(size: float) -> Control:
	return UiArt.drawn(Vector2(size * .62, size), func(ci: CanvasItem, r: Rect2): UiArt.crystal(ci, r))

## Placa de pedra com o subtitulo entre dois ossos fosseis.
func _subtitle_plaque(text: String, size: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bone_l := UiArt.drawn(Vector2(54, 24), func(ci: CanvasItem, r: Rect2): UiArt.bone(ci, Vector2(6, r.size.y * .5), Vector2(r.size.x - 4, r.size.y * .5), 5.0, Color(UiArt.IVORY, .85)))
	row.add_child(bone_l)
	var plaque := PanelContainer.new()
	var s := UiArt.stone_panel(0.92, UiArt.JADE, Vector4(18, 4, 18, 6), 6)
	s.shadow_size = 6
	plaque.add_theme_stylebox_override("panel", s)
	var label := _label(text, size, UiArt.IVORY)
	label.name = "Subtitle"
	label.add_theme_font_override("font", _display_font())
	label.add_theme_constant_override("outline_size", 0)
	var spaced := FontVariation.new()
	spaced.base_font = _display_font()
	spaced.spacing_glyph = 5
	label.add_theme_font_override("font", spaced)
	plaque.add_child(label)
	row.add_child(plaque)
	var bone_r := UiArt.drawn(Vector2(54, 24), func(ci: CanvasItem, r: Rect2): UiArt.bone(ci, Vector2(4, r.size.y * .5), Vector2(r.size.x - 6, r.size.y * .5), 5.0, Color(UiArt.IVORY, .85)))
	row.add_child(bone_r)
	return row

## Botao do menu principal: tamanho fixo (consistente), icone proprio a
## esquerda, faixa jade e leve avanço no hover, afunda no clique.
func _stone_button(parent: Node, text: String, icon: StringName, primary: bool, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(392, 68) if primary else Vector2(348, 48)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_override("font", _display_font())
	b.add_theme_font_size_override("font_size", 30 if primary else 18)
	var fill := Color("c98f45") if primary else UiArt.STONE
	var edge := Color("f0c983") if primary else UiArt.STONE_EDGE
	var styles := UiArt.button_styles(fill, edge, 7 if primary else 5, 10, 76 if primary else 62, 8)
	for state in styles:
		b.add_theme_stylebox_override(state, styles[state])
	var ink := Color("2b1906") if primary else CREAM
	b.add_theme_color_override("font_color", ink)
	b.add_theme_color_override("font_hover_color", ink if primary else Color.WHITE)
	b.add_theme_color_override("font_focus_color", ink if primary else Color.WHITE)
	b.add_theme_color_override("font_pressed_color", ink if primary else UiArt.JADE_LIGHT)
	b.set_meta("icon", icon)
	b.draw.connect(func():
		var h := b.size.y
		var lit := b.is_hovered() or b.has_focus()
		var r := Rect2(Vector2(20 if primary else 18, h * .2), Vector2(h * .6, h * .6) * (0.85 if not primary else 1.0))
		if primary:
			r = Rect2(Vector2(22, h * .14), Vector2(h * .48, h * .66))
		var col := (UiArt.JADE_LIGHT if lit else UiArt.JADE) if not primary else UiArt.INK
		UiArt.icon(b, icon, r, col)
		# divisor talhado entre icone e texto
		var dx := (64.0 if primary else 52.0)
		b.draw_line(Vector2(dx, h * .22), Vector2(dx, h * .74), Color(0, 0, 0, .28), 2.0)
		b.draw_line(Vector2(dx + 2, h * .22), Vector2(dx + 2, h * .74), Color(1, 1, 1, .08), 1.0)
		if lit and not primary: # faixa jade a esquerda
			b.draw_rect(Rect2(Vector2(3, 6), Vector2(4, h - 14)), UiArt.JADE))
	b.mouse_entered.connect(func(): _nudge(b, true))
	b.mouse_exited.connect(func(): _nudge(b, false))
	b.focus_entered.connect(b.queue_redraw)
	b.focus_exited.connect(b.queue_redraw)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

## Hover: o botao avanca alguns pixels (via pivo/escala, sem brigar com o container).
func _nudge(b: Control, on: bool) -> void:
	b.pivot_offset = Vector2(0, b.size.y * .5)
	var t := b.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "scale", Vector2.ONE * (1.035 if on else 1.0), .12)
	b.queue_redraw()

func _build_main_menu() -> void:
	# Faixa escura a esquerda (leitura dos botoes) que se dissolve no diorama.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(UiArt.GREEN_DEEP, .86))
	gradient.add_point(0.42, Color(UiArt.GREEN_DEEP, .55))
	gradient.set_color(gradient.get_point_count() - 1, Color(UiArt.GREEN_DEEP, 0))
	var band_tex := GradientTexture2D.new()
	band_tex.gradient = gradient
	band_tex.fill_from = Vector2(0, .5)
	band_tex.fill_to = Vector2(1, .5)
	var band := TextureRect.new()
	band.name = "MenuBand"
	band.texture = band_tex
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	band.anchor_right = 0.62
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(band)
	# Vinheta suave nas bordas.
	var vg := Gradient.new()
	vg.set_color(0, Color(.02, .06, .05, 0))
	vg.set_color(1, Color(.02, .06, .05, .5))
	var vt := GradientTexture2D.new()
	vt.gradient = vg
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(.62, .45)
	vt.fill_to = Vector2(1.25, 1.05)
	var vignette := TextureRect.new()
	vignette.texture = vt
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(vignette)
	# Trilha de pegadas cruzando a faixa (decoracao, bem apagada).
	var trail := UiArt.drawn(Vector2.ZERO, func(ci: CanvasItem, r: Rect2):
		UiArt.footprint_trail(ci, Vector2(r.size.x * .03, r.size.y * .97), Vector2(r.size.x * .4, r.size.y * .62), 9, 30.0, Color(UiArt.IVORY, .07)))
	trail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(trail)

	var column := VBoxContainer.new()
	column.name = "MenuColumn"
	column.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	column.offset_left = 72
	column.offset_right = 72 + 560
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(column)
	var logo := VBoxContainer.new()
	logo.name = "Logo"
	logo.add_theme_constant_override("separation", 2)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(logo)
	logo.add_child(_title_mark(86))
	var sub := _subtitle_plaque("GUARDIÕES DO REFÚGIO", 19)
	var sub_pad := MarginContainer.new()
	sub_pad.add_theme_constant_override("margin_left", 66)
	sub_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_pad.add_child(sub)
	logo.add_child(sub_pad)
	var gap := Control.new()
	gap.custom_minimum_size.y = 38
	column.add_child(gap)
	var buttons := VBoxContainer.new()
	buttons.name = "MenuButtons"
	buttons.add_theme_constant_override("separation", 10)
	column.add_child(buttons)
	var play := _stone_button(buttons, "JOGAR", &"play", true, start_game)
	play.name = "PlayButton"
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	buttons.add_child(spacer)
	# Spec 022: tutorial jogavel (mesmo jogo, instancia isolada).
	_stone_button(buttons, "TUTORIAL", &"tutorial", false, start_tutorial).name = "TutorialButton"
	_stone_button(buttons, "CONTROLES", &"controls", false, func(): show_info(false))
	_stone_button(buttons, "CONFIGURAÇÕES", &"settings", false, func(): show_settings(_close_overlay)).name = "SettingsButton"
	_stone_button(buttons, "CRÉDITOS", &"credits", false, func(): show_info(true))
	_stone_button(buttons, "SAIR", &"quit", false, func(): get_tree().quit())
	# Rodape: estudio (sem textos institucionais na tela principal).
	var foot := HBoxContainer.new()
	foot.name = "MenuFooter"
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	foot.offset_left = 74
	foot.offset_bottom = -22
	foot.add_theme_constant_override("separation", 8)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := TextureRect.new()
	mark.texture = load("res://assets/ui/inity_mark.svg")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.custom_minimum_size = Vector2(18, 18)
	mark.modulate = Color(1, 1, 1, .7)
	foot.add_child(mark)
	foot.add_child(_label("INITY PIXEL  ·  EXPEDIÇÃO PRÉ-HISTÓRICA", 12, Color(CREAM, .5)))
	ui.add_child(foot)
	_build_audio_corner()
	play.grab_focus()
	# Entrada: a marca desce e aparece; os botoes surgem em cascata.
	logo.modulate.a = 0.0
	var intro := logo.create_tween().set_trans(Tween.TRANS_SINE)
	intro.tween_property(logo, "modulate:a", 1.0, .6)
	var i := 0
	for b in buttons.get_children():
		b.modulate.a = 0.0
		var t := b.create_tween()
		t.tween_interval(.25 + .06 * i)
		t.tween_property(b, "modulate:a", 1.0, .25)
		i += 1
	column.offset_top = -14
	column.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(column, "offset_top", 0.0, .7)

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
	var disc := UiArt.button_styles(UiArt.STONE, UiArt.STONE_EDGE, 5, 29, 0, 0)
	for state in ["normal", "hover", "pressed"]:
		icon.add_theme_stylebox_override(state, disc[state])
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
	var elixir := preload("res://scenes/world/jade_elixir.gd").new()
	elixir.name = "JadeElixir"
	world.add_child(elixir)
	_build_hud()
	hud.inventory_panel.visibility_changed.connect(sync_cursor)
	hud.build_menu_panel.visibility_changed.connect(sync_cursor)
	elixir.notice.connect(func(text): _show_toast("ElixirToast", text, JADE))
	sync_cursor()
	audio.change_music("calm")
	audio.set_ambience("day")

func _panel(parent: Node, box: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var style := UiArt.stone_panel(0.93, UiArt.STONE_EDGE, Vector4(20, 12, 20, 12), 8)
	style.shadow_size = 6
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	p.add_child(box)
	return p

func _ignore_mouse(control: Node) -> void:
	if control is Control:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in control.get_children():
		_ignore_mouse(c)

## Icone de cada tela (mesma familia de desenhos do menu).
const MODAL_ICONS := {
	"Controles": &"controls", "Créditos": &"credits", "Configurações": &"settings",
	"Uma pausa no refúgio": &"campfire", "O refúgio caiu": &"refuge", "Tutorial concluído!": &"tutorial",
}

# Visual Overhaul 3.0: todas as telas (pausa, configuracoes, controles,
# creditos, derrota, fim do tutorial) sao a mesma "tabua" de pedra: cabecalho
# com icone e titulo, filete jade com ossos, cristal no topo e cantos de fossil.
func _modal(title: String) -> VBoxContainer:
	_close_overlay()
	overlay = ColorRect.new()
	overlay.color = Color(UiArt.GREEN_DEEP.darkened(.4), .8)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	overlay.modulate.a = 0.0 # transicao discreta de entrada
	overlay.create_tween().tween_property(overlay, "modulate:a", 1.0, 0.15)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var tablet := PanelContainer.new()
	tablet.name = "Tablet"
	tablet.add_theme_stylebox_override("panel", UiArt.stone_panel(0.97, UiArt.STONE_EDGE, Vector4(34, 26, 34, 24), 12))
	center.add_child(tablet)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 540
	box.add_theme_constant_override("separation", 14)
	tablet.add_child(box)
	UiArt.decorate(tablet)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	box.add_child(head)
	if MODAL_ICONS.has(title):
		var icon_color := UiArt.EMBER if title == "O refúgio caiu" else UiArt.JADE
		head.add_child(UiArt.icon_control(MODAL_ICONS[title], 34, icon_color))
	var title_label := _label(title, 30, UiArt.AMBER_LIGHT)
	title_label.add_theme_font_override("font", _display_font())
	title_label.add_theme_color_override("font_outline_color", Color("2a160a"))
	title_label.add_theme_constant_override("outline_size", 6)
	head.add_child(title_label)
	# divisor: filete jade com um osso no meio
	box.add_child(UiArt.drawn(Vector2(0, 14), func(ci: CanvasItem, r: Rect2):
		var y := r.size.y * .5
		ci.draw_line(Vector2(0, y), Vector2(r.size.x * .5 - 34, y), Color(UiArt.JADE, .55), 2.0)
		ci.draw_line(Vector2(r.size.x * .5 + 34, y), Vector2(r.size.x, y), Color(UiArt.JADE, .55), 2.0)
		UiArt.bone(ci, Vector2(r.size.x * .5 - 22, y), Vector2(r.size.x * .5 + 22, y), 4.0, Color(UiArt.IVORY, .7))))
	tablet.modulate.a = 0.0 # entrada curta
	tablet.create_tween().tween_property(tablet, "modulate:a", 1.0, 0.18)
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
	sync_cursor()
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
	sync_cursor()
	audio.set_paused_mix(false)

# RF-AGE-016: a derrota continua encerrando a sessao com tela propria.
func _defeat() -> void:
	_cancel_channel()
	_controls_back = Callable()
	screen = "defeat"
	get_tree().paused = true
	sync_cursor()
	audio.result(false)
	var box := _modal("O refúgio caiu")
	box.add_child(_label("A base perdeu toda a vida.\nPrepare aliados e lute ao lado deles na próxima tentativa.", 20))
	_button(box, "Reiniciar", restart).grab_focus()
	_button(box, "Menu", show_menu)

# Spec 008 (RF-UI-001): vencer a noite nao pausa nem abre modal. O estado ja
# voltou a DIA (DayNightManager); aqui so ha o jingle e um aviso passageiro.
func _victory() -> void:
	audio.result(true)
	audio.set_ambience("day") # 4.0: amanhecer volta ao ambiente de dia (sem nova conexao de sinal)
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
		# 3.0: abas da mochila pelas teclas 1, 2 e 3 (so com ela aberta).
		if inventory_panel.visible and event is InputEventKey and event.pressed \
				and event.physical_keycode in [KEY_1, KEY_2, KEY_3]:
			hud.show_inventory_tab(["resources", "build", "companions"][event.physical_keycode - KEY_1])
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
	sync_cursor()
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

# Gameplay 5.0: politica unica do cursor. Oculto na partida (o golpe segue o
# WASD); visivel em menus, pausa, configuracoes, derrota, mochila e menu de
# construcao. Posicionando uma obra o cursor fica oculto: a pegada colorida da
# previa e o marcador. cursor_hidden guarda a decisao (o modo sem janela do
# Godot ignora MOUSE_MODE_HIDDEN, entao os testes leem este campo).
var cursor_hidden := false

func sync_cursor() -> void:
	var interactive := screen != "playing" or is_instance_valid(overlay)
	var live_hud := is_instance_valid(hud) and not hud.is_queued_for_deletion()
	if live_hud:
		interactive = interactive or (is_instance_valid(hud.inventory_panel) and hud.inventory_panel.visible) or (is_instance_valid(hud.build_menu_panel) and hud.build_menu_panel.visible)
	cursor_hidden = not interactive
	if live_hud:
		hud.set_pointer_capture(interactive)
	var mode := Input.MOUSE_MODE_HIDDEN if cursor_hidden else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode: Input.mouse_mode = mode
	if is_instance_valid(world) and not world.is_queued_for_deletion():
		var player = world.get_node("Player")
		player.ui_blocked = interactive
		if interactive: player._attack_queued = false

func _process(_delta: float) -> void:
	sync_cursor()