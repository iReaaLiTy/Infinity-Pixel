extends StaticBody3D

# Spec: docs/specs/013c-combate-coleta-hud.md — RF-COL-002 a 005 (PROVISORIO)
#
# Arvore ou pedra coletavel. Recebe o golpe normal do Player pelo contrato
# take_damage (ADR 0001) — sem tecla propria. Ao zerar: paga UMA vez ao
# ResourceStock, cai/quebra e fica esgotada ate o proximo amanhecer, quando o
# MESMO no e restaurado (nenhum no novo e criado).
#
# Fisica/navegacao: solido (camada 1, mundo, para bloquear Player/criaturas) +
# camada 5 (interacao) para o golpe. NAO entra na navmesh (assada offline so
# com o grupo navigation_source): a IA desvia pelo NavigationObstacle3D. Assim
# esgotar o recurso nao deixa buraco na navmesh e nao exige rebake.

const Nature := preload("res://scenes/visuals/nature_meshes.gd")
const CombatFX := preload("res://scenes/visuals/combat_fx.gd")
const WORLD := 1 << 0
const INTERACTABLES := 1 << 4
const KINDS := {
	&"wood": {"hp": 30.0, "reward": 10, "label": "MADEIRA"},
	&"stone": {"hp": 45.0, "reward": 6, "label": "PEDRA"},
}

@export_enum("wood", "stone") var kind := "wood"
@export var stock_path: NodePath = ^"../../ResourceStock"

var max_hp := 0.0
var hp := 0.0
var depleted := false
var _visual: Node3D
var _shape: CollisionShape3D
var _obstacle: NavigationObstacle3D
var _rest_transform: Transform3D
var _depleted_on_day := 0
var _feedback_tween: Tween

func _ready() -> void:
	add_to_group("damageable") # ADR 0001: o golpe do Player alcanca
	add_to_group("collectable")
	collision_layer = WORLD | INTERACTABLES
	collision_mask = 0
	var data: Dictionary = KINDS[StringName(kind)]
	max_hp = data.hp
	hp = max_hp
	_shape = CollisionShape3D.new()
	_obstacle = NavigationObstacle3D.new()
	_obstacle.avoidance_enabled = true
	if kind == "wood":
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.35
		capsule.height = 3.0
		_shape.shape = capsule
		_shape.position.y = 1.5
		_obstacle.radius = 0.6
	else:
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.8
		cylinder.height = 1.2
		_shape.shape = cylinder
		_shape.position.y = 0.6
		_obstacle.radius = 1.0
	_obstacle.height = 2.0
	add_child(_shape)
	add_child(_obstacle)
	_visual = _build_tree() if kind == "wood" else _build_stone()
	_rest_transform = _visual.transform
	set_process(false) # so verifica o amanhecer enquanto esgotado

func reward() -> int:
	return KINDS[StringName(kind)].reward

func label() -> String:
	return KINDS[StringName(kind)].label

func take_damage(amount: float) -> void:
	if depleted or not is_finite(amount) or amount <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	print("[COLETA] %s recebeu %.0f. HP: %.0f/%.0f" % [name, amount, hp, max_hp])
	if hp <= 0.0:
		_deplete()
	else:
		_hit_feedback()

