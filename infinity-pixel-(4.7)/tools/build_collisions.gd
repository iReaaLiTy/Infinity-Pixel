extends SceneTree

# Reads actual Godot transforms; supports editor-saved Transform3D too.
const WORLD := 1 << 0
const BUILDINGS := 1 << 3

func _initialize() -> void:
	build.call_deferred()

func build() -> void:
	var art := (load("res://scenes/visuals/arena_art.tscn") as PackedScene).instantiate()
	var scene := Node3D.new()
	scene.name = "ArenaCollision"
	for visual in art.get_children():
		var label := String(visual.name)
		var shape: Shape3D
		var layer := WORLD
		if label.begins_with("Trunk"):
			var capsule := CapsuleShape3D.new()
			capsule.radius = visual.scale.x * .5
			capsule.height = visual.scale.y
			shape = capsule
		elif label.begins_with("Rock"):
			var cylinder := CylinderShape3D.new()
			cylinder.radius = maxf(visual.scale.x, visual.scale.z) * .45
			# Spec 012: boulders are taller; the solid follows the visual height
			# (small rocks keep the Spec 009 height of 0,85 m).
			cylinder.height = maxf(.85, visual.scale.y * .9)
			shape = cylinder
		elif label.begins_with("Arch"):
			var box := BoxShape3D.new()
			box.size = visual.mesh.size
			shape = box
			layer = BUILDINGS
		elif label.begins_with("FirePost") or label.begins_with("BannerPole"):
			var cylinder := CylinderShape3D.new()
			cylinder.radius = visual.scale.x * .5
			cylinder.height = visual.scale.y
			shape = cylinder
			layer = BUILDINGS
		elif label == "RefugeCore":
			var cylinder := CylinderShape3D.new()
			cylinder.radius = .55
			cylinder.height = 2.6
			shape = cylinder
			layer = BUILDINGS
		else:
			continue
		var body := StaticBody3D.new()
		body.name = visual.name
		body.position = visual.position
		if label.begins_with("Arch"):
			body.rotation = visual.rotation
		if label == "RefugeCore":
			body.position.y = 1.3
		body.collision_layer = layer
		body.collision_mask = 0
		body.add_to_group("solid_obstacles", true)
		scene.add_child(body)
		body.owner = scene
		var collider := CollisionShape3D.new()
		collider.name = "CollisionShape3D"
		collider.shape = shape
		body.add_child(collider)
		collider.owner = scene
	assert(scene.get_child_count() == 66, "Review the Spec 009 obstacle inventory")
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/world/arena_collision.tscn") == OK)
	scene.free()
	art.free()
	print("[COLLISIONS] 66 authored primitives, unit scale, layers preserved")
	quit()
