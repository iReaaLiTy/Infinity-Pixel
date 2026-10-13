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

## Botao das telas (pausa, configuracoes, derrota...). `primary` = a acao
## principal da tela em placa ambar (Design 5.0: hierarquia clara).
func _button(parent: Node, text: String, action: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 50 if primary else 46
	b.add_theme_font_override("font", _display_font())
	b.add_theme_font_size_override("font_size", 20 if primary else 18)
	if primary:
		var styles := UiArt.button_styles(Color("c98f45"), Color("f0c983"), 6, 10, 22, 8)
		for state in styles:
			b.add_theme_stylebox_override(state, styles[state])
		for key in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			b.add_theme_color_override(key, Color("2b1906"))
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

## Design 5.0 — logotipo: JADEFALL em relevo (extrusao, contorno, bisel claro
## em cima e sombra embaixo) sobre um LINTEL de pedra talhada com musgo,
## rachaduras e filete jade; um medalhao com o cristal do Refugio e dois ossos
## fosseis cruzados sela a ponta esquerda. Tudo desenhado (nitido em qualquer
## escala); fonte embutida Lilita One (OFL).
func _title_mark(size: int) -> Control:
	var c := Control.new()
	c.name = "TitleMark"
	c.set_meta("text", "JADEFALL")
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := _display_font()
	var text_size := font.get_string_size("JADEFALL", HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var medal := size * 1.22
	var pad := size * 0.46
	c.custom_minimum_size = Vector2(medal * 0.62 + pad * 2.0 + text_size.x + size * 0.2, size * 1.62)
	c.draw.connect(func():
		var ci := c.get_canvas_item()
		var w := c.size.x
		var h := c.size.y
		# lintel: placa trapezoidal chanfrada, um pouco mais larga em cima
		var slab_l := medal * 0.36
		var top := h * 0.2
		var bottom := h * 0.94
		var ch := size * 0.14
		var slab := PackedVector2Array([Vector2(slab_l + ch, top), Vector2(w - ch, top), Vector2(w, top + ch), Vector2(w - size * 0.08, bottom - ch),
			Vector2(w - size * 0.08 - ch, bottom), Vector2(slab_l + size * 0.08 + ch, bottom), Vector2(slab_l + size * 0.08, bottom - ch), Vector2(slab_l, top + ch)])
		c.draw_colored_polygon(_offset_poly(slab, Vector2(0, 8)), Color(0, 0, 0, 0.35))
		var cols := PackedColorArray()
		for p in slab:
			cols.append(Color("4a5a50").lerp(Color("26342e"), clampf((p.y - top) / (bottom - top), 0.0, 1.0)))
		c.draw_polygon(slab, cols)
		# veios/rachaduras e marcas de cinzel na pedra
		var crack := Color(0.05, 0.08, 0.07, 0.55)
		c.draw_polyline(PackedVector2Array([Vector2(w * 0.55, top + 2), Vector2(w * 0.565, top + (bottom - top) * 0.3), Vector2(w * 0.545, top + (bottom - top) * 0.55)]), crack, 2.0)
		c.draw_polyline(PackedVector2Array([Vector2(w * 0.9, bottom - 2), Vector2(w * 0.885, bottom - (bottom - top) * 0.35), Vector2(w * 0.905, bottom - (bottom - top) * 0.5)]), crack, 2.0)
		# filete jade e bisel do topo
		c.draw_line(Vector2(slab_l + size * 0.2, bottom - size * 0.14), Vector2(w - size * 0.26, bottom - size * 0.14), Color(UiArt.JADE, 0.5), 2.0)
		c.draw_line(Vector2(slab_l + ch, top + 1.5), Vector2(w - ch, top + 1.5), Color(1, 1, 1, 0.18), 2.0)
		c.draw_polyline(slab + PackedVector2Array([slab[0]]), Color("1a2420"), 2.5, true)
		# musgo pendendo da borda de cima (pequenos tufos)
		for i in 9:
			var x := slab_l + ch + (w - slab_l - 2.0 * ch) * (0.04 + 0.11 * i + 0.02 * sin(i * 3.1))
			var mw := size * (0.1 + 0.05 * fposmod(i * 0.37, 1.0))
			var mh := size * (0.05 + 0.06 * fposmod(i * 0.61, 1.0))
			c.draw_colored_polygon(PackedVector2Array([Vector2(x - mw, top - 1), Vector2(x + mw, top - 1), Vector2(x + mw * 0.4, top + mh), Vector2(x - mw * 0.3, top + mh * 0.7)]),
				Color("4f7f45") if i % 2 == 0 else Color("5f9150"))
		# letras em relevo
		var x0 := medal * 0.62 + pad
		var base := top + (bottom - top) * 0.5 + size * 0.36
		for k in range(8, 0, -1):
			font.draw_string(ci, Vector2(x0, base + k), "JADEFALL", HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("1d1006").lerp(Color("5a3414"), 1.0 - k / 8.0))
		font.draw_string_outline(ci, Vector2(x0, base), "JADEFALL", HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(6, size / 10), Color("1d1006"))
		font.draw_string(ci, Vector2(x0, base - 2.5), "JADEFALL", HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("fff1cf"))
		font.draw_string(ci, Vector2(x0, base + 3.0), "JADEFALL", HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("b8742a"))
		font.draw_string(ci, Vector2(x0, base), "JADEFALL", HORIZONTAL_ALIGNMENT_LEFT, -1, size, UiArt.AMBER_LIGHT)
		# medalhao: ossos cruzados atras, anel de pedra, fundo escuro e o cristal
		var mc := Vector2(medal * 0.46, h * 0.54)
		var mr := medal * 0.42
		UiArt.bone(c, mc + Vector2(-mr * 1.05, -mr * 0.9), mc + Vector2(mr * 1.05, mr * 0.9), size * 0.07, UiArt.IVORY.darkened(0.08))
		UiArt.bone(c, mc + Vector2(-mr * 1.05, mr * 0.9), mc + Vector2(mr * 1.05, -mr * 0.9), size * 0.07, UiArt.IVORY)
		c.draw_circle(mc + Vector2(0, 6), mr + 4, Color(0, 0, 0, 0.35))
		_ring_poly(c, mc, mr + 3, 10, Color("1a2420"))
		_ring_poly(c, mc, mr, 10, Color("5d6d63"))
		_ring_poly(c, mc, mr * 0.8, 10, Color("13261f"))
		for i in 10:
			var a := TAU * i / 10.0
			c.draw_circle(mc + Vector2(cos(a), sin(a)) * mr * 0.9, size * 0.025, Color(UiArt.JADE, 0.75))
		UiArt.crystal(c, Rect2(mc - Vector2(mr * 0.42, mr * 0.68), Vector2(mr * 0.84, mr * 1.36)), 1.0))
	return c

func _offset_poly(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + d)
	return out

func _ring_poly(ci: CanvasItem, center: Vector2, r: float, sides: int, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in sides:
		var a := TAU * i / sides - PI / 2.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, col)

## Cristal facetado do Refugio (icone da HUD e das telas).
func _crystal(size: float) -> Control:
	return UiArt.drawn(Vector2(size * .62, size), func(ci: CanvasItem, r: Rect2): UiArt.crystal(ci, r))

## Design 5.0 — faixa de tecido jade com pontas recortadas e borda ambar; o
## subtitulo (Label "Subtitle") vai por cima, com espacamento largo.
func _subtitle_plaque(text: String, size: int) -> Control:
	var ribbon := PanelContainer.new()
	ribbon.name = "SubtitleRibbon"
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = size * 2.2
	empty.content_margin_right = size * 2.2
	empty.content_margin_top = size * 0.35
	empty.content_margin_bottom = size * 0.45
	ribbon.add_theme_stylebox_override("panel", empty)
	ribbon.draw.connect(func():
		var s := ribbon.size
		var n := s.y * 0.5
		var cut := s.y * 0.55
		var band := PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x - cut, n), Vector2(s.x, s.y), Vector2(0, s.y), Vector2(cut, n)])
		ribbon.draw_colored_polygon(_offset_poly(band, Vector2(0, 4)), Color(0, 0, 0, 0.35))
		ribbon.draw_colored_polygon(band, Color("1d4a3d"))
		ribbon.draw_colored_polygon(PackedVector2Array([Vector2(cut * 1.4, 2), Vector2(s.x - cut * 1.4, 2), Vector2(s.x - cut * 1.4, n), Vector2(cut * 1.4, n)]), Color(1, 1, 1, 0.05))
		ribbon.draw_polyline(band + PackedVector2Array([band[0]]), UiArt.AMBER, 2.0, true)
		ribbon.draw_line(Vector2(cut * 1.3, s.y - 5), Vector2(s.x - cut * 1.3, s.y - 5), Color(UiArt.AMBER, 0.35), 1.0)
		for x in [cut * 1.45, s.x - cut * 1.45]:
			UiArt.crystal(ribbon, Rect2(Vector2(x - s.y * 0.14, s.y * 0.22), Vector2(s.y * 0.28, s.y * 0.56))))
	var label := _label(text, size, UiArt.IVORY)
	label.name = "Subtitle"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spaced := FontVariation.new()
	spaced.base_font = _display_font()
	spaced.spacing_glyph = 5
	label.add_theme_font_override("font", spaced)
	label.add_theme_color_override("font_outline_color", Color("0e231c"))
	label.add_theme_constant_override("outline_size", 4)
	ribbon.add_child(label)
	return ribbon

