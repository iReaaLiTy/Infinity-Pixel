extends Node

# Spec: docs/specs/022-tutorial-jogavel.md — Tutorial jogavel (PROVISORIO)
#
# Diretor do tutorial. Existe SO no mundo criado por main.start_tutorial(): a
# partida normal nunca tem este no. Usa o jogo real (mesmo mapa, Player, IA,
# coleta, construcao, torres, onda) e so observa acoes reais para avancar.
# Mudancas desta instancia (e de mais nenhuma):
# - relogio segurado (DayNightManager.clock_hold) ate a etapa da noite;
#   reset_session() zera isso em qualquer nova partida/menu;
# - primeira noite com 2 inimigos (WaveManager desta instancia);
# - sem o guardiao da Regiao Rochosa (as pedras ficam la).
# Nada aqui muda dano, vida, custos, recompensas ou regras.

signal step_changed(index: int)
signal completed

const CombatFX := preload("res://scenes/visuals/combat_fx.gd")
const Recipes := preload("res://scenes/world/build_recipes.gd")
const WILD_DINO := preload("res://scenes/enemies/wild_dino.tscn")
const WOOD_GOAL := 20 # custo da Fogueira (build_recipes)
const STONE_GOAL := 12
const WALK_POINT := Vector3(0, 0, -1.5) # estrada, ao lado do posto central
const NIGHT_ENEMIES := 2
## Balanceamento do tutorial (so nesta instancia): os dinossauros hostis do
## tutorial causam metade do dano. Ensinar, nao punir.
const TUTORIAL_DAMAGE_SCALE := 0.5
const JADE := Color("69be9b")
const GOLD := Color("e7ae58")
const CREAM := Color("f2e8ce")
const EMBER := Color("e0795a")

enum Step { MOVE, WALK, ATTACK, WEAKEN, TAME, WOOD, STONE, INVENTORY, CAMPFIRE, TOWER, ALLY, NIGHT, DONE }
## [titulo curto (objetivo da HUD), instrucao, tecla]
const TEXT := {
	Step.MOVE: ["Ande pelo Refúgio", "Use W A S D para andar. A câmera acompanha você.", "W A S D"],
	Step.WALK: ["Vá até o sinal jade", "Caminhe até a coluna de luz jade na estrada.", "W A S D"],
	Step.ATTACK: ["Ataque", "Clique com o botão esquerdo: o herói vira para onde você clicou e golpeia. Clique EM CIMA do alvo; o golpe alcança cerca de 2 m.", "CLIQUE"],
	Step.WEAKEN: ["Enfraqueça o selvagem", "Golpeie o dinossauro marcado (4 golpes). Quando aparecer um ARCO VERMELHO no chão à frente dele, recue um passo: ele vai morder. Pare quando surgir o anel jade sob ele.", "CLIQUE · RECUE"],
	Step.TAME: ["Domestique", "Fique perto dele e SEGURE E por 2 segundos. Soltar ou se afastar cancela.", "SEGURE E"],
	Step.WOOD: ["Colete Madeira", "Golpeie árvores de copa amarelada (coletáveis) até juntar 20 Madeira.", "CLIQUE"],
	Step.STONE: ["Colete Pedra", "Golpeie as rochas com cristais de minério até juntar 12 Pedra.", "CLIQUE"],
	Step.INVENTORY: ["Abra o inventário", "Aperte I para ver seus recursos e o que dá para construir.", "I"],
	Step.CAMPFIRE: ["Construa a Fogueira", "Escolha Fogueira de Cura (B ou CONSTRUIR no inventário) e posicione dentro da área de construção, ao lado do Refúgio.", "B · CLIQUE"],
	Step.TOWER: ["Prepare uma torre", "Vá até um ponto de defesa (anel jade tracejado) e aperte C para erguer uma torre (30 Pontos).", "C"],
	Step.ALLY: ["Posicione o aliado", "Leve o aliado até onde quer que ele defenda e aperte F perto dele: ele passa a FICAR ali.", "F"],
	Step.NIGHT: ["Defenda o Refúgio", "A noite chegou: 2 invasores vêm pelas entradas. Proteja o cristal com a torre, o aliado e seus golpes.", "CLIQUE"],
	Step.DONE: ["Tutorial concluído", "Você aprendeu o ciclo do Vale de Jade.", ""],
}

