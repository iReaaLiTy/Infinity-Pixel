extends Node

## Gameplay 5.0: one per world, never tied to the lifetime of inventory UI.
signal changed
signal notice(text: String)
const WOOD := 40
const STONE := 24
const HEAL := 40.0
const RANGE := 3.0
const FX := preload("res://scenes/visuals/combat_fx.gd")
var stored := 0
var next_day := 2
var stock: Node
var player: Node3D

func _ready() -> void:
	stock = get_parent().get_node("ResourceStock")
	player = get_parent().get_node("Player")
	DayNightManager.day_started.connect(_dawn)

func _dawn() -> void:
	changed.emit()
	if DayNightManager.day_number == 2:
		notice.emit("ELIXIR DE JADE liberado · Inventário → Companheiros · G cura um aliado próximo")

func days_left() -> int:
	return maxi(0, next_day - DayNightManager.day_number)

func craft_reason() -> String:
	if stored > 0: return "Você já possui um elixir (1/1)."
	if days_left() > 0: return "Disponível em %d amanhecer(es) · Dia %d" % [days_left(), next_day]
	if not stock.can_afford_resources(WOOD, STONE):
		return "Faltam %d madeiras e %d pedras." % [maxi(0, WOOD - stock.get_amount(&"wood")), maxi(0, STONE - stock.get_amount(&"stone"))]
	if not DayNightManager.can_play() or player.is_dead: return "Indisponível agora."
	return ""

func craft() -> bool:
	var reason := craft_reason()
	if reason != "":
		notice.emit(reason)
		return false
	# Reserve before resource signals fire: reentrant UI cannot duplicate items.
	stored = 1
	next_day = DayNightManager.day_number + 2
	if not stock.spend_resources(WOOD, STONE):
		stored = 0
		next_day = DayNightManager.day_number
		return false
	FX.hit_spark(player, player.global_position + Vector3.UP, Color("74e3b6"), 6)
	changed.emit()
	notice.emit("ELIXIR DE JADE fabricado · G para curar um aliado ferido a até 3 m")
	return true

func valid_target(target: Node3D) -> bool:
	return is_instance_valid(target) and not target.is_queued_for_deletion() \
		and target.is_in_group("domesticated") and target.get("is_domesticated") == true \
		and not target.is_in_group("wave_enemy") and target.has_method("heal_ally") \
		and target.get("hp") > 0.0 and target.get("hp") < target.MAX_HP \
		and player.global_position.distance_to(target.global_position) <= RANGE

func nearest_target() -> Node3D:
	var best: Node3D
	var best_distance := INF
	for target in get_tree().get_nodes_in_group("domesticated"):
		if not valid_target(target): continue
		var distance: float = player.global_position.distance_squared_to(target.global_position)
		if distance < best_distance or (is_equal_approx(distance, best_distance) and (best == null or target.get_instance_id() < best.get_instance_id())):
			best = target
			best_distance = distance
	return best

func use_on(target: Node3D) -> bool:
	if stored != 1 or not DayNightManager.can_play() or player.is_dead or not valid_target(target):
		return false
	stored = 0
	var recovered: float = target.heal_ally(HEAL)
	if recovered <= 0.0:
		stored = 1
		return false
	FX.hit_spark(target, target.global_position + Vector3.UP, Color("74e3b6"), 8)
	FX.ring(target, target.global_position, Color("74e3b6"), 1.5, 0.6)
	var label := Label3D.new()
	label.text = "+%d HP" % int(recovered)
	label.modulate = Color("74e3b6")
	label.font_size = 64
	label.outline_size = 12
	label.outline_modulate = Color(0.04, 0.09, 0.07, 0.9)
	label.no_depth_test = true
	label.pixel_size = 0.011
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	get_parent().add_child(label)
	label.global_position = target.global_position + Vector3(0, 2.5, 0)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 0.7, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(label.queue_free)
	changed.emit()
	notice.emit("Companheiro recuperou +%d HP" % int(recovered))
	return true

func use_nearest() -> bool:
	var target := nearest_target()
	if use_on(target): return true
	notice.emit("Fabrique um Elixir de Jade no inventário." if stored == 0 else "Nenhum aliado ferido a até 3 m.")
	return false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode == KEY_G and event.pressed and not event.echo:
		if DayNightManager.can_play():
			use_nearest()
			get_viewport().set_input_as_handled()