## Botao do menu principal em tres niveis de hierarquia: 0 = JOGAR (placa ambar
## grande), 1 = TUTORIAL (placa jade media), 2 = demais opcoes (pedra, mesmo
## tamanho). Icone proprio a esquerda, divisor talhado, brilho jade no hover,
## avanço curto, afunda no clique e contorno ambar no foco de teclado.
const MENU_TIERS := [
	{"size": Vector2(410, 74), "font": 32, "fill": Color("c98f45"), "edge": Color("f0c983"), "depth": 7, "ink": Color("2b1906"), "pad": 84},
	{"size": Vector2(360, 56), "font": 23, "fill": Color("1f5a49"), "edge": Color("69c7a0"), "depth": 6, "ink": Color("f2e8ce"), "pad": 70},
	{"size": Vector2(320, 46), "font": 18, "fill": Color("1f332c"), "edge": Color("4e7a66"), "depth": 5, "ink": Color("f2e8ce"), "pad": 62},
]

func _stone_button(parent: Node, text: String, icon: StringName, tier: int, action: Callable) -> Button:
	var spec: Dictionary = MENU_TIERS[tier]
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = spec.size
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_override("font", _display_font())
	b.add_theme_font_size_override("font_size", spec.font)
	var styles := UiArt.button_styles(spec.fill, spec.edge, spec.depth, 12 if tier == 0 else 10, spec.pad, 8)
	if tier == 0:
		for st in styles.values():
			st.studs = true
			st.stud_color = Color("fff1cf")
	for state in styles:
		b.add_theme_stylebox_override(state, styles[state])
	var ink: Color = spec.ink
	b.add_theme_color_override("font_color", ink)
	b.add_theme_color_override("font_hover_color", ink if tier == 0 else Color.WHITE)
	b.add_theme_color_override("font_focus_color", ink if tier == 0 else Color.WHITE)
	b.add_theme_color_override("font_pressed_color", ink if tier == 0 else UiArt.JADE_LIGHT)
	if tier > 0:
		b.add_theme_color_override("font_outline_color", Color("0b1a15"))
		b.add_theme_constant_override("outline_size", 3)
	b.set_meta("icon", icon)
	b.set_meta("tier", tier)
	b.draw.connect(func():
		var h := b.size.y
		var lit := b.is_hovered() or b.has_focus()
		var face := h - float(spec.depth)
		var pad := float(spec.pad)
		var r := Rect2(Vector2(pad * 0.3, face * 0.2), Vector2(face * 0.6, face * 0.6))
		var col := UiArt.INK if tier == 0 else (UiArt.JADE_LIGHT if lit else UiArt.JADE)
		if tier == 0:
			r = Rect2(Vector2(pad * 0.27, face * 0.13), Vector2(face * 0.5, face * 0.72))
		UiArt.icon(b, icon, r, col)
		var dx := pad - 14.0
		b.draw_line(Vector2(dx, face * 0.22), Vector2(dx, face * 0.78), Color(0, 0, 0, .3), 2.0)
		b.draw_line(Vector2(dx + 2, face * 0.22), Vector2(dx + 2, face * 0.78), Color(1, 1, 1, .1), 1.0)
		if lit and tier > 0: # seta jade a direita (o botao "aponta" a acao)
			var ax := b.size.x - 26.0
			var ay := face * 0.5
			b.draw_colored_polygon(PackedVector2Array([Vector2(ax, ay - 6), Vector2(ax + 9, ay), Vector2(ax, ay + 6)]), UiArt.JADE_LIGHT))
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