var app: Node
var world: Node3D
var player # CharacterBody3D (player.gd)
var stock: Node
var placer: Node
var slots: Node
var step: int = Step.MOVE
var target # WildDino do passo (enfraquecer/domesticar)
var note := "" # aviso extra no painel (ex.: outro selvagem apareceu)
var _start_pos := Vector3.ZERO
var _was_attacking := true
var _resume_after_tame: int = Step.WOOD
var _campfire_built := false
var _beacon: Node3D
var _beacon_mat: StandardMaterial3D
var _card: PanelContainer
var _counter: Label
var _title: Label
var _text: Label
var _progress: Label
var _note: Label
var _keys: Label
var _time := 0.0
# Feedback de erro (combate): golpe no vazio, longe demais, mordida chegando.
var _swings := 0
var _miss_check := 0
var _miss_hp := 0.0
var _note_left := 0.0

func setup(main: Node, game_world: Node3D) -> void:
	app = main
	world = game_world
	player = world.get_node("Player")
	stock = world.get_node("ResourceStock")
	placer = world.get_node("BuildPlacer")
	slots = world.get_node("DefenseSlots")
	DayNightManager.clock_hold = true
	world.get_node("WaveManager").base_enemy_count = NIGHT_ENEMIES
	placer.structure_built.connect(_on_structure_built)
	player.attack_out_of_range.connect(func(_t): _say("Longe demais: chegue mais perto (o golpe alcança cerca de 2 m)."))
	_swings = player.attack_count
	DayNightManager.day_started.connect(_on_dawn)
	_build_card()
	_build_beacon()
	# Os encontros diurnos nascem no quadro seguinte (EncounterSpawner).
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var spawner = world.get_node("EncounterSpawner")
	if spawner.encounters.size() > 1 and is_instance_valid(spawner.encounters[1]):
		world.get_node("TerritoryManager").guardians.erase(&"east")
		spawner.encounters[1].queue_free() # so nesta instancia: pedras sem guardiao
	target = spawner.encounters[0] if not spawner.encounters.is_empty() else null
	if target != null:
		target.damage_scale = TUTORIAL_DAMAGE_SCALE
	_enter(Step.MOVE)

# --- etapas ----------------------------------------------------------------------

func _enter(s: int) -> void:
	step = s
	match s:
		Step.MOVE:
			_start_pos = player.global_position
		Step.ATTACK:
			_was_attacking = true # so conta um golpe NOVO, dado depois de entrar aqui
		Step.NIGHT:
			DayNightManager.clock_hold = false
			DayNightManager.start_night() # onda desta instancia: 2 inimigos
	var hud = app.hud
	if is_instance_valid(hud):
		hud.objective_override = "TUTORIAL  ·  " + TEXT[s][0]
	_refresh_card()
	step_changed.emit(s)
	print("[TUTORIAL] passo %d/%d: %s" % [s + 1, Step.DONE + 1, TEXT[s][0]])
	if s == Step.DONE:
		_beacon.hide()
		completed.emit()
		if app.has_method("tutorial_finished"):
			app.tutorial_finished()

func _advance() -> void:
	note = ""
	if step == Step.TAME:
		_enter(_resume_after_tame)
		_resume_after_tame = Step.WOOD
	else:
		_enter(step + 1)

