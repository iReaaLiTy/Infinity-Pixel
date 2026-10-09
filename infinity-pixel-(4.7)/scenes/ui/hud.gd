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
var _cycle_fill: StyleBoxFlat
var _cycle_night := false
var _focus_ring: MeshInstance3D # destaque do coletavel ao alcance
var objective_override := "" # Spec 022: passo do tutorial (vazio = objetivo normal)
var _range_hint_left := 0.0 # aviso "fora de alcance" apos um clique longe do alvo
const NIGHT_VIOLET := Color("9aa6f0")
const CombatFX := preload("res://scenes/visuals/combat_fx.gd")

func build(main: Node, game_world: Node3D) -> void:
	app = main
	world = game_world
	name = "Hud"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Spec 017B/020: vida com icone (jogador / cristal do Refugio) e barras mais
	# legiveis; os textos continuam os mesmos.
	var health = VBoxContainer.new()
	health.add_theme_constant_override("separation", 3)
	health.custom_minimum_size.x = 220
	var player_row = HBoxContainer.new()
	player_row.add_theme_constant_override("separation", 7)
	player_row.add_child(_hud_icon(&"player", 16))
	player_text = app._label("JOGADOR  100 / 100", 13, CREAM)
	player_row.add_child(player_text)
	health.add_child(player_row)
	player_bar = _hud_bar(health, EMBER)
	var gap = Control.new()
	gap.custom_minimum_size.y = 4
	health.add_child(gap)
	var base_row = HBoxContainer.new()
	base_row.add_theme_constant_override("separation", 7)
	base_row.add_child(_hud_icon(&"refuge", 16))
	base_text = app._label("REFÚGIO  100 / 100", 13, CREAM)
	base_row.add_child(base_text)
	health.add_child(base_row)
	base_bar = _hud_bar(health, JADE)
	var left = _hud_panel(self, health)
	left.name = "HealthPanel"
	left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	left.position = Vector2(16, 14)
	# Centro: "DIA 1 • 08:58" / "PREPARAÇÃO · Noites: 0" (+ onda a noite).
	var phase = VBoxContainer.new()
	phase.add_theme_constant_override("separation", 0)
	var phase_row = HBoxContainer.new()
	phase_row.alignment = BoxContainer.ALIGNMENT_CENTER
	phase_row.add_theme_constant_override("separation", 8)
	phase.add_child(phase_row)
	_cycle_icon = _hud_icon(&"cycle", 18)
	phase_row.add_child(_cycle_icon)
	phase_text = app._label("DIA 1", 17, GOLD)
	phase_text.add_theme_font_override("font", app._display_font())
	phase_row.add_child(phase_text)
	phase_row.add_child(app._label("•", 15, GOLD))
	clock_text = app._label("08:00", 17, CREAM)
	clock_text.add_theme_font_override("font", app._display_font())
	phase_row.add_child(clock_text)
	wave_text = app._label("PREPARAÇÃO  ·  Noites: 0", 12, CREAM)
	wave_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase.add_child(wave_text)
	onda_text = app._label("", 12, Color("f0c9a0"))
	onda_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	onda_text.hide()
	phase.add_child(onda_text)
	countdown_text = app._label("", 14, EMBER)
	countdown_text.add_theme_font_override("font", app._display_font())
	countdown_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_text.hide()
	phase.add_child(countdown_text)
	# Spec 017B/020: quanto do dia (ou da noite) ja passou — ambar de dia,
	# violeta a noite. So leitura do DayNightManager.
	var cycle_gap = Control.new()
	cycle_gap.custom_minimum_size.y = 4
	phase.add_child(cycle_gap)
	_cycle_bar = _hud_bar(phase, GOLD)
	_cycle_bar.custom_minimum_size = Vector2(190, 4)
	_cycle_bar.max_value = 1.0
	_cycle_fill = _cycle_bar.get_theme_stylebox("fill") as StyleBoxFlat
	var center = _hud_panel(self, phase)
	center.name = "PhasePanel"
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.offset_top = 14
	center.offset_bottom = 14
	# Direita: Pontos de Defesa, Madeira e Pedra, icone + numero + legenda curta.
	_build_points_panel(self)
	# Spec 008 (RF-UI-002): sem tutorial permanente. So objetivo atual + dica de
	# contexto (alvo/aliado proximo) + barra de canalizacao, num painel compacto
	# centralizado que cresce conforme o texto.
	var bottom = VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	var panel = app._panel(self, bottom)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_top = -16
	panel.offset_bottom = -16
	objective = app._label("", 17, GOLD)
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(objective)
	hint = app._label("", 15)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(hint)
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