## Escala da coluna do menu pela altura da janela (cabe de 960x540 a 4K).
func _menu_scale() -> float:
	return clampf(get_viewport().get_visible_rect().size.y / 780.0, 0.62, 1.25)

# ---------------------------------------------------------------------------
# Design 5.0 — composicao do menu principal: o diorama 3D ocupa a tela toda
# (o Refugio, as torres novas e um aliado ficam no terco direito); faixas de
# cinema escurecem o alto e o rodape; a esquerda, o logotipo no lintel e a
# ESTELA de pedra com a hierarquia JOGAR > TUTORIAL > opcoes > sair.
# ---------------------------------------------------------------------------
func _build_main_menu() -> void:
	# Faixa escura a esquerda (leitura) que se dissolve no diorama.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(UiArt.GREEN_DEEP, .78))
	gradient.add_point(0.38, Color(UiArt.GREEN_DEEP, .42))
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
	band.anchor_right = 0.55
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(band)
	# Faixas de cinema (alto e rodape) e vinheta suave.
	for top in [true, false]:
		var g := Gradient.new()
		g.set_color(0, Color(0.02, 0.05, 0.04, 0.62 if top else 0.7))
		g.set_color(1, Color(0.02, 0.05, 0.04, 0.0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(.5, 0 if top else 1)
		gt.fill_to = Vector2(.5, 1 if top else 0)
		var bar := TextureRect.new()
		bar.texture = gt
		bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bar.stretch_mode = TextureRect.STRETCH_SCALE
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top:
			bar.anchor_bottom = 0.2
		else:
			bar.anchor_top = 0.74
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(bar)
	var vg := Gradient.new()
	vg.set_color(0, Color(.02, .06, .05, 0))
	vg.set_color(1, Color(.02, .06, .05, .45))
	var vt := GradientTexture2D.new()
	vt.gradient = vg
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(.64, .46)
	vt.fill_to = Vector2(1.3, 1.1)
	var vignette := TextureRect.new()
	vignette.texture = vt
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(vignette)

	# Coluna: logotipo + estela. Escala pela altura da janela (pivo no canto).
	var column := VBoxContainer.new()
	column.name = "MenuColumn"
	column.position = Vector2(64, 0)
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(column)
	var logo := VBoxContainer.new()
	logo.name = "Logo"
	logo.add_theme_constant_override("separation", -6)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(logo)
	logo.add_child(_title_mark(84))
	var sub := _subtitle_plaque("GUARDIÕES DO REFÚGIO", 19)
	sub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo.add_child(sub)
	# Estela: placa alta de pedra com cravos e filete jade, botoes dentro.
	var stele := PanelContainer.new()
	stele.name = "MenuStele"
	stele.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var stele_style := UiArt.stone_panel(0.88, UiArt.STONE_EDGE, Vector4(26, 26, 30, 24), 14)
	stele.add_theme_stylebox_override("panel", stele_style)
	stele.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(stele)
	var buttons := VBoxContainer.new()
	buttons.name = "MenuButtons"
	buttons.add_theme_constant_override("separation", 10)
	stele.add_child(buttons)
	var play := _stone_button(buttons, "JOGAR", &"play", 0, start_game)
	play.name = "PlayButton"
	# Spec 022: tutorial jogavel (mesmo jogo, instancia isolada).
	_stone_button(buttons, "TUTORIAL", &"tutorial", 1, start_tutorial).name = "TutorialButton"
	buttons.add_child(UiArt.drawn(Vector2(0, 16), func(ci: CanvasItem, r: Rect2):
		var y := r.size.y * .5
		ci.draw_line(Vector2(6, y), Vector2(r.size.x * .5 - 30, y), Color(UiArt.JADE, .4), 2.0)
		ci.draw_line(Vector2(r.size.x * .5 + 30, y), Vector2(r.size.x - 6, y), Color(UiArt.JADE, .4), 2.0)
		UiArt.bone(ci, Vector2(r.size.x * .5 - 18, y), Vector2(r.size.x * .5 + 18, y), 3.5, Color(UiArt.IVORY, .6))))
	_stone_button(buttons, "CONTROLES", &"controls", 2, func(): show_info(false))
	_stone_button(buttons, "CONFIGURAÇÕES", &"settings", 2, func(): show_settings(_close_overlay)).name = "SettingsButton"
	_stone_button(buttons, "CRÉDITOS", &"credits", 2, func(): show_info(true))
	_stone_button(buttons, "SAIR", &"quit", 2, func(): get_tree().quit())
	# Rodape: estudio (sem textos institucionais na tela principal).
	var foot := HBoxContainer.new()
	foot.name = "MenuFooter"
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	foot.offset_left = 66
	foot.offset_bottom = -20
	foot.add_theme_constant_override("separation", 8)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := TextureRect.new()
	mark.texture = load("res://assets/ui/inity_mark.svg")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.custom_minimum_size = Vector2(18, 18)
	mark.modulate = Color(1, 1, 1, .7)
	foot.add_child(mark)
	foot.add_child(_label("INITY PIXEL  ·  EXPEDIÇÃO PRÉ-HISTÓRICA", 12, Color(CREAM, .55)))
	ui.add_child(foot)
	_build_audio_corner()
	play.grab_focus()
	# Layout responsivo: escala e centraliza a coluna na altura da janela.
	var layout := func():
		if not is_instance_valid(column):
			return
		var s := _menu_scale()
		column.scale = Vector2(s, s)
		column.reset_size()
		var view := get_viewport().get_visible_rect().size
		column.position = Vector2(64.0 * s, maxf(12.0, (view.y - column.size.y * s) * 0.5 - 10.0 * s))
	layout.call_deferred()
	get_viewport().size_changed.connect(layout)
	column.tree_exiting.connect(func():
		if get_viewport().size_changed.is_connected(layout):
			get_viewport().size_changed.disconnect(layout))
	# Entrada: o logotipo aparece, a estela desliza da esquerda, botoes em cascata.
	logo.modulate.a = 0.0
	logo.create_tween().set_trans(Tween.TRANS_SINE).tween_property(logo, "modulate:a", 1.0, .6)
	stele.modulate.a = 0.0
	var st := stele.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	st.tween_interval(.15)
	st.tween_property(stele, "modulate:a", 1.0, .35)
	var i := 0
	for b in buttons.get_children():
		b.modulate.a = 0.0
		var t := b.create_tween()
		t.tween_interval(.3 + .05 * i)
		t.tween_property(b, "modulate:a", 1.0, .22)
		i += 1

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
	var tablet_style := UiArt.stone_panel(0.97, UiArt.STONE_EDGE, Vector4(34, 26, 34, 24), 12)
	tablet_style.studs = false # os ossos de UiArt.decorate ja ornam os cantos
	tablet.add_theme_stylebox_override("panel", tablet_style)
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
	_button(box, "Retomar", resume_game, true).grab_focus()
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
	_button(box, "Reiniciar", restart, true).grab_focus()
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
	_button(box, "Jogar partida", start_game, true).grab_focus()
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