func _process(delta: float) -> void:
	if step == Step.DONE or not is_instance_valid(player):
		return
	_time += delta
	match step:
		Step.MOVE:
			if _flat(player.global_position, _start_pos) > 2.5:
				_advance()
		Step.WALK:
			if _flat(player.global_position, WALK_POINT) < 1.8:
				_advance()
		Step.ATTACK:
			var attacking: bool = not player.attack_cooldown.is_stopped()
			if attacking and not _was_attacking:
				_advance()
			_was_attacking = attacking
		Step.WEAKEN:
			if not _alive(target):
				_new_target("O selvagem caiu. Outro apareceu: enfraqueça sem derrotar.")
			elif target.is_domesticated:
				_advance() # domesticou direto: o passo seguinte ja esta cumprido
			elif target.can_be_domesticated():
				_advance()
		Step.TAME:
			if not _alive(target):
				_new_target("O selvagem caiu. Outro apareceu: enfraqueça e domestique.")
				_enter(Step.WEAKEN)
			elif target.is_domesticated:
				_advance()
		Step.WOOD:
			if stock.get_amount(&"wood") >= WOOD_GOAL or _campfire_built:
				_advance()
		Step.STONE:
			if stock.get_amount(&"stone") >= STONE_GOAL or _campfire_built:
				_advance()
		Step.INVENTORY:
			var inv = app.inventory_panel
			if is_instance_valid(inv) and inv.visible:
				_advance()
		Step.CAMPFIRE:
			if _campfire_built:
				_advance()
		Step.TOWER:
			for slot in slots.get_children():
				if not slot.is_empty():
					_advance()
					break
		Step.ALLY:
			var allies := get_tree().get_nodes_in_group("domesticated")
			if allies.is_empty():
				# Sem travar: o aliado caiu. Novo selvagem, e depois volta para ca.
				_resume_after_tame = Step.ALLY
				_new_target("Seu aliado caiu. Domestique outro selvagem.")
				_enter(Step.WEAKEN)
			else:
				for ally in allies:
					if ally.ally_state == 1: # AllyState.STAYING
						_advance()
						break
	# Invasores da noite do tutorial tambem batem com metade da forca.
	for foe in get_tree().get_nodes_in_group("wave_enemy"):
		if foe.get("damage_scale") == 1.0:
			foe.damage_scale = TUTORIAL_DAMAGE_SCALE
	_combat_feedback(delta)
	_update_beacon()
	_refresh_progress()

func _on_structure_built(id: StringName, _node: Node3D) -> void:
	if id == Recipes.CAMPFIRE:
		_campfire_built = true

func _on_dawn() -> void:
	if step == Step.NIGHT:
		_advance()

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

static func _alive(dino) -> bool:
	return is_instance_valid(dino) and dino.is_inside_tree() and dino.hp > 0.0

## Novo selvagem domesticavel perto do jogador (so no tutorial; mesma cena e
## mesmos valores da partida normal).
func _new_target(message: String) -> void:
	var dino = WILD_DINO.instantiate()
	dino.territorial = true # fica onde nasceu, como os encontros diurnos
	dino.name = "TutorialDino"
	var away := Vector3(5.0, 0.0, 3.0)
	var spot: Vector3 = player.global_position + away
	spot.x = clampf(spot.x, -20.0, 20.0)
	spot.z = clampf(spot.z, -18.0, 24.0)
	dino.position = Vector3(spot.x, 0.5, spot.z)
	world.add_child(dino, true)
	dino.damage_scale = TUTORIAL_DAMAGE_SCALE
	target = dino
	note = message

# --- sinal no mundo -----------------------------------------------------------------

func _build_beacon() -> void:
	_beacon = Node3D.new()
	_beacon.name = "TutorialBeacon"
	world.add_child(_beacon)
	_beacon_mat = CombatFX.fx_material(JADE, 0.28)
	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.35
	cyl.height = 5.0
	cyl.radial_segments = 8
	cyl.rings = 1
	shaft.mesh = cyl
	shaft.material_override = _beacon_mat
	shaft.position.y = 2.5
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.add_child(shaft)
	var ring := MeshInstance3D.new()
	ring.mesh = CombatFX.ring_mesh()
	ring.material_override = CombatFX.fx_material(JADE, 0.75)
	ring.position.y = 0.07
	ring.scale = Vector3.ONE * 1.3
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.add_child(ring)

func _beacon_target() -> Variant:
	match step:
		Step.WALK:
			return WALK_POINT
		Step.WEAKEN, Step.TAME:
			return target.global_position if _alive(target) else null
		Step.WOOD, Step.STONE:
			return _nearest_collectable("wood" if step == Step.WOOD else "stone")
		Step.CAMPFIRE:
			return Vector3(7, 0, -15) # centro da area de construcao
		Step.TOWER:
			var best = null
			var best_d := INF
			for slot in slots.get_children():
				var d := _flat(slot.global_position, player.global_position)
				if slot.is_empty() and d < best_d:
					best_d = d
					best = slot.global_position
			return best
		Step.ALLY:
			var allies := get_tree().get_nodes_in_group("domesticated")
			return allies[0].global_position if not allies.is_empty() else null
	return null