func _deplete() -> void:
	depleted = true # antes de pagar: um segundo golpe no mesmo quadro nao paga de novo
	_depleted_on_day = DayNightManager.day_number
	set_process(true)
	collision_layer = 0
	_obstacle.avoidance_enabled = false
	remove_from_group("damageable")
	var stock := get_node_or_null(stock_path)
	if stock != null:
		stock.add(StringName(kind), reward())
	if is_instance_valid(_feedback_tween): _feedback_tween.kill()
	var t := create_tween()
	_feedback_tween = t
	if kind == "wood":
		# A arvore tomba para o lado e afunda.
		t.tween_property(_visual, "rotation:z", deg_to_rad(82), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(_visual, "scale", Vector3.ONE * 0.01, 0.35)
	else:
		_burst()
		t.tween_property(_visual, "scale", Vector3(1.25, 0.15, 1.25), 0.18)
		t.tween_property(_visual, "scale", Vector3.ONE * 0.01, 0.2)
	t.tween_callback(_visual.hide)

# RF-COL-004: volta no amanhecer seguinte — o mesmo no, sem duplicar. Compara o
# numero do dia (fonte unica: DayNightManager) em vez de assinar day_started,
# para nao somar conexoes ao autoload a cada recurso.
func _process(_delta: float) -> void:
	if depleted and DayNightManager.day_number > _depleted_on_day:
		restore()

func restore() -> void:
	if not depleted:
		return
	if is_instance_valid(_feedback_tween): _feedback_tween.kill()
	depleted = false
	hp = max_hp
	collision_layer = WORLD | INTERACTABLES
	_obstacle.avoidance_enabled = true
	add_to_group("damageable")
	_visual.transform = _rest_transform
	_visual.show()
	set_process(false)

# Golpe que nao esgota: tremida e "aperto" rapido.
func _hit_feedback() -> void:
	var t := create_tween()
	var base := _rest_transform.basis
	_visual.scale = Vector3(1.12, 0.9, 1.12)
	t.tween_property(_visual, "rotation:z", 0.09, 0.05)
	t.tween_property(_visual, "rotation:z", -0.07, 0.06)
	t.tween_property(_visual, "rotation:z", 0.0, 0.05)
	t.parallel().tween_property(_visual, "scale", base.get_scale(), 0.16)
	_burst(3)

# Lascas facetadas que saltam e somem (sem particulas): cinza-azuladas na pedra,
# madeira clara na arvore (Spec 019: todo golpe que acerta mostra impacto).
func _burst(count := 6) -> void:
	var mat := _mat(Color("9aa3a8") if kind == "stone" else Color("d9b98a"))
	for i in count:
		var chip := MeshInstance3D.new()
		chip.mesh = CombatFX.shard_mesh()
		chip.material_override = mat
		chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chip.scale = Vector3.ONE * randf_range(1.2, 2.0)
		chip.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		add_child(chip)
		chip.position = Vector3(0, 0.7 if kind == "stone" else 0.8, 0)
		var a := TAU * i / count + randf() * 0.5
		var end := Vector3(sin(a) * 1.1, 0.15, cos(a) * 1.1)
		var t := chip.create_tween()
		t.tween_property(chip, "position", end, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(chip, "scale", Vector3.ONE * 0.2, 0.35)
		t.tween_callback(chip.queue_free)

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, scale_v: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scale_v
	mi.material_override = _mat(color)
	parent.add_child(mi)
	return mi

# Spec 018: arvore coletavel da mesma familia facetada das arvores do mapa, mais
# baixa, com copa amarelo-esverdeada (diferente da decoracao) e o corte claro de
# machado no tronco: "da para lenhar".
func _build_tree() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var trunk := MeshInstance3D.new()
	trunk.mesh = Nature.harvest_trunk()
	trunk.material_override = Nature.material()
	root.add_child(trunk)
	for spec in [[Vector3(0, 2.45, 0), Vector3(2.3, 1.8, 2.3), 0], [Vector3(0.1, 3.05, -0.05), Vector3(1.6, 1.3, 1.6), 1]]:
		var crown := MeshInstance3D.new()
		crown.mesh = Nature.crown(Nature.Kind.BROADLEAF, spec[2], Nature.HARVEST_LEAVES)
		crown.material_override = Nature.material()
		crown.position = spec[0]
		crown.scale = spec[1]
		root.add_child(crown)
	return root

# Pedra coletavel: bloco facetado escuro com cristais de minerio (azul e ambar)
# saindo da rocha: le diferente das rochas decorativas (cinza, sem cristal).
func _build_stone() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var body := MeshInstance3D.new()
	body.mesh = Nature.ore_stone()
	body.material_override = Nature.material()
	body.rotation.y = 0.6
	root.add_child(body)
	return root
