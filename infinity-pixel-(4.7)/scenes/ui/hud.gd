extends Control

# HUD da partida (extraida de main.gd sem mudar comportamento). So exibe e
# encaminha: as regras vivem no mundo (DefenseEconomy, ResourceStock,
# BuildPlacer, TerritoryManager, DayNightManager, Player). main.gd cria uma
# HUD nova a cada partida e expoe os mesmos campos de antes (testes e menus).
# Ajudantes visuais compartilhados com os menus (_label, _panel, fontes,
# botoes) continuam em main.gd e sao usados por `app`.

const CREAM := Color("f2e8ce")
const GOLD := Color("e7ae58")
const JADE := Color("69be9b")
const EMBER := Color("e0795a") # Spec 011: barra do jogador e tinta de dano
const DAWN_TOAST_TIME := 2.5 # Spec 008 (RF-UI-001): avisos passageiros, em segundos

var app: Node # main.gd
var world: Node3D
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
var _cycle_icon: Control # sol / lua ao lado do relogio
var _cycle_bar: ProgressBar
var _cycle_fill: StyleBox
var _cycle_night := false
var _focus_ring: MeshInstance3D # destaque do coletavel ao alcance
var objective_override := "" # Spec 022: passo do tutorial (vazio = objetivo normal)
var _range_hint_left := 0.0 # aviso "fora de alcance" apos um clique longe do alvo
var _hint_row: HBoxContainer # 3.0: [tecla] + dica
var _hint_key: Control
const NIGHT_VIOLET := Color("9aa6f0")
const CombatFX := preload("res://scenes/visuals/combat_fx.gd")
const UiArt := preload("res://scenes/ui/ui_art.gd")
const FossilUI := preload("res://scenes/ui/fossil_ui.gd") # World 6.0

func build(main: Node, game_world: Node3D) -> void:
	app = main
	world = game_world
	name = "Hud"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Design 5.0 — VITAIS: medalhao do explorador (brasa) e do Refugio (jade),
	# cada um com a barra talhada (marcas a cada 10% e "rastro" do dano
	# recente). Os textos continuam os mesmos ("JOGADOR  100 / 100").
	var health = VBoxContainer.new()
	health.add_theme_constant_override("separation", 6)
	var prow := _vital_row(health, &"player", EMBER)
	_player_medal = prow[0]
	player_text = prow[1]
	player_text.text = "JOGADOR  100 / 100"
	player_bar = prow[2]
	var brow := _vital_row(health, &"refuge", JADE)
	_refuge_medal = brow[0]
	base_text = brow[1]
	base_text.text = "REFÚGIO  100 / 100"
	base_bar = brow[2]
	var left = _hud_panel(self, health)
	left.name = "HealthPanel"
	left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	left.position = Vector2(16, 14)
	# CICLO: arco do periodo (sol ou lua percorrendo o ceu), "DIA 1 • 08:58" e
	# "PREPARACAO · Noites: 0" (+ onda e contagem final). So leitura do
	# DayNightManager: horarios e duracoes nao mudam.
	var phase = VBoxContainer.new()
	phase.add_theme_constant_override("separation", 0)
	_cycle_dial = Control.new()
	_cycle_dial.name = "CycleDial"
	_cycle_dial.custom_minimum_size = Vector2(236, 26)
	_cycle_dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cycle_dial.draw.connect(_draw_cycle_dial)
	phase.add_child(_cycle_dial)
	var phase_row = HBoxContainer.new()
	phase_row.alignment = BoxContainer.ALIGNMENT_CENTER
	phase_row.add_theme_constant_override("separation", 8)
	phase.add_child(phase_row)
	_cycle_icon = _hud_icon(&"cycle", 18)
	_cycle_icon.visible = false # 5.0: o sol/lua agora anda no arco acima
	phase_row.add_child(_cycle_icon)
	phase_text = app._label("DIA 1", 19, GOLD)
	phase_text.add_theme_font_override("font", app._display_font())
	phase_text.add_theme_color_override("font_outline_color", Color("1d1006"))
	phase_text.add_theme_constant_override("outline_size", 4)
	phase_row.add_child(phase_text)
	phase_row.add_child(app._label("•", 15, GOLD))
	clock_text = app._label("08:00", 19, CREAM)
	clock_text.add_theme_font_override("font", app._display_font())
	clock_text.add_theme_color_override("font_outline_color", Color("0b1a15"))
	clock_text.add_theme_constant_override("outline_size", 4)
	phase_row.add_child(clock_text)
	wave_text = app._label("PREPARAÇÃO  ·  Noites: 0", 12, Color(CREAM, .85))
	wave_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase.add_child(wave_text)
	onda_text = app._label("", 12, Color("f0c9a0"))
	onda_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	onda_text.hide()
	phase.add_child(onda_text)
	countdown_text = app._label("", 15, EMBER)
	countdown_text.add_theme_font_override("font", app._display_font())
	countdown_text.add_theme_color_override("font_outline_color", Color("1d1006"))
	countdown_text.add_theme_constant_override("outline_size", 4)
	countdown_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_text.hide()
	phase.add_child(countdown_text)
	# Barra antiga do periodo: continua existindo (o arco le o mesmo valor),
	# escondida.
	_cycle_bar = _hud_bar(phase, GOLD)
	_cycle_bar.custom_minimum_size = Vector2(190, 4)
	_cycle_bar.max_value = 1.0
	_cycle_bar.visible = false
	_cycle_fill = _cycle_bar.get_theme_stylebox("fill")
	var center = _hud_panel(self, phase)
	center.name = "PhasePanel"
	center.get_theme_stylebox("panel").content_margin_top = 4
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.offset_top = 14
	center.offset_bottom = 14
	# RECURSOS: fichas proprias com hierarquia (Defesa em destaque; Madeira e
	# Pedra; Territorios e Elixir menores).
	_build_points_panel(self)
	# CONTEXTO (embaixo, centro): objetivo curto + dica com a TECLA desenhada +
	# barra de canalizacao. Compacto; a linha da dica e a barra so aparecem
	# quando ha o que mostrar.
	var bottom = VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 3)
	var panel = _hud_panel(self, bottom)
	panel.name = "ContextPanel"
	panel.get_theme_stylebox("panel").content_margin_top = 5
	panel.get_theme_stylebox("panel").content_margin_bottom = 6
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_top = -14
	panel.offset_bottom = -14
	var obj_row := HBoxContainer.new()
	obj_row.alignment = BoxContainer.ALIGNMENT_CENTER
	obj_row.add_theme_constant_override("separation", 8)
	bottom.add_child(obj_row)
	obj_row.add_child(UiArt.icon_control(&"defense", 14))
	objective = app._label("", 14, UiArt.AMBER_LIGHT)
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	obj_row.add_child(objective)
	_hint_row = HBoxContainer.new()
	_hint_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hint_row.add_theme_constant_override("separation", 8)
	bottom.add_child(_hint_row)
	_hint_key = UiArt.keycap("E", app._display_font(), 13)
	_hint_row.add_child(_hint_key)
	hint = app._label("", 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_row.add_child(hint)
	channel_bar = ProgressBar.new()
	channel_bar.max_value = 1.0
	channel_bar.show_percentage = false
	channel_bar.custom_minimum_size = Vector2(320, 8)
	bottom.add_child(channel_bar)
	_build_defense_panel()
	app._ignore_mouse(self)
	# Spec 007 (RF-CAM-004): com o cursor visivel, clicar sobre os paineis da HUD
	# e clicar na interface — o painel consome o clique e o Player nao ataca.
	for p in self.find_children("*", "PanelContainer", true, false):
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		_gameplay_click_targets.append(p)
	build_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_gameplay_click_targets.append(build_button)
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
	player.attack_out_of_range.connect(func(_t): _range_hint_left = 1.2)
	_on_player_health(player.current_hp, player.max_hp)
	# Spec 017B/020: alerta curto quando a noite comeca (a onda esta a caminho).
	DayNightManager.night_started.connect(_on_night_started)

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
var _resource_items = {} # kind -> Control (posicao do "+N")

var _player_medal: Control
var _refuge_medal: Control
var _cycle_dial: Control
var _elixir_chip: Control
var _elixir_chip_text: Label
var _last_base_health := -1.0

# Painel compacto da HUD. Design 5.0: a mesma "pedra talhada" do menu e das
# telas (chanfro, bisel, filete jade), mais leve e sem cravos; a cor da borda
# vira alerta (vida baixa, noite) em _update_alerts.
func _hud_panel(parent: Node, box: Control) -> PanelContainer:
	var p = PanelContainer.new()
	var style := UiArt.stone_panel(0.84, Color("3d6a57"), Vector4(12, 8, 12, 9), 8)
	style.studs = false
	style.shadow_size = 6.0
	style.shadow_offset = Vector2(0, 3)
	style.shadow_color = Color(0, 0, 0, .28)
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	p.add_child(box)
	return p

## Barra talhada: trilho escuro chanfrado, preenchimento em degrade com bisel,
## marcas a cada 10% e o "rastro" claro do dano recente (some em ~0,6 s).
func _hud_bar(parent: Node, color: Color) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.custom_minimum_size.y = 10
	bar.show_percentage = false
	var fill := UiArt.carved(color, Color(0, 0, 0, 0), Vector4.ZERO, 3.0)
	fill.bg_top = color.lightened(0.32)
	fill.inner_color = Color(0, 0, 0, 0)
	fill.shadow_size = 0.0
	fill.border_width = 0.0
	fill.chisel = false
	var back := UiArt.carved(Color("0c1c18"), Color("2c4a40"), Vector4.ZERO, 3.0)
	back.bg_top = Color("07120f")
	back.inner_color = Color(0, 0, 0, 0)
	back.shadow_size = 0.0
	back.border_width = 1.5
	back.chisel = false
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	bar.draw.connect(func(): _draw_bar_overlay(bar))
	parent.add_child(bar)
	return bar

func _draw_bar_overlay(bar: ProgressBar) -> void:
	var s := bar.size
	if s.x < 40.0:
		return
	var frac := clampf(bar.value / maxf(bar.max_value, 0.001), 0.0, 1.0)
	var ghost: float = bar.get_meta("ghost", frac)
	if ghost > frac + 0.002:
		bar.draw_rect(Rect2(s.x * frac, 1.5, s.x * (ghost - frac), s.y - 3.0), Color(1.0, 0.93, 0.8, 0.6))
	if s.y >= 8.0: # marcas a cada 10% numa so chamada (a do meio mais forte)
		var ticks := PackedVector2Array()
		var cols := PackedColorArray()
		for i in range(1, 10):
			var x := s.x * i / 10.0
			ticks.append_array([Vector2(x, 2.5), Vector2(x, s.y - 2.5)])
			cols.append(Color(0, 0, 0, 0.42 if i == 5 else 0.24))
		bar.draw_multiline_colors(ticks, cols, 1.0)

## Rastro do dano: fica parado ~0,35 s e depois desce ate o valor atual.
func _tick_ghost(bar: ProgressBar, delta: float) -> void:
	var frac := clampf(bar.value / maxf(bar.max_value, 0.001), 0.0, 1.0)
	var ghost: float = bar.get_meta("ghost", frac)
	if frac >= ghost:
		if ghost != frac:
			bar.set_meta("ghost", frac)
			bar.queue_redraw()
		return
	var hold: float = bar.get_meta("ghost_hold", 0.0) - delta
	bar.set_meta("ghost_hold", hold)
	if hold <= 0.0:
		bar.set_meta("ghost", move_toward(ghost, frac, delta * 0.9))
	bar.queue_redraw()

func _hurt_bar(bar: ProgressBar, previous_frac: float) -> void:
	bar.set_meta("ghost", maxf(bar.get_meta("ghost", previous_frac), previous_frac))
	bar.set_meta("ghost_hold", 0.35)

## Linha dos vitais: medalhao + nome/valor + barra.
func _vital_row(parent: Node, kind: StringName, color: Color) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	var medal := Control.new()
	medal.name = "Medal_" + String(kind)
	medal.custom_minimum_size = Vector2(40, 40)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	medal.set_meta("flash", 0.0)
	medal.set_meta("critical", false)
	medal.draw.connect(func(): _draw_medal(medal, kind, color))
	row.add_child(medal)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var label: Label = app._label("", 14, CREAM)
	label.add_theme_font_override("font", app._display_font())
	label.add_theme_color_override("font_outline_color", Color("0b1a15"))
	label.add_theme_constant_override("outline_size", 3)
	col.add_child(label)
	var bar := _hud_bar(col, color)
	bar.custom_minimum_size = Vector2(198, 11)
	row.add_child(col)
	parent.add_child(row)
	return [medal, label, bar]

## Medalhao de pedra (anel octogonal) com o icone: explorador ou cristal do
## Refugio. Pisca ao levar dano; em estado critico, o anel pulsa em brasa.
func _draw_medal(c: Control, kind: StringName, color: Color) -> void:
	var s := c.size
	var ctr := s * 0.5
	var r := minf(s.x, s.y) * 0.5
	var flash: float = c.get_meta("flash", 0.0)
	var critical: bool = c.get_meta("critical", false)
	var oct := func(rad: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 8:
			var a := TAU * i / 8.0 + PI / 8.0
			pts.append(ctr + Vector2(cos(a), sin(a)) * rad)
		return pts
	c.draw_colored_polygon(oct.call(r), Color("0a1512"))
	c.draw_colored_polygon(oct.call(r - 2.0), Color("55645b"))
	var ring := color
	if critical:
		ring = UiArt.EMBER.lerp(Color.WHITE, 0.25 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)))
	c.draw_colored_polygon(oct.call(r - 4.5), ring.darkened(0.15))
	c.draw_colored_polygon(oct.call(r - 7.0), Color("10261f"))
	c.draw_line(ctr + Vector2(-r * 0.55, -r * 0.74), ctr + Vector2(r * 0.55, -r * 0.74), Color(1, 1, 1, 0.16), 1.5)
	if kind == &"refuge":
		UiArt.crystal(c, Rect2(ctr - Vector2(r * 0.34, r * 0.6), Vector2(r * 0.68, r * 1.2)), 0.6)
	else:
		UiArt.icon(c, &"player", Rect2(ctr - Vector2(r * 0.5, r * 0.52), Vector2(r * 1.0, r * 1.04)), color.lightened(0.25))
	if flash > 0.0:
		c.draw_colored_polygon(oct.call(r - 1.0), Color(1.0, 0.9, 0.85, 0.45 * flash))

