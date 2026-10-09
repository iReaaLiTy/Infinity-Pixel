extends Node

# Spec 022: capturas reais do tutorial (nao e teste): menu com o botao, painel
# do passo 1, sinal jade no passo 2, selvagem marcado (passo 4), coleta, area de
# construcao (passo 9), noite do tutorial e a tela de conclusao. Exige janela.
# Uso: res://tools/tutorial_capture.tscn -- --output=<pasta>
const Director := preload("res://scenes/world/tutorial_director.gd")
var out := "user://tutorial-capture/"
var app

func wait(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func shot(label: String, frames := 15) -> void:
	await wait(frames)
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(out + label + ".png")
	print("[022] " + label)

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await wait(20)
	await shot("40_menu_com_tutorial")
	app.start_tutorial()
	await wait(10)
	var world: Node3D = app.world
	var tut = world.get_node("Tutorial")
	var player = world.get_node("Player")
	player.set_physics_process(false)
	player._invulnerable_left = INF
	player.get_node("StrategicCamera").follow_smoothing = 0.0
	await shot("41_passo1_andar")
	tut._enter(Director.Step.WALK)
	await shot("42_passo2_sinal")
	tut.target.set_physics_process(false)
	player.global_position = tut.target.global_position + Vector3(2.5, 0.1, 3.0)
	tut._enter(Director.Step.WEAKEN)
	tut.target.take_damage(45.0)
	await shot("43_passo4_enfraquecer")
	tut.target.take_damage(15.0)
	await shot("44_passo5_domesticar")
	tut.target.domesticate()
	await wait(5)
	player.global_position = Vector3(-14.0, 0.1, 16.0)
	tut._enter(Director.Step.WOOD)
	await shot("45_passo6_madeira")
	player.global_position = Vector3(4.0, 0.1, -9.0)
	tut._enter(Director.Step.CAMPFIRE)
	await shot("46_passo9_fogueira")
	player.global_position = Vector3(0.0, 0.1, -8.0)
	tut._enter(Director.Step.NIGHT)
	await wait(200)
	await shot("47_passo12_noite", 2)
	tut._enter(Director.Step.DONE)
	await shot("48_concluido")
	print("[022] capturas em " + out)
	app.show_menu()
	get_tree().quit.call_deferred()
