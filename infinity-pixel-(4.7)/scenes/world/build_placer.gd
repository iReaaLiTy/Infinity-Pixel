extends Node3D

# Spec: docs/specs/013d-inventario-construcao-cura.md — RF-CON-002 / 003 (PROVISORIO)
#
# Fundacao do posicionamento: receita -> fantasma -> validacao -> posicionamento.
# O fantasma segue o cursor no chao; R gira 90 graus; clique esquerdo confirma;
# clique direito (ou ESC, via HUD) cancela. Enquanto posiciona, o clique NAO
# vira ataque (o placer consome o evento e o Player tambem checa is_placing()).
# Paga com MADEIRA/PEDRA de forma atomica (ResourceStock) so ao confirmar.
# Reutilizavel: estruturas futuras so precisam de uma receita e de uma zona.

signal placement_changed(active: bool)
signal structure_built(recipe_id: StringName, node: Node3D)
signal notice(text: String)

const Recipes := preload("res://scenes/world/build_recipes.gd")
const WORLD := 1 << 0
const PLAYER := 1 << 1
const CREATURES := 1 << 2
const BUILDINGS := 1 << 3
const INTERACTABLES := 1 << 4
const ROUTE_HALF_WIDTH := 2.0 # m da linha central de uma rota noturna (zona da armadilha)
const MIN_FROM_REFUGE := 3.0 # m do centro do refugio
const MIN_FROM_SLOT := 1.9 # m de um ponto de defesa (plataforma ~1,25 m)

@export var stock_path: NodePath = ^"../ResourceStock"
@export var player_path: NodePath = ^"../Player"
@export var regions_path: NodePath = ^"../WorldRegions"
@export var structures_path: NodePath = ^"../Structures"

var recipe_id := &""
var ghost: Node3D
var ghost_valid := false
var ghost_reason := ""
var _rotation_steps := 0
var _ghost_mats: Array[StandardMaterial3D] = []
## Jogo: o fantasma segue o cursor. Testes desligam e usam move_ghost_to().
var follow_cursor := true

@onready var stock: Node = get_node(stock_path)
@onready var player: Node3D = get_node(player_path)
@onready var regions: Node = get_node(regions_path)
@onready var structures: Node3D = get_node(structures_path)

func _ready() -> void:
	add_to_group("build_placer")

func is_placing() -> bool:
	return recipe_id != &""

func count(id: StringName) -> int:
	var group := "healing_campfire" if id == Recipes.CAMPFIRE else "spike_trap"
	return get_tree().get_nodes_in_group(group).size()

## Motivo para a receita nao poder ser iniciada ("" = pode).
func recipe_block_reason(id: StringName) -> String:
	var r := Recipes.get_recipe(id)
	if count(id) >= r.limit:
		return "LIMITE ATINGIDO"
	if not DayNightManager.is_day():
		return "Disponível durante o dia"
	if not stock.can_afford_resources(r.wood, r.stone):
		return "Recursos insuficientes"
	return ""

func begin(id: StringName) -> bool:
	cancel()
	var reason := recipe_block_reason(id)
	if reason != "":
		notice.emit("Construa durante o dia" if reason == "Disponível durante o dia" else reason)
		return false
	recipe_id = id
	_rotation_steps = 0
	var script: Script = load(Recipes.get_recipe(id).script)
	ghost = script.new()
	ghost.set("preview", true)
	ghost.name = "BuildGhost"
	add_child(ghost)
	_ghost_mats.clear()
	for mi in ghost.find_children("*", "MeshInstance3D", true, false):
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
		_ghost_mats.append(m)
	# Pegada no chao com o raio REAL ocupado: estruturas pequenas (fogueira,
	# armadilha) ficavam quase invisiveis so como fantasma translucido.
	var footprint := MeshInstance3D.new()
	footprint.name = "Footprint"
	var disc := CylinderMesh.new()
	disc.top_radius = Recipes.get_recipe(id).radius
	disc.bottom_radius = disc.top_radius
	disc.height = 0.04
	disc.radial_segments = 24
	footprint.mesh = disc
	footprint.position.y = 0.05
	var fm := StandardMaterial3D.new()
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	footprint.material_override = fm
	footprint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.add_child(footprint)
	_ghost_mats.append(fm)
	placement_changed.emit(true)
	if follow_cursor:
		_update_ghost()
	elif is_instance_valid(ghost):
		move_ghost_to(ghost.global_position) # revalida no lugar (dia/noite, ocupacao)
	return true