func _flash_medal(medal: Control) -> void:
	if not is_instance_valid(medal):
		return
	medal.set_meta("flash", 1.0)
	medal.queue_redraw()

## Arco do periodo: o sol (dia) ou a lua (noite) percorre o arco conforme a
## fracao ja passada (a mesma leitura da barra antiga). Ambar de dia, violeta
## a noite; estrelas pequenas a noite.
func _draw_cycle_dial() -> void:
	var c := _cycle_dial
	var s := c.size
	var night: bool = DayNightManager.is_night()
	var t: float = _cycle_bar.value if is_instance_valid(_cycle_bar) else 0.0
	var tone := NIGHT_VIOLET if night else GOLD
	var base := Vector2(s.x * 0.5, s.y - 1.0)
	var rx := s.x * 0.44
	var ry := s.y - 5.0
	var arc := PackedVector2Array()
	var lit := PackedVector2Array()
	for i in 33:
		var k := i / 32.0
		var a := PI + PI * k
		var p := base + Vector2(cos(a) * rx, sin(a) * ry)
		arc.append(p)
		if k <= t:
			lit.append(p)
	c.draw_line(Vector2(base.x - rx - 10, base.y), Vector2(base.x + rx + 10, base.y), Color(tone, 0.25), 1.0)
	c.draw_polyline(arc, Color(0, 0, 0, 0.45), 4.0, true)
	c.draw_polyline(arc, Color(tone, 0.22), 2.0, true)
	if lit.size() >= 2:
		c.draw_polyline(lit, tone, 2.5, true)
	if night:
		for q in [Vector2(0.2, 0.35), Vector2(0.36, 0.12), Vector2(0.64, 0.18), Vector2(0.8, 0.4)]:
			c.draw_circle(Vector2(s.x * q.x, s.y * q.y), 1.2, Color(1, 1, 1, 0.55))
	var a := PI + PI * t
	var m := base + Vector2(cos(a) * rx, sin(a) * ry)
	c.draw_circle(m, 9.0, Color(tone, 0.18))
	if night:
		c.draw_circle(m, 6.0, NIGHT_VIOLET)
		c.draw_circle(m + Vector2(2.6, -1.8), 5.0, Color("10221d"))
	else:
		for i in 8:
			var ra := TAU * i / 8.0
			c.draw_line(m + Vector2(cos(ra), sin(ra)) * 6.5, m + Vector2(cos(ra), sin(ra)) * 9.5, GOLD, 1.5)
		c.draw_circle(m, 5.0, GOLD)
		c.draw_circle(m + Vector2(-1.4, -1.4), 2.0, Color(1, 0.95, 0.8, 0.8))

## Icones vetoriais da HUD: jogador, cristal do Refugio, sol/lua do ciclo.
func _hud_icon(kind: StringName, size: float) -> Control:
	if kind == &"refuge":
		return app._crystal(size)
	var c = Control.new()
	c.custom_minimum_size = Vector2(size, size)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.draw.connect(func():
		var s: Vector2 = c.size
		if kind == &"player": # explorador de chapeu, na cor da barra de vida
			UiArt.icon(c, &"player", Rect2(Vector2.ZERO, s), EMBER)
		elif _cycle_night: # lua crescente
			c.draw_circle(s * .5, s.y * .42, NIGHT_VIOLET)
			c.draw_circle(s * .5 + Vector2(s.x * .2, -s.y * .12), s.y * .36, Color(.03, .095, .09))
		else: # sol com raios
			for i in 8:
				var a := TAU * i / 8.0
				c.draw_line(s * .5 + Vector2(cos(a), sin(a)) * s.y * .3, s * .5 + Vector2(cos(a), sin(a)) * s.y * .48, GOLD, 2.0)
			c.draw_circle(s * .5, s.y * .24, GOLD))
	return c

# Icones vetoriais pequenos dos recursos (os mesmos da mochila).
func _resource_icon(kind: StringName, size: float) -> Control:
	if kind == &"defense":
		return app._crystal(size)
	return UiArt.icon_control(kind, size)

## Ficha de recurso: placa pequena de pedra com icone, valor e legenda.
## tier 0 = destaque (Pontos de Defesa), 1 = normal, 2 = secundaria.
func _resource_item(row: Node, kind: StringName, caption: String, color: Color, tier := 1) -> Label:
	var chip := PanelContainer.new()
	chip.name = "Chip_" + String(kind)
	var st := UiArt.carved(Color("10241e", 0.88), Color(color, 0.6 if tier == 0 else 0.32), Vector4(8, 3, 11, 4), 7.0)
	st.bg_top = Color("1d3c33", 0.9)
	st.inner_color = Color(0, 0, 0, 0)
	st.shadow_size = 4.0
	st.shadow_color = Color(0, 0, 0, 0.25)
	st.chisel = false
	st.border_width = 2.0 if tier == 0 else 1.5
	chip.add_theme_stylebox_override("panel", st)
	var item = HBoxContainer.new()
	item.add_theme_constant_override("separation", 6)
	item.add_child(_resource_icon(kind, [26.0, 21.0, 18.0][tier]))
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", -6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var value = app._label("0", [21, 17, 15][tier], color)
	value.add_theme_font_override("font", app._display_font())
	value.add_theme_color_override("font_outline_color", Color("0b1a15"))
	value.add_theme_constant_override("outline_size", 3)
	col.add_child(value)
	col.add_child(app._label(caption, 9, Color(CREAM, .72)))
	item.add_child(col)
	chip.add_child(item)
	row.add_child(chip)
	_resource_items[kind] = chip
	return value

func _build_points_panel(parent: Node) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_END
	points_text = _resource_item(row, &"defense", "DEFESA", Color("aef0cf"), 0)
	wood_text = _resource_item(row, &"wood", "MADEIRA", Color("e6c79a"))
	stone_text = _resource_item(row, &"stone", "PEDRA", Color("c9d3cc"))
	territory_text = _resource_item(row, &"territory", "TERRITÓRIOS", Color("9fe0c0"), 2) # Spec 015
	# Elixir de Jade: ficha so depois de liberado (Dia 2) ou com um guardado.
	_elixir_chip_text = _resource_item(row, &"elixir", "ELIXIR", UiArt.JADE_LIGHT, 2)
	_elixir_chip = _resource_items[&"elixir"]
	_elixir_chip.visible = false
	points_box = PanelContainer.new()
	points_box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	parent.add_child(points_box)
	points_box.add_child(row)
	points_box.name = "PointsPanel"
	points_box.tooltip_text = "Pontos de Defesa · Madeira · Pedra · Territórios recuperados"
	points_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	points_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	points_box.offset_right = -16
	points_box.offset_top = 14
	var esc := HBoxContainer.new()
	esc.add_theme_constant_override("separation", 6)
	esc.add_child(UiArt.keycap("ESC", app._display_font(), 11))
	var esc_label = app._label("pausa", 11, Color(CREAM, .85))
	esc_label.add_theme_color_override("font_outline_color", Color("10221e"))
	esc_label.add_theme_constant_override("outline_size", 4) # legivel em fundo claro
	esc.add_child(esc_label)
	esc.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	esc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	esc.offset_right = -18
	esc.offset_top = 70
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
	var gain = app._label(text, 14, color)
	gain.add_theme_font_override("font", app._display_font())
	gain.add_theme_color_override("font_outline_color", Color("10221e"))
	gain.add_theme_constant_override("outline_size", 4)
	gain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	self.add_child(gain)
	gain.name = node_name # depois do add_child, como os avisos (senao vira @Label@N)
	# Spec 017B/020: os "+N" empilham a esquerda do painel de recursos, no alto
	# (antes "+12 MADEIRA" e "+4 PEDRA" se sobrepunham e cobriam o inventario).
	var stacked := 0
	for other in get_children():
		if other != gain and other.has_meta("gain") and not other.is_queued_for_deletion():
			stacked += 1
	gain.set_meta("gain", true)
	var width = gain.get_minimum_size().x
	var x = points_box.global_position.x - width - 12.0
	gain.global_position = Vector2(x, points_box.global_position.y + 4.0 + 20.0 * stacked)
	var t = gain.create_tween().set_parallel()
	t.tween_property(gain, "position:y", gain.position.y - 14, 1.0)
	t.tween_property(gain, "modulate:a", 0.0, 1.0).set_delay(.4)
	t.chain().tween_callback(gain.queue_free)

