extends Node

# Spec 013B — economia, pontos de defesa, torre e niveis, na cena real.
# Tambem cobre o audio do menu (R, S, T). Itens do pedido entre colchetes.
const DINO := preload("res://scenes/enemies/wild_dino.tscn")
var passed: Array[String] = []
var failed: Array[String] = []
var app: Node
var notices: Array[String] = []

func check(ok: bool, title: String) -> void:
	(passed if ok else failed).append(title)
	print(("PASS: " if ok else "FAIL: ") + title)

# Espera em TEMPO DE JOGO (passos de fisica): com janela e quadros perdidos um
# timer de parede correria na frente dos spawns/torres e o teste mediria errado.
func wait(seconds: float) -> void:
	for i in int(round(seconds * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func key_c() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_C
	ev.keycode = KEY_C
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)
	ev.pressed = false
	Input.parse_input_event(ev)
	await frames(1)

func stand_at(player: Node3D, slot: Node3D, offset := Vector3(0, 0, 1.8)) -> void:
	player.global_position = slot.global_position + offset + Vector3(0, .1, 0)
	player.velocity = Vector3.ZERO
	await frames(3)

func _ready() -> void:
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await frames(1)
	app.start_game()
	await frames(3)
	var world: Node3D = app.world
	var economy = world.get_node("DefenseEconomy")
	var slots = world.get_node("DefenseSlots")
	var wave = world.get_node("WaveManager")
	var player: CharacterBody3D = world.get_node("Player")
	var encounter = world.get_node("EncounterSpawner").current_encounter
	encounter.set_physics_process(false)
	player._invulnerable_left = INF # o teste mede economia/torres, nao a vida
	slots.notice.connect(func(t): notices.append(t))
	var all_slots: Array = slots.slots()
	check(all_slots.size() == 6, "6 pontos de defesa no mapa")
	var routes := {}
	for s in all_slots: routes[s.route] = routes.get(s.route, 0) + 1
	check(routes == {"Oeste": 2, "Ruína": 2, "Leste": 2}, "2 pontos por rota %s" % [routes])
	var min_base := INF
	for s in all_slots: min_base = minf(min_base, s.global_position.distance_to(world.get_node("Territory").global_position))
	check(min_base > 8.0, "Nenhum ponto colado no refugio (mais proximo a %.1f m)" % min_base)

	# [A] 30 pontos iniciais, HUD exibe
	check(economy.points == 40 and app.points_text.text == "40", "[A] Novo jogo comeca com 40 Pontos de Defesa (HUD 40; 013C: era 30)")
	# Painel contextual perto de um ponto vazio
	var w1: Node3D = world.get_node("DefenseSlots/SlotWestInner")
	await stand_at(player, w1)
	check(app.build_panel.visible and app.build_title.text == "PONTO DE CONSTRUÇÃO" and app.build_info.text == "Torre de Defesa  ·  Custo: 30" and not app.build_button.disabled, "Painel: PONTO DE CONSTRUCAO, Torre de Defesa Custo 30, CONSTRUIR habilitado")
	# [E][G] construir com a tecla C custa 30
	await key_c()
	check(not w1.is_empty() and economy.points == 10 and app.points_text.text == "10", "[E][G] C constroi: ponto ocupado, 40 -> 10")
	# [H] nada de segunda torre no mesmo ponto
	check(w1.build() == null and w1.find_children("*", "StaticBody3D", false, false).size() == 1, "[H] Segunda torre no mesmo ponto recusada")
	# [F] sem pontos nao constroi
	var e1: Node3D = world.get_node("DefenseSlots/SlotEastInner")
	await stand_at(player, e1)
	check(app.build_button.disabled and app.build_note.text == "Pontos insuficientes", "[F] Sem pontos: botao desabilitado + 'Pontos insuficientes'")
	await key_c()
	check(e1.is_empty() and economy.points == 10 and "Pontos insuficientes" in notices, "[F] C com 10 pontos nao constroi (custa 30)")

	# Noite: inimigos reais da onda
	player.global_position = Vector3(0, 1, -10)
	DayNightManager.start_night()
	await wait(4.3)
	var foes: Array = wave._active_wave_enemies.keys()
	check(foes.size() == 3, "Noite 1 com 3 inimigos da onda")
	for f in foes: f.set_physics_process(false)
	# Os outros dois saem do alcance: a torre mira o mais proximo, e o teste
	# precisa saber qual inimigo ela deve acertar.
	foes[1].global_position = Vector3(-2, .5, 40)
	foes[2].global_position = Vector3(2, .5, 40)
	# [P] construcao/upgrade bloqueados a noite
	economy.add_points(100)
	var before: int = economy.points
	await stand_at(player, e1)
	check(app.build_button.disabled and app.build_note.text == "Construa durante o dia", "[P] Painel a noite: 'Construa durante o dia'")
	await key_c()
	check(e1.is_empty() and economy.points == before and notices.back() == "Construa durante o dia", "[P] Construcao bloqueada a noite")
	await stand_at(player, w1)
	check(not slots.interact(w1) and w1.tower.level == 1 and economy.points == before, "[P] Upgrade bloqueado a noite")
	economy.spend(100) # volta ao saldo real da partida (10)
	# [I] a torre ataca inimigo valido no alcance
	var tower = w1.tower
	player.global_position = Vector3(0, 1, -10)
	var foe = foes[0]
	foe.global_position = w1.global_position + Vector3(4, .5, 0)
	var hp0: float = foe.hp
	await wait(1.25)
	check(foe.hp < hp0 and is_equal_approx(fmod(hp0 - foe.hp, 10.0), 0.0) and tower.target == foe, "[I] Torre L1 ataca inimigo da onda (10 por golpe, %d -> %d)" % [hp0, foe.hp])
	# [B] morte de inimigo da onda: +15, com '+15' na HUD
	foe.take_damage(1000)
	foe.died.emit(foe) # [C] sinal de morte duplicado do mesmo inimigo, mesmo quadro
	await frames(2)
	check(economy.points == 25, "[B] Inimigo da onda derrotado: +15 (total %d)" % economy.points)
	# "+N" pode vir sufixado (PointsGain2) se um anterior ainda estiver sumindo.
	var gains: Array = app.hud.get_children().filter(func(c): return String(c.name).begins_with("PointsGain") and c.text == "+15 PONTOS")
	check(not gains.is_empty() and app.points_text.text == "25", "[B] HUD mostra 25 e o '+15 PONTOS' temporario")
	# [C] o mesmo inimigo nao paga de novo
	# (o died duplicado acima nao pagou de novo)
	check(economy.points == 25, "[C] Mesmo inimigo nao concede duas vezes")
	# [K] domesticado (vindo da onda) nao e alvo e nao paga
	var tamed = foes[1]
	tamed.global_position = w1.global_position + Vector3(-3, .5, 0)
	tamed.hp = 20.0 # a torre ja pode te-lo acertado no caminho; fixa o HP elegivel
	tamed.domesticate()
	var tamed_hp: float = tamed.hp
	await wait(1.5)
	check(tamed.hp == tamed_hp and tower.target != tamed and economy.points == 25, "[K] Torre nao ataca domesticado; domesticar nao paga")
	tamed.take_damage(100) # morte posterior do ex-inimigo
	await frames(2)
	check(economy.points == 25, "[C][K] Domesticado morto depois nao concede pontos")
	# [J] nunca Player, aliado ou refugio
	player.global_position = w1.global_position + Vector3(2.5, 1, 0)
	var php: float = player.current_hp
	var last = foes[2]
	last.global_position = Vector3(0, .5, 40) # fora de alcance
	await wait(1.3)
	check(tower.target == null and player.current_hp == php, "[J] Torre sem alvo nao ataca o Player")
	check(not tower.is_valid_target(player) and not tower.is_valid_target(world.get_node("Territory")) and not tower.is_valid_target(tamed), "[J][K] Player, refugio e aliado nunca sao alvos validos")
	# [D] criatura selvagem comum (encontro / T) nao paga e nao e alvo
	var wild = DINO.instantiate()
	world.add_child(wild)
	wild.global_position = w1.global_position + Vector3(0, .5, 3)
	wild.set_physics_process(false)
	await wait(1.3)
	check(wild.hp == 80.0, "[D] Torre ignora selvagem fora da onda")
	wild.take_damage(1000)
	encounter.take_damage(1000)
	await frames(2)
	check(economy.points == 25, "[D] Selvagem comum e encontro derrotados nao concedem pontos")
	# fim da onda -> amanhecer
	last.take_damage(1000)
	await wait(.3)
	check(DayNightManager.is_day() and DayNightManager.day_number == 2 and economy.points == 40, "Noite 1 vencida: Dia 2 com 40 pontos (10 + 15 + 15)")
	# [O] torre persiste
	check(not w1.is_empty() and w1.tower == tower and tower.level == 1, "[O] Torre e nivel persistem no amanhecer")

	# [L] L1 -> L2 = 30, pelo botao do painel
	await stand_at(player, w1)
	check(app.build_button.text == "MELHORAR — 30  (C)" and app.build_title.text == "TORRE DE DEFESA  ·  NÍVEL 1", "Painel da torre: NIVEL 1, MELHORAR — 30")
	app.build_button.pressed.emit()
	var s2: Dictionary = tower.stats()
	check(tower.level == 2 and economy.points == 10 and s2.damage == 15.0 and s2.interval == .85 and s2.range == 9.0, "[L] Upgrade L1->L2 custa 30: dano 15, 0,85 s, 9 m")
	# [M] L2 -> L3 = 45
	economy.add_points(34) # 10 + 34 = 44
	await frames(2)
	check(app.build_button.disabled and app.build_note.text == "Pontos insuficientes", "[M] 44 pontos nao bastam para o L3")
	economy.add_points(1)
	await key_c()
	var s3: Dictionary = tower.stats()
	check(tower.level == 3 and economy.points == 0 and s3.damage == 20.0 and s3.interval == .7 and s3.range == 10.0, "[M] Upgrade L2->L3 custa 45: dano 20, 0,70 s, 10 m")
	# [N] L3 e o maximo
	economy.add_points(100)
	await frames(2)
	await key_c()
	check(tower.level == 3 and economy.points == 100 and app.build_button.text == "NÍVEL MÁXIMO" and app.build_button.disabled, "[N] L3 nao melhora de novo; painel 'NIVEL MAXIMO'")
	# [Q] Reiniciar limpa tudo
	app.start_game()
	await frames(3)
	var new_world: Node3D = app.world
	var empty := true
	for s in new_world.get_node("DefenseSlots").slots(): empty = empty and s.is_empty()
	check(new_world.get_node("DefenseEconomy").points == 40 and empty and DayNightManager.day_number == 1, "[Q] Reiniciar: 40 pontos, pontos vazios, Dia 1")

	# [R][S][T] audio do menu
	app.show_menu()
	await frames(3)
	var slider: HSlider = app.ui.find_child("VolumeSlider", true, false)
	var icon: Button = app.ui.find_child("AudioButton", true, false)
	var bus := AudioServer.get_bus_index("Music")
	slider.value = 0
	check(app.audio.muted and AudioServer.is_bus_mute(bus) and (app.audio.muted or app.audio.volume <= 0.0), "[R] Slider 0: mudo (icone de mudo)")
	slider.value = 1
	check(not app.audio.muted and not AudioServer.is_bus_mute(bus) and is_equal_approx(app.audio.volume, .01), "[S] Slider 1%: som volta (icone de som)")
	slider.value = 60
	icon.pressed.emit()
	check(slider.value == 0 and app.audio.muted, "[T] Icone com som 60: mudo, slider 0")
	icon.pressed.emit()
	check(slider.value == 60 and not app.audio.muted and is_equal_approx(app.audio.volume, .6), "[T] Icone de novo: volta para 60")
	slider.value = 55

	var report := {"passed": passed, "failed": failed, "display": DisplayServer.get_name()}
	var destination := "user://spec013b-defense.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): destination = argument.trim_prefix("--report=")
	var file := FileAccess.open(destination, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("SPEC013B RESULTS: %d passed; %d failed" % [passed.size(), failed.size()])
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)