func cancel() -> void:
	if not is_placing():
		return
	recipe_id = &""
	if is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null
	placement_changed.emit(false)

func rotate_step() -> void:
	_rotation_steps = (_rotation_steps + 1) % 4

func _process(_delta: float) -> void:
	if not is_placing():
		return
	if not DayNightManager.is_day():
		notice.emit("Construa durante o dia")
		cancel() # anoiteceu no meio do posicionamento
		return
	if follow_cursor:
		_update_ghost()
	elif is_instance_valid(ghost):
		move_ghost_to(ghost.global_position) # revalida no lugar (dia/noite, ocupacao)

func cursor_ground_point() -> Variant:
	var cam: Camera3D = player.get_node("StrategicCamera")
	return cam.screen_to_ground(get_viewport().get_mouse_position(), 0.0)

## Posiciona o fantasma (testes podem passar o ponto direto).
func move_ghost_to(point: Vector3) -> void:
	if not is_instance_valid(ghost):
		return
	ghost.global_position = Vector3(point.x, 0.0, point.z)
	ghost.rotation.y = _rotation_steps * PI / 2.0
	ghost_reason = validate(recipe_id, ghost.global_position)
	ghost_valid = ghost_reason == ""
	var color := Color(0.35, 1.0, 0.55, 0.7) if ghost_valid else Color(1.0, 0.25, 0.2, 0.7)
	for m in _ghost_mats:
		m.albedo_color = color

func _update_ghost() -> void:
	var p = cursor_ground_point()
	if p != null:
		move_ghost_to(p)

## RF-CON-003: "" = valido; senao o motivo (mostrado na HUD).
func validate(id: StringName, pos: Vector3) -> String:
	var r := Recipes.get_recipe(id)
	if r.is_empty():
		return "Receita inválida"
	if not DayNightManager.is_day():
		return "Construa durante o dia"
	if count(id) >= r.limit:
		return "Limite atingido"
	if not _in_zone(r.zone, pos):
		if r.zone == "base" and _in_wild_territory(pos):
			return "Território selvagem: recupere o marco primeiro" # Spec 015
		return "Fora da área permitida" if r.zone == "base" else "Coloque sobre uma rota de ataque"
	# Spec 015 (RF-TER-010): fora da BuildZone original, estrutura solida nunca
	# encosta numa rota noturna (a navmesh e assada offline e nao desvia).
	if r.zone == "base" and not _in_build_zone(pos) and _route_distance(pos) < ROUTE_HALF_WIDTH + r.radius:
		return "Bloquearia uma rota noturna"
	var refuge := get_parent().get_node("Territory") as Node3D
	if _flat(pos, refuge.global_position) < MIN_FROM_REFUGE:
		return "Muito perto do refúgio"
	for slot in get_tree().get_nodes_in_group("defense_slot"):
		if _flat(pos, slot.global_position) < MIN_FROM_SLOT:
			return "Ocupado por ponto de defesa"
	for s in get_tree().get_nodes_in_group("built_structure"):
		var other := Recipes.get_recipe(s.get_meta("recipe_id", &""))
		var gap: float = r.radius + (other.radius if not other.is_empty() else 1.0)
		if _flat(pos, s.global_position) < gap:
			return "Local ocupado"
	# Solidos e corpos: arvores, pedras, coletaveis, refugio, torres, Player, dinos.
	var shape := CylinderShape3D.new()
	shape.radius = r.radius
	shape.height = 1.6
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.95, 0))
	q.collision_mask = WORLD | PLAYER | CREATURES | BUILDINGS | INTERACTABLES
	if not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
		return "Local ocupado"
	# Precisa estar no chao navegavel (nada de construir fora do vale).
	var map := get_world_3d().navigation_map
	var on_mesh := NavigationServer3D.map_get_closest_point(map, pos)
	if _flat(on_mesh, pos) > 0.35:
		return "Terreno inválido"
	return ""