# Painel contextual: so aparece perto de um ponto de defesa. Fica acima do
# painel de objetivo, nunca no centro da tela.
# Design 5.0: icone da torre + titulo + niveis (losangos), dados REAIS da
# tabela DefenseTower.LEVELS (dano, alcance, cadencia), previa do proximo nivel
# e quantos Pontos de Defesa faltam. A torre nao tem vida no sistema (nao e
# atacada), entao nao ha barra de vida.
var _tower_pips: Control
var _tower_stats: HBoxContainer
var _tower_stat_labels := {}
var _tower_next: Label
var _tower_missing: Label

func _build_defense_panel() -> void:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 10)
	head.add_child(UiArt.icon_control(&"tower", 26))
	build_title = app._label("TORRE DE DEFESA", 18, GOLD)
	build_title.add_theme_font_override("font", app._display_font())
	build_title.add_theme_color_override("font_outline_color", Color("1d1006"))
	build_title.add_theme_constant_override("outline_size", 4)
	build_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(build_title)
	_tower_pips = UiArt.drawn(Vector2(54, 16), func(ci: CanvasItem, r: Rect2):
		var lv: int = _tower_pips.get_meta("level", 0)
		for i in 3:
			var c := Vector2(9 + i * 18, r.size.y * 0.5)
			var d := PackedVector2Array([c + Vector2(0, -7), c + Vector2(6, 0), c + Vector2(0, 7), c + Vector2(-6, 0)])
			ci.draw_colored_polygon(d, UiArt.AMBER_LIGHT if i < lv else Color("1d3a31"))
			ci.draw_polyline(d + PackedVector2Array([d[0]]), Color("0b1a15"), 1.5))
	head.add_child(_tower_pips)
	box.add_child(head)
	build_info = app._label("", 15)
	build_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(build_info)
	_tower_stats = HBoxContainer.new()
	_tower_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	_tower_stats.add_theme_constant_override("separation", 18)
	for spec in [[&"damage", "DANO"], [&"range", "ALCANCE"], [&"cadence", "CADÊNCIA"]]:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 5)
		cell.add_child(UiArt.icon_control(spec[0], 20, UiArt.JADE_LIGHT))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -5)
		var value: Label = app._label("0", 17, CREAM)
		value.add_theme_font_override("font", app._display_font())
		col.add_child(value)
		col.add_child(app._label(spec[1], 9, Color(CREAM, .65)))
		cell.add_child(col)
		_tower_stats.add_child(cell)
		_tower_stat_labels[spec[0]] = value
	box.add_child(_tower_stats)
	_tower_next = app._label("", 12, UiArt.JADE_LIGHT)
	_tower_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_tower_next)
	build_button = app._menu_button(box, "CONSTRUIR", 18, Color("e9a23b"), Color("8a4f19"), 6, 12, 22, 4, func():
		if is_instance_valid(_build_slot):
			world.get_node("DefenseSlots").interact(_build_slot))
	build_button.focus_mode = Control.FOCUS_NONE # C e clique; nao rouba teclas
	build_note = app._label("", 14, EMBER)
	build_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(build_note)
	_tower_missing = app._label("", 13, Color("f0c9a0"))
	_tower_missing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_tower_missing)
	build_panel = app._panel(self, box)
	build_panel.name = "DefensePanel"
	build_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	build_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	build_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	build_panel.offset_top = -112
	build_panel.offset_bottom = -112
	build_panel.hide()

static func _seconds(v: float) -> String: # 0,85 s · 0,7 s · 1,0 s
	return str(snappedf(v, 0.01)).replace(".", ",") + " s"

func _show_tower_stats(s: Dictionary) -> void:
	_tower_stat_labels[&"damage"].text = "%d" % s.damage
	_tower_stat_labels[&"range"].text = "%d m" % s.range
	_tower_stat_labels[&"cadence"].text = _seconds(s.interval)

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
		build_info.visible = true
		build_button.text = "[C]  CONSTRUIR"
		_tower_pips.visible = false
		_show_tower_stats(DefenseTower.LEVELS[0]) # o que sera construido
		_tower_next.text = "Nível 1  ·  Sentinela do Jade"
	else:
		var tower = _build_slot.tower
		var s: Dictionary = tower.stats()
		build_title.text = "TORRE DE DEFESA  ·  NÍVEL %d" % tower.level
		build_info.text = ""
		build_info.visible = false
		build_button.text = "NÍVEL MÁXIMO" if tower.is_max_level() else "MELHORAR — %d  (C)" % cost
		_tower_pips.visible = true
		if _tower_pips.get_meta("level", 0) != tower.level:
			_tower_pips.set_meta("level", tower.level)
			_tower_pips.queue_redraw()
		_show_tower_stats(s)
		if tower.is_max_level():
			_tower_next.text = "Bastião Ancestral  ·  nível máximo"
		else:
			var n: Dictionary = DefenseTower.LEVELS[tower.level]
			_tower_next.text = "PRÓXIMO NÍVEL  →  Dano %d  ·  Alcance %d m  ·  %s" % [n.damage, n.range, _seconds(n.interval)]
	build_button.disabled = reason != ""
	build_note.text = reason if reason != "NÍVEL MÁXIMO" else ""
	build_note.visible = build_note.text != ""
	var missing := 0
	if reason == "Pontos insuficientes":
		missing = maxi(0, cost - int(world.get_node("DefenseEconomy").points))
	_tower_missing.text = "Faltam %d Pontos de Defesa" % missing if missing > 0 else ""
	_tower_missing.visible = missing > 0

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
var _recipe_rows = {} # painel -> {recipe_id: {"button", "status"}}

func _placer() -> Node:
	return world.get_node("BuildPlacer") if is_instance_valid(world) else null

## Linha de custo; devolve os rotulos [madeira, pedra] para colorir o que falta.
func _cost_line(parent: Node, wood: int, stone: int) -> Array:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.add_child(_resource_icon(&"wood", 15))
	var wood_label = app._label("%d Madeira" % wood, 13, Color("e6c79a"))
	row.add_child(wood_label)
	row.add_child(app._label("•", 13, Color(CREAM, .6)))
	row.add_child(_resource_icon(&"stone", 15))
	var stone_label = app._label("%d Pedra" % stone, 13, Color("c9d3cc"))
	row.add_child(stone_label)
	parent.add_child(row)
	return [wood_label, stone_label]

## Descricao curta de cada construcao (valores lidos dos proprios scripts).
const RECIPE_INFO := {
	&"campfire": ["Segure H perto dela: +25 de vida em 3 s. 2 cargas, que voltam com o tempo.", "Onde: área de construção do Refúgio · máx. 1"],
	&"trap": ["Espinhos ferem quem pisa (15 de dano, 3 cargas).", "Onde: sobre as trilhas noturnas · máx. 5"],
}

func _recipe_list(box: VBoxContainer, rows: Dictionary, big := false) -> void:
	for id in BuildRecipes.order():
		var r = BuildRecipes.get_recipe(id)
		var entry: VBoxContainer = _inv_tile(box, GOLD) if big else VBoxContainer.new()
		entry.add_theme_constant_override("separation", 3 if big else 2)
		if big: # 3.0: icone proprio da estrutura ao lado do nome
			var head := HBoxContainer.new()
			head.add_theme_constant_override("separation", 10)
			head.add_child(UiArt.icon_control(&"campfire" if id == BuildRecipes.CAMPFIRE else &"trap", 26))
			var title = app._label(r.name, 17, UiArt.AMBER_LIGHT)
			title.add_theme_font_override("font", app._display_font())
			head.add_child(title)
			entry.add_child(head)
		else:
			entry.add_child(app._label(r.name, 15, GOLD))
		if big and RECIPE_INFO.has(id):
			for k in 2:
				var info = app._label(RECIPE_INFO[id][k], 13 if k == 0 else 12, Color(CREAM, .85 if k == 0 else .6))
				info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				entry.add_child(info)
		var costs: Array = _cost_line(entry, r.wood, r.stone)
		var line = HBoxContainer.new()
		var status = app._label("", 12, EMBER)
		status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(status)
		var button = app._menu_button(line, "CONSTRUIR", 14, Color("e9a23b"), Color("8a4f19"), 5, 9, 14, 2, func(): _start_placement(id))
		# No inventario grande os botoes recebem foco (Tab/setas + Enter); no
		# painel compacto (B) nao roubam teclas.
		button.focus_mode = Control.FOCUS_ALL if big else Control.FOCUS_NONE
		entry.add_child(line)
		if not big:
			box.add_child(entry)
		rows[id] = {"button": button, "status": status, "wood": costs[0], "stone": costs[1], "need": Vector2i(r.wood, r.stone)}

func _side_panel(title: String, box: VBoxContainer) -> PanelContainer:
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size.x = 260
	var head = app._label(title, 17, GOLD)
	head.add_theme_font_override("font", app._display_font())
	box.add_child(head)
	box.move_child(head, 0)
	var p = _hud_panel(self, box)
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.offset_right = -16
	p.offset_top = 112 # abaixo dos recursos e do "+N"; nao cresce a HUD do topo
	p.mouse_filter = Control.MOUSE_FILTER_STOP # clique no painel nao ataca
	p.hide()
	return p

