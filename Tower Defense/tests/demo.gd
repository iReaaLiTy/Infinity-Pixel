# Staged, repeatable gameplay demonstration. Positions are arranged for filming.
extends Node
var app: Node
func wait(t: float) -> void:
	await get_tree().create_timer(t,true,false,true).timeout
func _ready() -> void:
	app=load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await wait(2)
	app.start_game()
	await wait(.3)
	var player=app.world.get_node("Player")
	var dino=app.world.get_node("EncounterSpawner").current_encounter
	player.global_position=dino.global_position+Vector3(0,0,1.6)
	await wait(1)
	for i in range(3):
		player._try_attack()
		await wait(.85)
	Input.action_press("domesticate")
	await wait(2.1)
	Input.action_release("domesticate")
	player.global_position=Vector3(0,0,-7)
	dino.global_position=Vector3(0,0,-5)
	player.rotation.y=PI
	await wait(.5)
	Input.action_press("command_stay")
	await wait(.1)
	Input.action_release("command_stay")
	await wait(1)
	DayNightManager.start_night()
	await wait(1.6)
	var wave=app.world.get_node("WaveManager")
	# Face and strike each hostile through the real Area3D/cooldown path.
	for i in range(3):
		var target: Node3D
		for candidate in wave._active_wave_enemies:
			if is_instance_valid(candidate): target=candidate;break
		if target==null:
			await wait(2)
			for candidate in wave._active_wave_enemies:
				if is_instance_valid(candidate):target=candidate;break
		if is_instance_valid(target):
			for hit in range(4):
				if not is_instance_valid(target):break
				player.global_position=target.global_position+Vector3(0,0,-1.5)
				player.rotation.y=PI
				await wait(.08)
				player._try_attack()
				await wait(.83)
	await wait(2)
	print("DEMO victory: ",app.screen)
	app.resume_game()
	await wait(1)
	app.start_game()
	await wait(.2)
	player=app.world.get_node("Player")
	player.global_position=Vector3(17,0,-17)
	var camera:=Camera3D.new()
	app.world.add_child(camera)
	camera.position=Vector3(5,7,-20)
	camera.look_at(Vector3(0,1,-10))
	camera.make_current()
	DayNightManager.start_night()
	var t:=0.0
	while app.screen!="defeat" and t<20:
		await wait(.25)
		t+=.25
	print("DEMO defeat by actual enemies: ",app.screen," time=",t)
	await wait(2)
	app.start_game()
	await wait(1)
	get_tree().quit()
