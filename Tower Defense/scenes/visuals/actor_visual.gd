extends Node3D

var clock := 0.0
var swing := 0.0
var flash_time := 0.0
var ally := false

func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	if body == null:
		return
	clock += delta
	var pace := minf(Vector2(body.velocity.x, body.velocity.z).length() / 4.0, 1.0)
	$LegL.rotation.x = sin(clock * 11.0) * 0.48 * pace
	$LegR.rotation.x = -sin(clock * 11.0) * 0.48 * pace
	swing = maxf(0, swing - delta)
	position.y = abs(sin(clock * 11)) * .04 * pace
	rotation.x = -sin(swing * PI / .32) * .2
	if has_node("ArmR"):
		$ArmR.rotation.x = -sin(swing * PI / .32) * 1.6
	if has_node("Tail"):
		$Tail.rotation.y = sin(clock * 3) * .13
	flash_time = maxf(0, flash_time - delta)
	scale = Vector3.ONE * (1.0 + sin(flash_time * 28) * .045)

func strike() -> void:
	swing = .32

func flash() -> void:
	flash_time = .22

func set_ally() -> void:
	ally = true
	if has_node("Collar"):
		$Collar.show()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("69be9b")
	material.roughness = .85
	$Crest.material_override = material
	flash_time = .6