func _build_inventory_panels() -> void:
	_recipe_rows = {} # a HUD e recriada a cada partida: nada da anterior (ja liberado)
	_build_big_inventory()
	var inv_rows := {}
	_recipe_list(_inv_recipes_box, inv_rows, true)
	_recipe_rows[inventory_panel] = inv_rows
	# CONSTRUCAO (B): so as receitas, compacto.
	var bm = VBoxContainer.new()
	var bm_rows = {}
	_recipe_list(bm, bm_rows)
	bm.add_child(app._label("B fecha", 11, Color(CREAM, .6)))
	build_menu_panel = _side_panel("CONSTRUIR", bm)
	build_menu_panel.name = "BuildMenuPanel"
	_recipe_rows[build_menu_panel] = bm_rows
	# Dica do posicionamento (mesmo lugar do painel de ponto de defesa).
	var pbox = VBoxContainer.new()
	pbox.add_theme_constant_override("separation", 2)
	placement_title = app._label("", 16, GOLD)
	placement_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pbox.add_child(placement_title)
	var keys = app._label("Clique: construir  ·  R: girar  ·  Botão direito / ESC: cancelar", 12)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pbox.add_child(keys)
	placement_note = app._label("", 13, EMBER)
	placement_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pbox.add_child(placement_note)
	placement_panel = _hud_panel(self, pbox)
	placement_panel.name = "PlacementPanel"
	placement_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	placement_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	placement_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	placement_panel.offset_top = -100
	placement_panel.offset_bottom = -100
	app._ignore_mouse(placement_panel) # dica nunca bloqueia o clique de construir
	placement_panel.hide()
	var stock = world.get_node("ResourceStock")
	stock.resources_changed.connect(func(_k, _t, _d): _refresh_inventory()) # RF-INV-001: por sinal
	var placer = _placer()
	placer.notice.connect(func(text: String): _show_toast("BuildNotice", text, GOLD if text.ends_with("CONSTRUÍDA") else EMBER))
	placer.structure_built.connect(_on_structure_built)
	_refresh_inventory()

func _refresh_inventory() -> void:
	_refresh_elixir()
	if not is_instance_valid(inv_wood_text) or not is_instance_valid(world):
		return
	var stock = world.get_node("ResourceStock")
	inv_wood_text.text = str(stock.get_amount(&"wood"))
	inv_stone_text.text = str(stock.get_amount(&"stone"))
	_refresh_defense_info()
	var placer = _placer()
	var have := Vector2i(stock.get_amount(&"wood"), stock.get_amount(&"stone"))
	for panel in _recipe_rows:
		for id in _recipe_rows[panel]:
			var row: Dictionary = _recipe_rows[panel][id]
			var reason: String = placer.recipe_block_reason(id)
			row.status.text = reason
			row.button.disabled = reason != ""
			# Spec 017B/020: o custo que falta fica em vermelho, com quanto falta.
			var need: Vector2i = row.need
			for k in [["wood", "Madeira", have.x, need.x, Color("e6c79a")], ["stone", "Pedra", have.y, need.y, Color("c9d3cc")]]:
				var label: Label = row[k[0]]
				var short: int = k[3] - k[2]
				label.text = "%d %s" % [k[3], k[1]] + ("  (faltam %d)" % short if short > 0 else "")
				label.add_theme_color_override("font_color", EMBER if short > 0 else k[4])

func toggle_inventory() -> void:
	build_menu_panel.hide()
	inventory_panel.visible = not inventory_panel.visible
	_refresh_inventory()
	if inventory_panel.visible:
		inventory_panel.move_to_front() # acima de avisos e do painel do tutorial
		_inv_close.grab_focus() # teclado: Tab/setas percorrem FECHAR e CONSTRUIR
	elif is_instance_valid(get_viewport().gui_get_focus_owner()):
		get_viewport().gui_get_focus_owner().release_focus()

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
	if inventory_panel.visible:
		toggle_inventory() # fecha e solta o foco do teclado
		return true
	if build_menu_panel.visible:
		inventory_panel.hide()
		build_menu_panel.hide()
		return true
	return false

func _update_build_ui() -> void:
	if not is_instance_valid(placement_panel):
		return
	var placer = _placer()
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
	var hurt = current < player_bar.value and player_bar.max_value == maximum
	var previous: float = player_bar.value / maxf(player_bar.max_value, 0.001)
	player_bar.max_value = maximum
	player_bar.value = current
	player_text.text = "JOGADOR  %d / %d" % [ceili(current), int(maximum)]
	if hurt: # tinta breve na barra e no texto, rastro do dano e medalhao piscando; nada na camera
		_hurt_bar(player_bar, previous)
		_flash_medal(_player_medal)
		for node in [player_bar, player_text]:
			node.modulate = Color(1.0, .45, .4)
			node.create_tween().tween_property(node, "modulate", Color.WHITE, .35)

# RF-VID-007: aviso pequeno e passageiro, sem modal e sem pausar.
func _on_player_died() -> void:
	if not is_instance_valid(self):
		return
	var box = VBoxContainer.new()
	death_text = app._label("", 19, EMBER)
	box.add_child(death_text)
	death_toast = app._panel(self, box)
	death_toast.name = "DeathToast"
	death_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	death_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	death_toast.offset_top = 170
	death_toast.offset_bottom = 170
	app._ignore_mouse(death_toast)
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

func _show_toast(toast_name: String, text: String, color: Color) -> void:
	if not is_instance_valid(self):
		return
	var box = VBoxContainer.new()
	box.add_child(app._label(text, 20, color))
	# Spec 017B/020: avisos simultaneos empilham (antes ficavam um sobre o outro).
	var stacked := 0
	for other in get_children():
		if other.has_meta("toast") and not other.is_queued_for_deletion() and other.modulate.a > 0.05:
			stacked += 1
	var toast = app._panel(self, box)
	toast.name = toast_name
	toast.set_meta("toast", true)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.offset_top = 112 + 58 * mini(stacked, 3)
	toast.offset_bottom = toast.offset_top
	app._ignore_mouse(toast) # aviso nunca bloqueia cliques no mundo
	var fade = toast.create_tween()
	fade.tween_interval(DAWN_TOAST_TIME)
	fade.tween_property(toast, "modulate:a", 0.0, 0.5)
	fade.tween_callback(toast.queue_free)

## Spec 017B/020: a noite comecou — a onda esta a caminho (alerta curto).
func _on_night_started() -> void:
	_show_toast("NightStartToast", "NOITE %d  ·  INVASORES A CAMINHO" % DayNightManager.day_number, NIGHT_VIOLET)
	# 3.0: vinheta violeta curta nas bordas (a onda chegou); some em 1,6 s e
	# nunca bloqueia cliques.
	var g := Gradient.new()
	g.set_color(0, Color(UiArt.NIGHT, 0.0))
	g.set_color(1, Color(UiArt.NIGHT.lightened(0.15), 0.75))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.15, 1.0)
	var veil := TextureRect.new()
	veil.name = "NightVignette"
	veil.texture = tex
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.modulate.a = 0.0
	add_child(veil)
	move_child(veil, 0) # atras dos paineis
	var t := veil.create_tween()
	t.tween_property(veil, "modulate:a", 1.0, 0.35)
	t.tween_property(veil, "modulate:a", 0.0, 1.25)
	t.tween_callback(veil.queue_free)

func _process(_delta: float) -> void:
	_elixir_tick -= _delta
	if _elixir_tick <= 0.0:
		_elixir_tick = 0.15
		_update_elixir_preview()
	if not is_instance_valid(world) or not is_instance_valid(self):
		return
	_update_death_toast() # so a contagem do aviso; nada roda sem o aviso aberto
	_update_defense_panel() # Spec 013B: painel contextual do ponto de defesa
	var base = world.get_node("Territory")
	var base_before: float = base_bar.value / maxf(base_bar.max_value, 0.001)
	base_bar.max_value = base.max_health
	base_bar.value = base.health
	base_text.text = "REFÚGIO  %d / %d" % [base.health, base.max_health]
	# Design 5.0: o Refugio levou dano -> rastro na barra e medalhao pisca.
	if _last_base_health >= 0.0 and base.health < _last_base_health:
		_hurt_bar(base_bar, base_before)
		_flash_medal(_refuge_medal)
	_last_base_health = base.health
	_tick_vitals(_delta)
	var wave: Dictionary = world.get_node("WaveManager").snapshot()
	var day: int = DayNightManager.day_number
	phase_text.text = ("NOITE %d" if DayNightManager.is_night() else "DIA %d") % day # 013C: "DIA 1 • 08:58"
	clock_text.text = DayNightManager.clock_text()
	if DayNightManager.is_night():
		wave_text.text = "DEFESA  ·  Noites: %d" % app.victory_count
		onda_text.text = "%d/%d criados  ·  %d neutralizados  ·  %d ativos" % [wave.spawned, wave.total, wave.resolved, wave.active]
		onda_text.show()
	else:
		wave_text.text = "PREPARAÇÃO  ·  Noites: %d" % app.victory_count
		onda_text.hide()
	# RF-CIC-002: ultimos segundos antes das 18:00, sem modal nem bloqueio.
	var left: float = DayNightManager.seconds_until_night()
	countdown_text.visible = DayNightManager.is_day() and left > 0.0 and left <= DayNightManager.night_countdown_seconds
	if countdown_text.visible:
		countdown_text.text = "ANOITECE EM %d" % ceili(left)
	var player = world.get_node("Player")
	var channel = player.get_node("DomesticationChannel")
	channel_bar.value = channel.get_progress()
	var allies = get_tree().get_nodes_in_group("domesticated")
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
	# Spec 022: no tutorial, o objetivo e o passo atual (o painel do tutorial
	# explica; aqui fica so o titulo curto).
	if objective_override != "":
		objective.text = objective_override
	for dino in get_tree().get_nodes_in_group("wild_dino"):
		if dino.global_position.distance_to(player.global_position) < 3.2:
			if dino.can_be_domesticated(): hint.text = "SEGURE E  ·  %.1f / 2.0 s  ·  Soltar ou afastar cancela" % (channel.get_progress()*2)
			elif not dino.is_domesticable: hint.text = "CARNOTAURO  ·  Esta variante não pode ser domesticada."
	for ally in allies:
		if ally.global_position.distance_to(player.global_position) < 3.3:
			hint.text = "ALIADO %d/80 HP  ·  %s  ·  %s" % [ally.hp, "SEGUINDO" if ally.ally_state == 0 else "DEFENDENDO POSTO", "F alterna seguir/ficar" if DayNightManager.is_day() else "Posicionamento bloqueado durante a noite"]
	# Spec 013D: Fogueira de Cura — dica de uso e barra "CURANDO..."
	var fire = get_tree().get_first_node_in_group("healing_campfire")
	var healing = 0.0
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
	# Spec 017B/020: coletavel ao alcance — anel no chao e dica com a recompensa
	# (so leitura: o golpe continua sendo o ataque normal).
	_update_collect_focus(player)
	_range_hint_left = maxf(0.0, _range_hint_left - get_process_delta_time())
	if _range_hint_left > 0.0:
		hint.text = "FORA DE ALCANCE  ·  Chegue mais perto (o golpe alcança ~2 m)"
	hint.visible = hint.text != ""
	_update_hint_key()
	_update_alerts()
	_update_creature_labels(player)
	channel_bar.visible = channel.get_progress() > 0.0 or healing > 0.0 or claim > 0.0
	if healing > 0.0:
		channel_bar.value = healing
	if claim > 0.0:
		channel_bar.value = claim
	_update_build_ui()
	_update_cycle()

