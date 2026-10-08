extends Node

# Focused regression: incompatible actions must cancel an ALREADY active heal.
# Complements the existing, unchanged 68 build_heal checks.
const Recipes := preload("res://scenes/world/build_recipes.gd")
var passed: Array[String] = []
var failed: Array[String] = []

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func check(ok: bool, label: String) -> void:
	(passed if ok else failed).append(label)
	print(("PASS: " if ok else "FAIL: ") + label)

func _ready() -> void:
	var app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	app.start_game()
	await frames(5)
	var world: Node3D = app.world
	var player = world.get_node("Player")
	player.set_process_unhandled_input(false)
	var stock = world.get_node("ResourceStock")
	var placer = world.get_node("BuildPlacer")
	for d in world.get_node("EncounterSpawner").encounters:
		d.set_physics_process(false)
	# validate() exige chao navegavel. A regiao do mapa novo entra no mapa de
	# navegacao de forma assincrona (as vezes > 5 quadros; o fundo do menu ja o
	# sincronizou antes, entao iteration_id > 0 nao basta): sem esperar, a
	# construcao era recusada ("Terreno invalido") e o teste travava.
	var map: RID = world.get_world_3d().navigation_map
	var spot := Vector3(8.5,0,-17)
	for i in 300:
		var on_mesh := NavigationServer3D.map_get_closest_point(map,spot)
		if Vector2(on_mesh.x-spot.x,on_mesh.z-spot.z).length() <= .35:
			break
		await frames(1)
	stock.add(&"wood",40)
	stock.add(&"stone",18)
	placer.follow_cursor=false
	placer.begin(Recipes.CAMPFIRE)
	placer.move_ghost_to(spot)
	var fire = placer.confirm()
	if fire == null:
		check(false,"Fogueira construida para o teste (recusada: %s)" % placer.ghost_reason)
		print("HEALING ACTIONS: %d passed; %d failed" % [passed.size(),failed.size()])
		get_tree().quit(1)
		return
	player.global_position=fire.global_position+Vector3(0,.1,1.8)
	player.current_hp=50
	var dino = world.get_node("EncounterSpawner").encounters[0]
	dino.global_position=player.global_position+Vector3(1.5,0,0)
	dino.hp=20
	await frames(5)
	Input.action_press("heal_interact")
	await frames(60)
	check(fire.progress()>.25,"Cura iniciou antes da acao incompativel")
	Input.action_press("domesticate")
	await frames(10)
	check(player.get_node("DomesticationChannel").get_progress()>0 and fire.progress()==0,"Iniciar domesticacao cancela cura em andamento")
	await frames(40)
	check(fire.progress()==0 and player.current_hp==50 and fire.charges==2,"Cura nao recomeca enquanto domestica; sem gasto ou cura parcial")
	Input.action_release("domesticate")
	Input.action_release("heal_interact")
	await frames(4)
	Input.action_press("heal_interact")
	await frames(60)
	placer.begin(Recipes.TRAP)
	await frames(5)
	check(fire.progress()==0,"Iniciar posicionamento cancela cura em andamento")
	await frames(185)
	check(player.current_hp==50 and fire.charges==2 and fire.progress()==0,"H durante posicionamento nao cura nem consome carga")
	placer.cancel()
	Input.action_release("heal_interact")
	await frames(4)
	Input.action_press("heal_interact")
	await frames(60)
	check(fire.progress()>.25,"Cancelar posicionamento permite nova canalizacao completa")
	fire.queue_free()
	await frames(185)
	Input.action_release("heal_interact")
	check(not is_instance_valid(fire) and player.current_hp==50,"Remover fogueira interrompe cura sem efeito atrasado")
	app.show_menu()
	await frames(3)
	var destination := "user://healing-actions.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): destination=arg.trim_prefix("--report=")
	var report := FileAccess.open(destination,FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":passed,"failed":failed,"display":DisplayServer.get_name()},"  "))
	report.close()
	print("HEALING ACTIONS: %d passed; %d failed" % [passed.size(),failed.size()])
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)