# Painel compacto (margens menores que _panel) para a HUD de jogo.
# Spec 017B/020: vidro verde-escuro com filete jade no topo e sombra leve,
# o mesmo estilo em todos os paineis da partida.
func _hud_panel(parent: Node, box: Control) -> PanelContainer:
	var p = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(.03, .095, .09, .86)
	style.border_color = Color("3d6a57")
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, .22)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	p.add_child(box)
	return p

func _hud_bar(parent: Node, color: Color) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.custom_minimum_size.y = 8
	bar.show_percentage = false
	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	var back = StyleBoxFlat.new()
	back.bg_color = Color("12292a")
	back.border_color = Color("24413b")
	back.set_border_width_all(1)
	back.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	parent.add_child(bar)
	return bar

## Icones vetoriais da HUD: jogador, cristal do Refugio, sol/lua do ciclo.
func _hud_icon(kind: StringName, size: float) -> Control:
	if kind == &"refuge":
		return app._crystal(size)
	var c = Control.new()
	c.custom_minimum_size = Vector2(size, size)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.draw.connect(func():
		var s: Vector2 = c.size
		if kind == &"player": # cabeca + ombros, na cor da barra de vida
			c.draw_circle(Vector2(s.x * .5, s.y * .3), s.y * .22, EMBER)
			c.draw_colored_polygon(PackedVector2Array([Vector2(s.x * .14, s.y), Vector2(s.x * .22, s.y * .62), Vector2(s.x * .78, s.y * .62), Vector2(s.x * .86, s.y)]), EMBER)
		elif _cycle_night: # lua crescente
			c.draw_circle(s * .5, s.y * .42, NIGHT_VIOLET)
			c.draw_circle(s * .5 + Vector2(s.x * .2, -s.y * .12), s.y * .36, Color(.03, .095, .09))
		else: # sol com raios
			for i in 8:
				var a := TAU * i / 8.0
				c.draw_line(s * .5 + Vector2(cos(a), sin(a)) * s.y * .3, s * .5 + Vector2(cos(a), sin(a)) * s.y * .48, GOLD, 2.0)
			c.draw_circle(s * .5, s.y * .24, GOLD))
	return c

# Icones vetoriais pequenos: tora (madeira) e bloco (pedra).
func _resource_icon(kind: StringName, size: float) -> Control:
	if kind == &"defense":
		return app._crystal(size)
	if kind == &"territory": # Spec 015: marco (pedestal + cristal)
		var m = Control.new()
		m.custom_minimum_size = Vector2(size, size)
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		m.draw.connect(func():
			var s = m.size
			m.draw_rect(Rect2(s.x * .2, s.y * .74, s.x * .6, s.y * .18), Color("8d9a8f"))
			m.draw_rect(Rect2(s.x * .36, s.y * .5, s.x * .28, s.y * .26), Color("7c8980"))
			m.draw_colored_polygon(PackedVector2Array([Vector2(s.x * .5, s.y * .04), Vector2(s.x * .7, s.y * .27), Vector2(s.x * .5, s.y * .5), Vector2(s.x * .3, s.y * .27)]), Color("7fe0b8")))
		return m
	var c = Control.new()
	c.custom_minimum_size = Vector2(size, size)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.draw.connect(func():
		var s = c.size
		if kind == &"wood":
			c.draw_rect(Rect2(s.x * .08, s.y * .3, s.x * .72, s.y * .42), Color("8a6440"))
			c.draw_circle(Vector2(s.x * .78, s.y * .51), s.y * .21, Color("d9b98a"))
			c.draw_arc(Vector2(s.x * .78, s.y * .51), s.y * .11, 0, TAU, 10, Color("8a6440"), 1.5)
		else:
			var pts = PackedVector2Array()
			for i in 6:
				var a = TAU * i / 6.0 + .3
				pts.append(s * .5 + Vector2(cos(a) * s.x * .42, sin(a) * s.y * .36))
			c.draw_colored_polygon(pts, Color("9aa79d"))
			c.draw_colored_polygon(PackedVector2Array([s * .5, s * .5 + Vector2(s.x * .3, -s.y * .2), s * .5 + Vector2(s.x * .1, s.y * .25)]), Color("6e8aa3")))
	return c