# ---------------------------------------------------------------------------
# Visual Overhaul 3.0 — leitura da HUD (so apresentacao; nada de regra aqui)
# ---------------------------------------------------------------------------

## Tecla desenhada ao lado da dica de acao (le o proprio texto da dica).
func _update_hint_key() -> void:
	if not is_instance_valid(_hint_key):
		return
	var key := ""
	var t := hint.text
	if t.contains("SEGURE E") or t.contains("Segure E") or t.contains("segure E"):
		key = "E"
	elif t.contains("Segure H"):
		key = "H"
	elif t.contains("F alterna"):
		key = "F"
	elif t.contains("Golpeie para coletar"):
		key = "CLIQUE"
	_hint_key.visible = hint.visible and key != ""
	if key != "" and _hint_key.get_meta("text") != key:
		UiArt.set_keycap(_hint_key, key, app._display_font(), 13)

## Bordas de alerta: vida baixa pulsa em brasa; a noite tinge o relogio de violeta.
func _update_alerts() -> void:
	var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.008)
	var health := get_node_or_null("HealthPanel") as PanelContainer
	if health != null:
		var low := player_bar.value < player_bar.max_value * 0.3 or base_bar.value < base_bar.max_value * 0.35
		health.get_theme_stylebox("panel").border_color = Color(UiArt.EMBER, pulse) if low else Color("3d6a57", .9)
	var phase := get_node_or_null("PhasePanel") as PanelContainer
	if phase != null:
		var edge := Color("3d6a57", .9)
		if countdown_text.visible:
			edge = Color(UiArt.AMBER, pulse)
		elif DayNightManager.is_night():
			edge = Color(NIGHT_VIOLET, .8)
		phase.get_theme_stylebox("panel").border_color = edge

## Rotulos das criaturas por contexto (World 6.0: identificacao + numero no
## rotulo e a BARRA de vida grafica embaixo). Regras de visibilidade:
## - ALIADO: o mais perto do Player (foco) sempre; outros so feridos e perto,
##   ou logo depois de levar dano / receber cura;
## - SELVAGEM: so em combate (ferido, golpeado ha pouco) ou bem perto;
## - GUARDIAO: em confronto (ferido, golpeado ha pouco ou perto);
## - INVASOR: durante o combate, ate uma distancia; os mais distantes menores.
## Rotulos que se sobrepoem na tela: fica o de maior prioridade (invasor >
## guardiao > selvagem > aliado em foco > aliado ferido) e no maximo
## MAX_LABELS ao mesmo tempo (onda grande nao cobre a tela). So visibilidade,
## tamanho e barra: o texto (testado) e a logica de combate nao mudam.
const LABEL_PIXEL := 0.0085 # World 6.0: legivel da camera estrategica (era 0,0065)
const MAX_LABELS := 9
const MAX_BARS_ONLY := 12 # criaturas sem espaco para o texto mostram so a barra
const RECENT := 5.0 # s em que um golpe/cura deixa a criatura "em destaque"
const CreatureHealthBar := preload("res://scenes/visuals/creature_health_bar.gd")

## Marca o instante do ultimo golpe/cura de cada criatura (le a mudanca de hp).
func _recent_change(dino: Node) -> bool:
	var now := Time.get_ticks_msec() * 0.001
	var last_hp: float = dino.get_meta("hud_hp", dino.hp)
	if not is_equal_approx(last_hp, dino.hp):
		dino.set_meta("hud_hp_at", now)
		dino.set_meta("hud_hp", dino.hp)
	return now - float(dino.get_meta("hud_hp_at", -100.0)) < RECENT

func _faction(dino: Node) -> StringName:
	if dino.get("is_domesticated") == true:
		return &"ally"
	if dino.is_in_group("wave_enemy"):
		return &"invader"
	if String(dino.get("guardian_of")) != "":
		return &"guardian"
	return &"wild"

func _update_creature_labels(player: Node3D) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or player == null:
		return
	var focus: Node3D = null
	var best := 3.3
	var allies := get_tree().get_nodes_in_group("domesticated")
	for ally in allies:
		var d: float = ally.global_position.distance_to(player.global_position)
		if d < best:
			best = d
			focus = ally
	var entries := []
	for dino in get_tree().get_nodes_in_group("wild_dino") + allies:
		var label := dino.get("hp_label") as Label3D
		if label == null or not is_instance_valid(label):
			continue
		var d := Vector2(dino.global_position.x - player.global_position.x, dino.global_position.z - player.global_position.z).length()
		var hurt: bool = dino.hp < WildDino.MAX_HP - 0.5
		var recent := _recent_change(dino)
		var kind := _faction(dino)
		var pri := 0
		var size := 1.0
		var show := true
		match kind:
			&"ally":
				if dino == focus:
					pri = 1
				elif (hurt and d < 14.0) or (recent and d < 18.0):
					size = 0.75
				else:
					show = false
			&"invader":
				pri = 4
				show = d < 22.0 or recent
				size = 1.0 if d < 14.0 else 0.8
			&"guardian":
				pri = 3
				show = d < 12.0 or ((hurt or recent) and d < 22.0)
			_:
				pri = 2
				show = d < 6.0 or ((hurt or recent) and d < 18.0)
		label.pixel_size = LABEL_PIXEL * size
		label.modulate.a = 1.0 if size >= 1.0 else 0.8
		if not show or cam.is_position_behind(label.global_position):
			label.visible = false
			continue
		var at := cam.unproject_position(label.global_position)
		var w := label.text.length() * 10.5 * size
		# o retangulo inclui a barra embaixo do texto
		entries.append([pri, d, label, Rect2(at - Vector2(w * 0.5, 12.0 * size), Vector2(w, 32.0 * size)), dino, kind])
	entries.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var taken: Array[Rect2] = []
	var bar_rects: Array[Rect2] = [] # faixa das barras (texto e so-barra)
	var bars_only := 0
	for e in entries:
		var free := taken.size() < MAX_LABELS
		for r in taken:
			if r.intersects(e[3]):
				free = false
				break
		var label: Label3D = e[2]
		label.modulate.a = 1.0 if label.pixel_size >= LABEL_PIXEL else 0.8
		label.set_meta("bar_only", false)
		label.outline_modulate.a = 0.85
		var bar_rect := Rect2(e[3].position + Vector2(e[3].size.x * 0.5 - 22.0, 14.0), Vector2(44.0, 8.0))
		if free:
			label.visible = true
			taken.append(e[3])
			bar_rects.append(bar_rect)
			_update_health_bar(e[4], label, e[5])
			continue
		# Sem espaco para o texto: so a barra, se ela nao cobrir outra barra.
		var bar_free := bars_only < MAX_BARS_ONLY
		for r in bar_rects:
			if r.intersects(bar_rect):
				bar_free = false
				break
		label.visible = bar_free
		if bar_free:
			bars_only += 1
			bar_rects.append(bar_rect)
			label.set_meta("bar_only", true)
			label.modulate.a = 0.0 # texto e contorno somem; a barra (filha) continua
			label.outline_modulate.a = 0.0
			_update_health_bar(e[4], label, e[5], 0.85)

## Barra de vida grafica (shader) sob o rotulo: criada na primeira vez que a
## criatura aparece, depois so recebe a fracao e a faccao. Fica dentro do
## rotulo: some e aparece junto com ele.
func _update_health_bar(dino: Node, label: Label3D, kind: StringName, opacity := -1.0) -> void:
	var bar = label.get_node_or_null("HealthBar")
	var frac: float = clampf(dino.hp / maxf(WildDino.MAX_HP, 1.0), 0.0, 1.0)
	if bar == null:
		bar = CreatureHealthBar.new()
		label.add_child(bar)
		bar.snap(frac)
	var s := label.pixel_size / LABEL_PIXEL
	bar.scale = Vector3.ONE * s
	bar.position = Vector3(0, -label.font_size * label.pixel_size * 0.78, 0)
	bar.show_health(frac, kind, label.modulate.a if opacity < 0.0 else opacity)

## Design 5.0: rastro do dano, piscar dos medalhoes, estado critico (anel em
## brasa) e a ficha do Elixir de Jade (so leitura do JadeElixir).
func _tick_vitals(delta: float) -> void:
	_tick_ghost(player_bar, delta)
	_tick_ghost(base_bar, delta)
	var crit := {_player_medal: player_bar.value < player_bar.max_value * 0.3, _refuge_medal: base_bar.value < base_bar.max_value * 0.35}
	for medal: Control in crit:
		if not is_instance_valid(medal):
			continue
		var flash: float = medal.get_meta("flash", 0.0)
		if flash > 0.0:
			medal.set_meta("flash", maxf(0.0, flash - delta / 0.35))
		var was: bool = medal.get_meta("critical", false)
		medal.set_meta("critical", crit[medal])
		if flash > 0.0 or crit[medal] or was != crit[medal]:
			medal.queue_redraw()
	var elixir = world.get_node_or_null("JadeElixir")
	if elixir != null and is_instance_valid(_elixir_chip):
		_elixir_chip.visible = elixir.stored > 0 or DayNightManager.day_number >= 2 # liberado no Dia 2
		_elixir_chip_text.text = "%d/1" % elixir.stored
		_elixir_chip.modulate.a = 1.0 if elixir.stored > 0 else 0.7

## Sol/lua e barra do periodo atual (fracao do dia ou da noite ja passada).
func _update_cycle() -> void:
	if not is_instance_valid(_cycle_bar):
		return
	var night: bool = DayNightManager.is_night()
	var duration: float = DayNightManager.night_duration_seconds if night else DayNightManager.day_duration_seconds
	_cycle_bar.value = clampf(DayNightManager.phase_elapsed / maxf(duration, 0.001), 0.0, 1.0)
	if night != _cycle_night:
		_cycle_night = night
		_cycle_fill.bg_color = NIGHT_VIOLET if night else GOLD
		_cycle_icon.queue_redraw()
	if is_instance_valid(_cycle_dial):
		_cycle_dial.queue_redraw()