func _nearest_collectable(kind: String) -> Variant:
	var best = null
	var best_d := INF
	for item in get_tree().get_nodes_in_group("collectable"):
		if item.kind != kind or item.depleted:
			continue
		var d := _flat(item.global_position, player.global_position)
		if d < best_d:
			best_d = d
			best = item.global_position
	return best

func _update_beacon() -> void:
	var at = _beacon_target()
	_beacon.visible = at != null
	if at != null:
		_beacon.global_position = Vector3(at.x, 0.0, at.z)
		_beacon_mat.albedo_color.a = 0.2 + 0.1 * sin(_time * 4.0)

# --- painel -----------------------------------------------------------------------

func _build_card() -> void:
	var hud = app.hud
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size.x = 300
	_counter = app._label("", 12, Color(CREAM, .75))
	box.add_child(_counter)
	_title = app._label("", 18, GOLD)
	_title.add_theme_font_override("font", app._display_font())
	box.add_child(_title)
	_text = app._label("", 14, CREAM)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 300
	box.add_child(_text)
	_keys = app._label("", 14, JADE)
	_keys.add_theme_font_override("font", app._display_font())
	box.add_child(_keys)
	_progress = app._label("", 14, Color("e6c79a"))
	box.add_child(_progress)
	_note = app._label("", 13, EMBER)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size.x = 300
	box.add_child(_note)
	box.add_child(app._label("ESC: pausar · Reiniciar · Sair do tutorial", 11, Color(CREAM, .55)))
	_card = hud._hud_panel(hud, box)
	_card.name = "TutorialCard"
	_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_card.position = Vector2(16, 108)
	app._ignore_mouse(_card) # o painel nunca bloqueia cliques no mundo

func _refresh_card() -> void:
	if not is_instance_valid(_card):
		return
	_counter.text = "TUTORIAL  ·  PASSO %d DE %d" % [mini(step + 1, Step.DONE), Step.DONE]
	_title.text = TEXT[step][0]
	_text.text = TEXT[step][1]
	_keys.text = "[ %s ]" % TEXT[step][2] if TEXT[step][2] != "" else ""
	_keys.visible = _keys.text != ""
	_refresh_progress()

func _refresh_progress() -> void:
	if not is_instance_valid(_card):
		return
	var text := ""
	match step:
		Step.WEAKEN, Step.TAME:
			if _alive(target):
				text = "Vida do selvagem: %d / 80" % int(target.hp)
		Step.WOOD:
			text = "Madeira: %d / %d" % [mini(stock.get_amount(&"wood"), WOOD_GOAL), WOOD_GOAL]
		Step.STONE:
			text = "Pedra: %d / %d" % [mini(stock.get_amount(&"stone"), STONE_GOAL), STONE_GOAL]
		Step.NIGHT:
			var wave: Dictionary = world.get_node("WaveManager").snapshot()
			text = "Invasores: %d neutralizados de %d" % [wave.resolved, wave.total]
	_progress.text = text
	_progress.visible = text != ""
	_note.text = note
	_note.visible = note != ""

## Mensagem curta no painel por alguns segundos (nao muda o passo).
func _say(message: String, seconds := 2.5) -> void:
	note = message
	_note_left = seconds

## Ensina o combate com o que o jogador acabou de fazer: golpe no vazio perto
## do alvo, alvo preparando a mordida (arco vermelho). So texto.
func _combat_feedback(delta: float) -> void:
	if _note_left > 0.0:
		_note_left -= delta
		if _note_left <= 0.0:
			note = ""
	if step != Step.WEAKEN and step != Step.TAME:
		_swings = player.attack_count
		return
	if not _alive(target):
		return
	if player.attack_count != _swings:
		_swings = player.attack_count
		_miss_hp = target.hp
		_miss_check = 3
	elif _miss_check > 0:
		_miss_check -= 1
		if _miss_check == 0 and target.hp == _miss_hp and note == "":
			_say("Golpe no vazio: clique EM CIMA do dinossauro, a até ~2 m dele.")
	if target.get("_windup_left") != null and target._windup_left > 0.0 and _flat(target.global_position, player.global_position) < 3.0:
		_say("Arco vermelho: ele vai morder — recue um passo!", 1.2)