func _in_zone(zone: String, pos: Vector3) -> bool:
	if zone == "base":
		# Spec 015 (RF-TER-010): BuildZone original OU um territorio CONTROLADO
		# com area de construcao. As demais validacoes continuam valendo.
		var territories := _territories()
		return _in_build_zone(pos) or (territories != null and territories.is_build_area(pos))
	# "route": perto da linha central de uma das 3 rotas noturnas.
	return _route_distance(pos) <= ROUTE_HALF_WIDTH

func _in_build_zone(pos: Vector3) -> bool:
	var bz: Marker3D = regions.get_node("SafeZone/BuildZone")
	var half: Vector2 = bz.get_meta("size_xz") * 0.5
	var d := pos - bz.global_position
	return absf(d.x) <= half.x and absf(d.z) <= half.y

func _territories() -> Node:
	return get_parent().get_node_or_null("TerritoryManager")

func _in_wild_territory(pos: Vector3) -> bool:
	var territories := _territories()
	if territories == null:
		return false
	var id: StringName = territories.territory_at(pos)
	return id != &"" and territories.info(id).get("build_area", false) and not territories.is_controlled(id)

var _route_segments: Array = [] # [a, b] em XZ, lidos uma vez das malhas das rotas

## Distancia (XZ) ate a linha central da rota noturna mais proxima.
func _route_distance(pos: Vector3) -> float:
	if _route_segments.is_empty():
		for trail in regions.get_node("NightRoutes").get_children():
			for stretch in trail.get_children():
				if not String(stretch.name).begins_with("Stretch"):
					continue
				var corners := {}
				for f in stretch.mesh.get_faces():
					corners[Vector2(snappedf(f.x, .01), snappedf(f.z, .01))] = true
				var pts: Array = corners.keys()
				if pts.size() == 4:
					_route_segments.append([(pts[0] + pts[3]) * 0.5, (pts[1] + pts[2]) * 0.5])
	var p := Vector2(pos.x, pos.z)
	var best := INF
	for s in _route_segments:
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, s[0], s[1]).distance_to(p))
	return best

## Confirma no ponto atual do fantasma. Paga de forma atomica e cria a estrutura.
func confirm() -> Node3D:
	if not is_placing() or not is_instance_valid(ghost):
		return null
	var pos := ghost.global_position
	var reason := validate(recipe_id, pos)
	if reason != "":
		notice.emit(reason)
		return null
	var r := Recipes.get_recipe(recipe_id)
	if not stock.spend_resources(r.wood, r.stone):
		notice.emit("Recursos insuficientes")
		return null
	var node: Node3D = load(r.script).new()
	node.set_meta("recipe_id", recipe_id)
	node.name = "%s%d" % [String(recipe_id).capitalize(), structures.get_child_count() + 1]
	structures.add_child(node, true)
	node.global_position = pos
	node.rotation.y = _rotation_steps * PI / 2.0
	var id := recipe_id
	cancel()
	print("[CONSTRUCAO] %s em %s" % [r.name, pos])
	notice.emit(r.built)
	structure_built.emit(id, node)
	return node

func _unhandled_input(event: InputEvent) -> void:
	if not is_placing():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			confirm()
			get_viewport().set_input_as_handled() # o clique de construir nao ataca
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("build_rotate") and not event.is_echo():
		rotate_step()
		get_viewport().set_input_as_handled()

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