func _update_collect_focus(player: Node3D) -> void:
	var best: Node3D = null
	var best_d := 2.8
	for item in get_tree().get_nodes_in_group("collectable"):
		if item.depleted:
			continue
		var d: float = Vector2(item.global_position.x - player.global_position.x, item.global_position.z - player.global_position.z).length()
		if d < best_d:
			best_d = d
			best = item
	if best == null:
		if is_instance_valid(_focus_ring):
			_focus_ring.visible = false
		return
	if not is_instance_valid(_focus_ring):
		_focus_ring = MeshInstance3D.new()
		_focus_ring.name = "CollectFocus"
		_focus_ring.mesh = CombatFX.ring_mesh()
		_focus_ring.material_override = CombatFX.fx_material(Color("e9c27a"), 0.7)
		_focus_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(_focus_ring)
	_focus_ring.visible = true
	_focus_ring.global_position = Vector3(best.global_position.x, 0.06, best.global_position.z)
	_focus_ring.scale = Vector3.ONE * (1.25 if best.kind == "stone" else 0.95) * (1.0 + 0.05 * sin(Time.get_ticks_msec() * 0.006))
	if hint.text == "":
		hint.text = "%s  ·  Golpeie para coletar  ·  +%d %s" % ["ÁRVORE" if best.kind == "wood" else "ROCHA COM MINÉRIO", best.reward(), best.label()]

# ---------------------------------------------------------------------------
# Inventario — "Mochila do Explorador" (Visual Overhaul 3.0). Cartao central
# de pedra e jade (~78% da largura de referencia 1280x720, escala com a janela)
# sobre um veu escuro que bloqueia cliques no mundo, com tres abas:
# RECURSOS, CONSTRUCOES e COMPANHEIROS (teclas 1, 2, 3 ou clique).
# NAO pausa: contrato aprovado da 013D (o relogio e a noite continuam
# correndo; um indicador no rodape avisa). Fecha com I, ESC, FECHAR ou clique
# fora. Mostra so dados reais: ResourceStock, BuildPlacer, DefenseEconomy,
# DefenseSlots, TerritoryManager e os aliados (grupo "domesticated").
# ---------------------------------------------------------------------------
const CARD_WIDTH := 1000.0
const PAGE_HEIGHT := 392.0
const DefenseTower := preload("res://scenes/world/defense_tower.gd")
const WildDino := preload("res://scenes/enemies/wild_dino.gd")
const TABS := [["resources", "RECURSOS", &"crystal_stone"], ["build", "CONSTRUÇÕES", &"tool"], ["companions", "COMPANHEIROS", &"skull"]]
var _inv_recipes_box: VBoxContainer
var _inv_card: PanelContainer
var _inv_close: Button
var _def_points: Label
var _def_towers: Label
var _def_territories: Label
var _def_structures: Label
var _res_points: Label
var _res_territories: Label
var _inv_tabs := {} # id -> Button
var _inv_pages := {} # id -> Control
var inventory_tab := "resources"
var _companion_grid: GridContainer
var _companion_empty: Control
var _companion_cards := {} # aliado -> {hp, bar, state, info}
var _companion_count: Label
var _world_clock: Label

func _inv_section(title: String, hint: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head = app._label(title, 15, UiArt.JADE_LIGHT)
	head.add_theme_font_override("font", app._display_font())
	head.add_theme_color_override("font_outline_color", Color("0b1a15"))
	head.add_theme_constant_override("outline_size", 3)
	col.add_child(head)
	if hint != "":
		var sub = app._label(hint, 12, Color(CREAM, .66))
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(sub)
	col.add_child(UiArt.drawn(Vector2(0, 10), func(ci: CanvasItem, r: Rect2): FossilUI.bone_divider(ci, r)))
	return col

## Nicho de pedra (World 6.0): cavidade mais escura escavada na placa, com
## filete na cor do tema — conteudo legivel sobre fundo calmo.
func _inv_tile(parent: Node, style_color: Color) -> VBoxContainer:
	var tile := PanelContainer.new()
	var sb := UiArt.carved(Color(0.07, 0.1, 0.085, 0.8), Color(style_color, 0.4), Vector4(14, 10, 14, 12), 10.0)
	sb.bg_top = Color(0.04, 0.06, 0.05, 0.85) # escuro em cima: parece escavado
	sb.inner_color = Color(FossilUI.BONE, 0.07)
	sb.shadow_size = 0.0
	sb.border_width = 1.5
	sb.chisel = true
	tile.add_theme_stylebox_override("panel", sb)
	parent.add_child(tile)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	tile.add_child(box)
	return box

func _big_value(text: String, color: Color, size := 34) -> Label:
	var l = app._label(text, size, color)
	l.add_theme_font_override("font", app._display_font())
	l.add_theme_color_override("font_outline_color", UiArt.INK)
	l.add_theme_constant_override("outline_size", 4)
	return l

func _build_big_inventory() -> void:
	# World 6.0: veu que escurece e tira a cor do jogo (que continua rodando e
	# visivel atras) — e o proprio inventory_panel, que bloqueia cliques no mundo.
	inventory_panel = PanelContainer.new()
	inventory_panel.name = "InventoryPanel"
	inventory_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(inventory_panel)
	inventory_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_panel.mouse_filter = Control.MOUSE_FILTER_STOP # nada atravessa para o mundo
	inventory_panel.gui_input.connect(_on_veil_input)
	var veil := ColorRect.new()
	veil.name = "Veil"
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var veil_mat := ShaderMaterial.new()
	veil_mat.shader = preload("res://scenes/ui/inventory_veil.gdshader")
	veil.material = veil_mat
	inventory_panel.add_child(veil)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_panel.add_child(center)
	# Placa arqueologica: contorno irregular, rachaduras com jade, vertebras,
	# amonite, ossos, pegadas e cristais na borda (FossilUI.slab).
	_inv_card = PanelContainer.new()
	_inv_card.name = "InventoryCard"
	var card_style := StyleBoxEmpty.new()
	card_style.content_margin_left = 34
	card_style.content_margin_right = 34
	card_style.content_margin_top = 28
	card_style.content_margin_bottom = 24
	_inv_card.add_theme_stylebox_override("panel", card_style)
	_inv_card.custom_minimum_size.x = CARD_WIDTH
	_inv_card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_inv_card)
	_inv_card.draw.connect(func(): FossilUI.slab(_inv_card, Rect2(Vector2.ZERO, _inv_card.size), 3.0))
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_inv_card.add_child(root)
	# Cabecalho: mochila, titulo e como fechar.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root.add_child(header)
	header.add_child(UiArt.drawn(Vector2(46, 46), _draw_backpack))
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title = app._label("MOCHILA DO EXPLORADOR", 27, UiArt.AMBER_LIGHT)
	title.name = "InventoryTitle"
	title.add_theme_font_override("font", app._display_font())
	title.add_theme_color_override("font_outline_color", Color("2a160a"))
	title.add_theme_constant_override("outline_size", 5)
	titles.add_child(title)
	titles.add_child(app._label("Diário de expedição  ·  recursos, construções e companheiros", 13, Color(CREAM, .7)))
	header.add_child(titles)
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 5)
	keys.add_child(UiArt.keycap("I", app._display_font(), 13))
	keys.add_child(app._label("ou", 12, Color(CREAM, .55)))
	keys.add_child(UiArt.keycap("ESC", app._display_font(), 12))
	header.add_child(keys)
	_inv_close = app._menu_button(header, "FECHAR", 15, UiArt.STONE, UiArt.STONE_EDGE, 5, 9, 18, 5, toggle_inventory)
	_inv_close.name = "InventoryClose"
	# Abas.
	var tabs := HBoxContainer.new()
	tabs.name = "InventoryTabs"
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	var group := ButtonGroup.new()
	for i in TABS.size():
		var spec: Array = TABS[i]
		var b := _tab_button(spec[1], spec[2], str(i + 1), group)
		b.name = "Tab_" + spec[0]
		b.pressed.connect(show_inventory_tab.bind(spec[0]))
		tabs.add_child(b)
		_inv_tabs[spec[0]] = b
	var tabs_fill := Control.new()
	tabs_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(tabs_fill)
	tabs.add_child(UiArt.drawn(Vector2(46, 34), func(ci: CanvasItem, r: Rect2): UiArt.claw_marks(ci, r.grow(-4), Color(UiArt.IVORY, .22))))
	root.add_child(UiArt.drawn(Vector2(0, 10), func(ci: CanvasItem, r: Rect2): FossilUI.bone_divider(ci, r)))
	# Paginas (todas com a mesma altura: trocar de aba nao mexe no cartao).
	var pages := Control.new()
	pages.custom_minimum_size.y = PAGE_HEIGHT
	root.add_child(pages)
	for spec in TABS:
		var page := MarginContainer.new()
		page.name = "Page_" + spec[0]
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.add_theme_constant_override("margin_top", 6)
		pages.add_child(page)
		_inv_pages[spec[0]] = page
	_build_resources_page(_inv_pages["resources"])
	_build_build_page(_inv_pages["build"])
	_build_companions_page(_inv_pages["companions"])
	# Rodape: atalho de construcao + "o mundo continua em movimento".
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	root.add_child(foot)
	foot.add_child(UiArt.keycap("B", app._display_font(), 12))
	foot.add_child(app._label("constrói direto, sem abrir a mochila", 12, Color(CREAM, .55)))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(fill)
	var running := UiArt.drawn(Vector2(16, 16), func(ci: CanvasItem, r: Rect2):
		var a := Time.get_ticks_msec() * 0.003
		ci.draw_arc(r.get_center(), 6.5, 0, TAU, 16, Color(UiArt.AMBER, .8), 1.5)
		ci.draw_line(r.get_center(), r.get_center() + Vector2(cos(a), sin(a)) * 5.0, UiArt.AMBER, 1.5))
	running.name = "WorldRunningIcon"
	foot.add_child(running)
	_world_clock = app._label("O MUNDO CONTINUA EM MOVIMENTO", 12, Color(UiArt.AMBER, .85))
	_world_clock.name = "WorldRunning"
	foot.add_child(_world_clock)
	inventory_panel.hide()
	show_inventory_tab(inventory_tab)