func _resource_item(row: Node, kind: StringName, caption: String, color: Color) -> Label:
	var item = HBoxContainer.new()
	item.add_theme_constant_override("separation", 5)
	item.add_child(_resource_icon(kind, 20))
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", -5)
	var value = app._label("0", 16, color)
	value.add_theme_font_override("font", app._display_font())
	col.add_child(value)
	col.add_child(app._label(caption, 9, Color(CREAM, .75)))
	item.add_child(col)
	row.add_child(item)
	_resource_items[kind] = item
	return value

func _build_points_panel(parent: Node) -> void:
	var row = HBoxContainer.new()
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
	var esc = app._label("ESC  pausa", 11, Color(CREAM, .85))
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
func _build_defense_panel() -> void:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	build_title = app._label("TORRE DE DEFESA", 18, GOLD)
	build_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(build_title)
	build_info = app._label("", 15)
	build_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(build_info)
	build_button = app._menu_button(box, "CONSTRUIR", 18, Color("e9a23b"), Color("8a4f19"), 6, 12, 22, 4, func():
		if is_instance_valid(_build_slot):
			world.get_node("DefenseSlots").interact(_build_slot))
	build_button.focus_mode = Control.FOCUS_NONE # C e clique; nao rouba teclas
	build_note = app._label("", 14, EMBER)
	build_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(build_note)
	build_panel = app._panel(self, box)
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

func _recipe_list(box: VBoxContainer, rows: Dictionary) -> void:
	for id in BuildRecipes.order():
		var r = BuildRecipes.get_recipe(id)
		var entry = VBoxContainer.new()
		entry.add_theme_constant_override("separation", 2)
		entry.add_child(app._label(r.name, 15, GOLD))
		var costs: Array = _cost_line(entry, r.wood, r.stone)
		var line = HBoxContainer.new()
		var status = app._label("", 12, EMBER)
		status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(status)
		var button = app._menu_button(line, "CONSTRUIR", 14, Color("e9a23b"), Color("8a4f19"), 5, 9, 14, 2, func(): _start_placement(id))
		button.focus_mode = Control.FOCUS_NONE
		entry.add_child(line)
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
	# INVENTARIO (I): recursos + receitas. Nao pausa o mundo.
	var inv = VBoxContainer.new()
	for kind in [&"wood", &"stone"]:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_resource_icon(kind, 20))
		var name_label = app._label("MADEIRA" if kind == &"wood" else "PEDRA", 15)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var value = app._label("0", 17, Color("e6c79a") if kind == &"wood" else Color("c9d3cc"))
		value.add_theme_font_override("font", app._display_font())
		row.add_child(value)
		inv.add_child(row)
		if kind == &"wood": inv_wood_text = value
		else: inv_stone_text = value
	inv.add_child(app._label("CONSTRUÇÕES", 12, JADE))
	var inv_rows = {}
	_recipe_list(inv, inv_rows)
	inv.add_child(app._label("I fecha  ·  B constrói direto", 11, Color(CREAM, .6)))
	inventory_panel = _side_panel("INVENTÁRIO", inv)
	inventory_panel.name = "InventoryPanel"
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
	if not is_instance_valid(inv_wood_text) or not is_instance_valid(world):
		return
	var stock = world.get_node("ResourceStock")
	inv_wood_text.text = str(stock.get_amount(&"wood"))
	inv_stone_text.text = str(stock.get_amount(&"stone"))
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
	player_bar.max_value = maximum
	player_bar.value = current
	player_text.text = "JOGADOR  %d / %d" % [ceili(current), int(maximum)]
	if hurt: # tinta breve na barra e no texto; nada na camera
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

func _process(_delta: float) -> void:
	if not is_instance_valid(world) or not is_instance_valid(self):
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
	channel_bar.visible = channel.get_progress() > 0.0 or healing > 0.0 or claim > 0.0
	if healing > 0.0:
		channel_bar.value = healing
	if claim > 0.0:
		channel_bar.value = claim
	_update_build_ui()
	_update_cycle()

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