## Aba: tabuleta de pedra com pinos de osso, icone fossil, nome e a tecla
## (1, 2, 3); a ativa ganha o fundo jade e o icone aceso.
func _tab_button(text: String, icon: StringName, key: String, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(216, 44)
	b.add_theme_font_override("font", app._display_font())
	b.add_theme_font_size_override("font_size", 15)
	var styles := UiArt.button_styles(Color("262b26"), Color(FossilUI.BONE_SHADE, 0.55), 3, 6, 54, 6)
	var on := UiArt.button_styles(UiArt.JADE_DEEP.darkened(0.25), UiArt.JADE, 3, 6, 54, 6)
	for state in styles:
		b.add_theme_stylebox_override(state, styles[state])
	b.add_theme_stylebox_override("pressed", on.normal)
	b.add_theme_stylebox_override("hover_pressed", on.hover)
	b.add_theme_color_override("font_color", Color(CREAM, .72))
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", CREAM)
	b.draw.connect(func():
		var h := b.size.y - 3.0
		for x in [7.0, b.size.x - 7.0]: # pinos de osso nas pontas
			b.draw_circle(Vector2(x, h * .5), 2.6, Color(FossilUI.BONE, .55))
		FossilUI.icon(b, icon, Rect2(Vector2(16, h * .18), Vector2(h * .64, h * .64)), UiArt.JADE_LIGHT if b.button_pressed else Color(FossilUI.BONE, .75))
		var kr := Rect2(Vector2(b.size.x - 30, h * .5 - 9), Vector2(16, 18))
		b.draw_rect(kr, Color(UiArt.AMBER, .9 if b.button_pressed else .35), false, 1.5)
		var f: Font = app._display_font()
		f.draw_string(b.get_canvas_item(), kr.position + Vector2(4.5, 13.5), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UiArt.AMBER, .95 if b.button_pressed else .5)))
	b.toggled.connect(func(_on): b.queue_redraw())
	return b

## Troca a aba visivel (clique, teclas 1-3 ou testes). Lembra a ultima aba.
func show_inventory_tab(id: String) -> void:
	if not _inv_pages.has(id):
		return
	inventory_tab = id
	for k in _inv_pages:
		_inv_pages[k].visible = k == id
		_inv_tabs[k].set_pressed_no_signal(k == id)
		_inv_tabs[k].queue_redraw()
	_refresh_inventory()

## Mochila de couro com fivela e um cristal pendurado (icone do cabecalho).
func _draw_backpack(ci: CanvasItem, r: Rect2) -> void:
	var s := r.size
	ci.draw_colored_polygon(PackedVector2Array([Vector2(s.x * .18, s.y * .3), Vector2(s.x * .82, s.y * .3), Vector2(s.x * .9, s.y * .96), Vector2(s.x * .1, s.y * .96)]), Color("8a5e3b"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(s.x * .18, s.y * .3), Vector2(s.x * .82, s.y * .3), Vector2(s.x * .76, s.y * .56), Vector2(s.x * .24, s.y * .56)]), Color("a8774b"))
	ci.draw_arc(Vector2(s.x * .5, s.y * .3), s.x * .2, PI, TAU, 10, Color("5e3f27"), 3.0)
	ci.draw_rect(Rect2(Vector2(s.x * .44, s.y * .5), Vector2(s.x * .12, s.y * .12)), UiArt.AMBER)
	ci.draw_line(Vector2(s.x * .3, s.y * .62), Vector2(s.x * .3, s.y * .94), Color("5e3f27"), 2.0)
	ci.draw_line(Vector2(s.x * .7, s.y * .62), Vector2(s.x * .7, s.y * .94), Color("5e3f27"), 2.0)
	UiArt.crystal(ci, Rect2(Vector2(s.x * .74, s.y * .52), Vector2(s.x * .2, s.y * .34)))

# --- RECURSOS ---------------------------------------------------------------
func _resource_card(parent: Node, kind: StringName, title: String, color: Color, hint: String, detail: String) -> Label:
	var tile := _inv_tile(parent, color)
	tile.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	tile.add_child(row)
	row.add_child(UiArt.icon_control(kind, 64, color))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label = app._label(title, 16, CREAM)
	name_label.add_theme_font_override("font", app._display_font())
	col.add_child(name_label)
	var value := _big_value("0", color, 44)
	col.add_child(value)
	row.add_child(col)
	tile.add_child(UiArt.drawn(Vector2(0, 8), func(ci: CanvasItem, r: Rect2): ci.draw_line(Vector2(0, 4), Vector2(r.size.x, 4), Color(color, .25), 1.0)))
	var h = app._label(hint, 14, Color(CREAM, .85))
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile.add_child(h)
	var d = app._label(detail, 12, Color(CREAM, .55))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile.add_child(d)
	return value

func _build_resources_page(page: Control) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	page.add_child(col)
	col.add_child(_inv_section("MATERIAIS E PONTOS", "Golpeie árvores de copa amarelada e rochas com cristais. Pontos de Defesa vêm dos invasores derrotados."))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	inv_wood_text = _resource_card(row, &"wood", "MADEIRA", Color("e6c79a"), "+10 por árvore de copa amarelada.", "Fogueira e Armadilha usam Madeira.")
	inv_stone_text = _resource_card(row, &"stone", "PEDRA", Color("c9d3cc"), "+6 por rocha com cristais.", "Fogueira e Armadilha usam Pedra.")
	_res_points = _resource_card(row, &"defense", "PONTOS DE DEFESA", Color("aef0cf"), "Erguem e melhoram torres nos pontos de defesa.", "Torre: %d  ·  Melhorias: %d / %d" % [DefenseTower.LEVELS[0].cost, DefenseTower.LEVELS[1].cost, DefenseTower.LEVELS[2].cost])
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 14)
	col.add_child(strip)
	var terr := _inv_tile(strip, UiArt.JADE)
	terr.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 10)
	terr.add_child(trow)
	trow.add_child(UiArt.icon_control(&"territory", 30))
	var tl = app._label("TERRITÓRIOS RECUPERADOS", 14, CREAM)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(tl)
	_res_territories = _big_value("0/0", Color("9fe0c0"), 24)
	trow.add_child(_res_territories)
	var regrow := _inv_tile(strip, CREAM)
	regrow.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 10)
	regrow.add_child(rrow)
	rrow.add_child(UiArt.drawn(Vector2(30, 30), func(ci: CanvasItem, r: Rect2): UiArt.ammonite(ci, r.get_center(), 13.0, Color(UiArt.IVORY, .7), 2.0)))
	var rl = app._label("Árvores e rochas voltam no amanhecer seguinte.", 13, Color(CREAM, .75))
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rrow.add_child(rl)

# --- CONSTRUCOES --------------------------------------------------------------
func _build_build_page(page: Control) -> void:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	page.add_child(cols)
	var build := _inv_section("ESTRUTURAS", "Pagas com Madeira e Pedra. Escolha e posicione no mundo.")
	build.custom_minimum_size.x = 520
	cols.add_child(build)
	_inv_recipes_box = VBoxContainer.new()
	_inv_recipes_box.add_theme_constant_override("separation", 10)
	build.add_child(_inv_recipes_box)
	var defense := _inv_section("TORRES DE DEFESA", "Pagas com Pontos de Defesa, nos pontos de construção.")
	cols.add_child(defense)
	var tile_p := _inv_tile(defense, UiArt.JADE)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 12)
	prow.add_child(UiArt.icon_control(&"tower", 40))
	var pcol := VBoxContainer.new()
	pcol.add_theme_constant_override("separation", -3)
	pcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pcol.add_child(app._label("PONTOS DE DEFESA", 15, CREAM))
	pcol.add_child(app._label("Torre: %d  ·  Melhorias: %d / %d" % [DefenseTower.LEVELS[0].cost, DefenseTower.LEVELS[1].cost, DefenseTower.LEVELS[2].cost], 12, Color(CREAM, .6)))
	prow.add_child(pcol)
	_def_points = _big_value("0", Color("aef0cf"), 30)
	prow.add_child(_def_points)
	tile_p.add_child(prow)
	var tile_s := _inv_tile(defense, CREAM)
	_def_towers = app._label("", 14, CREAM)
	tile_s.add_child(_def_towers)
	_def_territories = app._label("", 14, CREAM)
	tile_s.add_child(_def_territories)
	_def_structures = app._label("", 13, CREAM)
	_def_structures.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile_s.add_child(_def_structures)
	var tip := HBoxContainer.new()
	tip.add_theme_constant_override("separation", 6)
	tip.add_child(UiArt.keycap("C", app._display_font(), 12))
	var tl = app._label("perto de um ponto: ergue ou melhora a torre (de dia).", 12, Color(CREAM, .6))
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip.add_child(tl)
	defense.add_child(tip)

# --- COMPANHEIROS ------------------------------------------------------------
func _build_companions_page(page: Control) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	page.add_child(col)
	_build_elixir_card(col)
	var head := _inv_section("DINOSSAUROS DOMESTICADOS", "")
	col.add_child(head)
	_companion_count = app._label("", 12, Color(CREAM, .62))
	head.add_child(_companion_count)
	head.move_child(_companion_count, 1)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_companion_grid = GridContainer.new()
	_companion_grid.columns = 3
	_companion_grid.add_theme_constant_override("h_separation", 14)
	_companion_grid.add_theme_constant_override("v_separation", 14)
	_companion_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_companion_grid)
	# Estado vazio: pegadas apagadas levando a um dinossauro em silhueta.
	_companion_empty = VBoxContainer.new()
	_companion_empty.name = "CompanionsEmpty"
	_companion_empty.add_theme_constant_override("separation", 8)
	_companion_empty.alignment = BoxContainer.ALIGNMENT_CENTER
	_companion_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_companion_empty)
	var art := UiArt.drawn(Vector2(420, 60), func(ci: CanvasItem, r: Rect2):
		UiArt.footprint_trail(ci, Vector2(10, r.size.y * .8), Vector2(r.size.x * .58, r.size.y * .62), 6, 26.0, Color(UiArt.IVORY, .22))
		UiArt.dino_silhouette(ci, Rect2(Vector2(r.size.x * .62, 6), Vector2(r.size.y * 1.3, r.size.y * .94)), Color(UiArt.JADE, .28), false, Color(UiArt.JADE_LIGHT, .6)))
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_companion_empty.add_child(art)
	var t = app._label("Nenhum dinossauro domesticado.", 20, CREAM)
	t.add_theme_font_override("font", app._display_font())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_companion_empty.add_child(t)
	var how = app._label("Enfraqueça um selvagem até ficar com 20 de vida ou menos (anel jade no chão)\ne segure E perto dele por 2 s. Ele passa a seguir você e lutar ao seu lado.", 13, Color(CREAM, .65))
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_companion_empty.add_child(how)

## Ficha de expedicao de um aliado (World 6.0): cabecalho de osso com o numero
## da ficha, especime em moldura de pedra com cantos de osso, e so dados reais
## — origem, vida (barra + numero), estado (SEGUINDO/FICAR), funcao atual,
## golpe e o uso do Elixir de Jade.
func _companion_card(dino: Node, index: int) -> Dictionary:
	var tile := _inv_tile(_companion_grid, UiArt.JADE)
	tile.get_parent().custom_minimum_size = Vector2(300, 0)
	tile.add_theme_constant_override("separation", 6)
	var band := HBoxContainer.new()
	band.add_theme_constant_override("separation", 6)
	tile.add_child(band)
	band.add_child(UiArt.drawn(Vector2(30, 12), func(ci: CanvasItem, r: Rect2): FossilUI.vertebrae(ci, Vector2(0, 6), Vector2(r.size.x, 6), 4, Color(FossilUI.BONE, .5))))
	band.add_child(app._label("FICHA DE EXPEDIÇÃO  ·  Nº %02d" % index, 10, Color(FossilUI.BONE, .7)))
	var band_fill := Control.new()
	band_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	band.add_child(band_fill)
	band.add_child(app._label("Golpe %d  ·  F alterna (de dia)" % int(WildDino.ALLY_ATTACK_DAMAGE), 10, Color(CREAM, .5)))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	tile.add_child(top)
	var medal := UiArt.drawn(Vector2(72, 58), func(ci: CanvasItem, r: Rect2):
		ci.draw_rect(r.grow(-2), Color(0.03, 0.05, 0.04, 0.9))
		ci.draw_rect(r.grow(-2), Color(FossilUI.BONE_SHADE, .55), false, 1.5)
		for c in [Vector2(4, 4), Vector2(r.size.x - 4, 4), Vector2(4, r.size.y - 4), Vector2(r.size.x - 4, r.size.y - 4)]:
			ci.draw_circle(c, 3.0, Color(FossilUI.BONE, .7))
		UiArt.dino_silhouette(ci, Rect2(r.position + Vector2(8, 9), Vector2(r.size.x - 16, r.size.y - 16)), UiArt.JADE, false, UiArt.INK))
	top.add_child(medal)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title = app._label("ALIADO %d" % index, 17, UiArt.AMBER_LIGHT)
	title.add_theme_font_override("font", app._display_font())
	names.add_child(title)
	names.add_child(app._label("Tipo: " + String(dino.get_meta("ally_origin", "Dinossauro do vale")), 12, Color(CREAM, .66)))
	top.add_child(names)
	var state = app._label("", 12, UiArt.INK)
	state.add_theme_font_override("font", app._display_font())
	var chip := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.set_corner_radius_all(3)
	cs.corner_detail = 2
	cs.content_margin_left = 8
	cs.content_margin_right = 8
	cs.content_margin_top = 2
	cs.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", cs)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(state)
	top.add_child(chip)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	tile.add_child(hp_row)
	hp_row.add_child(app._label("VIDA", 11, Color(FossilUI.BONE, .6)))
	var bar := _hud_bar(hp_row, UiArt.JADE)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = WildDino.MAX_HP
	var hp = app._label("", 13, CREAM)
	hp.add_theme_font_override("font", app._display_font())
	hp_row.add_child(hp)
	var info = app._label("", 12, Color(CREAM, .78))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.y = 0
	tile.add_child(info)
	var heal_button: Button = app._button(tile, "USAR ELIXIR · até 3 m", func(): world.get_node("JadeElixir").use_on(dino))
	return {"heal": heal_button, "tile": tile.get_parent(), "hp": hp, "bar": bar, "state": state, "chip": cs, "info": info}

func _refresh_companions() -> void:
	if not is_instance_valid(_companion_grid):
		return
	var allies := get_tree().get_nodes_in_group("domesticated").filter(func(d): return is_instance_valid(d) and d.get("is_domesticated") == true)
	for dino in _companion_cards.keys():
		if not is_instance_valid(dino) or not allies.has(dino):
			_companion_cards[dino].tile.queue_free()
			_companion_cards.erase(dino)
	for dino in allies:
		if not _companion_cards.has(dino):
			_companion_cards[dino] = _companion_card(dino, _companion_cards.size() + 1)
	_companion_empty.visible = allies.is_empty()
	_companion_grid.get_parent().visible = not allies.is_empty()
	_companion_count.text = "Nenhum aliado ainda." if allies.is_empty() else "%d aliado%s com você. Dados ao vivo (vida e ordem atual)." % [allies.size(), "" if allies.size() == 1 else "s"]
	for dino in _companion_cards:
		var card: Dictionary = _companion_cards[dino]
		var elixir = world.get_node("JadeElixir")
		card.heal.disabled = elixir.stored == 0 or not elixir.valid_target(dino)
		var hp: float = dino.hp
		card.hp.text = "%d/%d" % [maxi(ceili(hp), 0), int(WildDino.MAX_HP)]
		card.bar.value = hp
		var staying: bool = dino.ally_state == WildDino.AllyState.STAYING
		card.state.text = "FICAR" if staying else "SEGUINDO"
		card.chip.bg_color = UiArt.AMBER if staying else UiArt.JADE
		card.info.text = ("Guarda o posto: ataca inimigos a até %d m de onde ficou." % int(WildDino.DEFENSE_RADIUS)) if staying \
			else ("Acompanha você e ataca quem te atacar a até %d m." % int(WildDino.ALLY_GUARD_RADIUS))

## Clique no veu escuro (fora do cartao) fecha o inventario.
func _on_veil_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and inventory_panel.visible \
			and not _inv_card.get_global_rect().has_point(ev.global_position):
		toggle_inventory()

## Linhas extras do inventario (defesa, territorios, estruturas, aliados).
func _refresh_defense_info() -> void:
	if not is_instance_valid(_def_points) or not is_instance_valid(world):
		return
	var points := str(world.get_node("DefenseEconomy").points)
	_def_points.text = points
	_res_points.text = points
	var built := 0
	var total := 0
	for slot in world.get_node("DefenseSlots").get_children():
		total += 1
		if not slot.is_empty():
			built += 1
	_def_towers.text = "Torres erguidas: %d de %d pontos" % [built, total]
	var terr = world.get_node_or_null("TerritoryManager")
	if terr != null:
		_def_territories.text = "Territórios controlados: %d / %d" % [terr.controlled_count(), terr.total_count()]
		_res_territories.text = "%d/%d" % [terr.controlled_count(), terr.total_count()]
	var placer = _placer()
	var parts := []
	for id in BuildRecipes.order():
		var r = BuildRecipes.get_recipe(id)
		parts.append("%s %d/%d" % ["Fogueira" if id == BuildRecipes.CAMPFIRE else "Armadilhas", placer.count(id), r.limit])
	_def_structures.text = "Construídas: " + "  ·  ".join(parts)
	_refresh_companions()
	if is_instance_valid(_world_clock):
		_world_clock.text = "O MUNDO CONTINUA  ·  %s %s" % ["NOITE" if DayNightManager.is_night() else "DIA", DayNightManager.clock_text()]
		var icon := _world_clock.get_parent().get_node_or_null("WorldRunningIcon")
		if icon != null:
			icon.queue_redraw()

# Gameplay 5.0: com o cursor oculto, um clique sobre um painel da HUD seria
# engolido sem o jogador ver o cursor (ou apertaria CONSTRUIR as cegas). Os
# paineis da partida so capturam o mouse com o cursor visivel.
var _gameplay_click_targets: Array[Control] = []
var _pointer_capture := true

func set_pointer_capture(on: bool) -> void:
	if on == _pointer_capture:
		return
	_pointer_capture = on
	for c in _gameplay_click_targets:
		if is_instance_valid(c):
			c.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE

var _elixir_status: Label
var _elixir_craft: Button
var _elixir_hint: Label
var _elixir_ring: MeshInstance3D
var _elixir_tick := 0.0

func _build_elixir_card(parent: Node) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_inv_tile(parent, UiArt.JADE).add_child(row) # World 6.0: nicho de pedra, como os outros cartoes
	# Frasco de especime: o liquido mostra o estoque real (cheio = 1 guardado).
	var jar := UiArt.drawn(Vector2(44, 64), func(ci: CanvasItem, r: Rect2):
		var elixir = world.get_node_or_null("JadeElixir")
		FossilUI.jar(ci, r, 1.0 if elixir != null and elixir.stored > 0 else 0.18))
	jar.name = "ElixirJar"
	row.add_child(jar)
	world.get_node("JadeElixir").changed.connect(jar.queue_redraw)
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_col)
	text_col.add_child(app._label("ELIXIR DE JADE · +40 HP · 40 madeiras + 24 pedras", 16, UiArt.JADE_LIGHT))
	var description = app._label("Uma mistura rara de minerais e essência do Refúgio que recupera a vitalidade de um companheiro.", 12, CREAM)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_col.add_child(description)
	_elixir_status = app._label("", 12, CREAM)
	_elixir_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_col.add_child(_elixir_status)
	_elixir_craft = app._button(row, "FABRICAR", func(): world.get_node("JadeElixir").craft(); _refresh_inventory())
	_elixir_craft.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	world.get_node("JadeElixir").changed.connect(_refresh_inventory)
	_elixir_hint = app._label("", 17, UiArt.JADE_LIGHT)
	_elixir_hint.add_theme_constant_override("outline_size", 7)
	_elixir_hint.add_theme_color_override("font_outline_color", Color(0.04, 0.09, 0.07, 0.92))
	add_child(_elixir_hint)
	_elixir_hint.name = "ElixirHint"
	# Ancorada embaixo, no centro, acima das linhas de objetivo/dica da HUD.
	_elixir_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_elixir_hint.offset_left = -240
	_elixir_hint.offset_right = 240
	_elixir_hint.offset_top = -150
	_elixir_hint.offset_bottom = -124
	_elixir_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_elixir_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_elixir()

func _refresh_elixir() -> void:
	if not is_instance_valid(_elixir_status): return
	var elixir = world.get_node("JadeElixir")
	var stock = world.get_node("ResourceStock")
	var reason: String = elixir.craft_reason()
	_elixir_status.text = "Guardado: %d/1 · Recursos: %d madeira / %d pedra\n%s" % [elixir.stored, stock.get_amount(&"wood"), stock.get_amount(&"stone"), "Pronto para fabricar · intervalo de 2 amanheceres" if reason == "" else reason]
	_elixir_craft.disabled = reason != ""
	_elixir_craft.tooltip_text = reason

func _update_elixir_preview() -> void:
	if not is_instance_valid(world) or not is_instance_valid(_elixir_hint): return
	var elixir = world.get_node("JadeElixir")
	var target: Node3D = elixir.nearest_target() if elixir.stored == 1 else null
	var active: bool = is_instance_valid(target) and DayNightManager.can_play() and not inventory_panel.visible and not world.get_node("Player").is_dead
	_elixir_hint.visible = active
	if is_instance_valid(_elixir_ring): _elixir_ring.visible = active
	if not active: return
	_elixir_hint.text = "G · ELIXIR DE JADE · curar aliado (+%d HP)" % mini(int(elixir.HEAL), ceili(target.MAX_HP - target.hp))
	if not is_instance_valid(_elixir_ring):
		_elixir_ring = MeshInstance3D.new()
		_elixir_ring.mesh = CombatFX.ring_mesh()
		_elixir_ring.material_override = CombatFX.fx_material(UiArt.JADE_LIGHT, 0.65)
		_elixir_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(_elixir_ring)
	_elixir_ring.global_position = target.global_position + Vector3(0, 0.04, 0)