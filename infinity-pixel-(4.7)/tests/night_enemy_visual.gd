extends Node

# Identidade visual do inimigo da onda noturna (Spec 019 antecipada).
# A paleta azul-violeta depende da ORIGEM da criatura (spawn da onda), nunca do
# horario; selvagens diurnos, guardioes e aliados mantem a aparencia; os
# materiais compartilhados do modelo nunca sao alterados; reiniciar a partida
# nao troca materiais. So visual: vida, IA, numeros e regras nao sao tocados.
const DINO_VISUAL := preload("res://scenes/visuals/dino.tscn")
const VISUAL := preload("res://scenes/visuals/actor_visual.gd")
const BODY_DAY := Color(0.7803921568627451, 0.4235294117647059, 0.2980392156862745)
const NIGHT_MAIN := Color("18244d")
const NIGHT_ACCENT := Color("6678c8")
const ALLY_CREST := Color("69be9b")

var passed: Array[String] = []
var failed: Array[String] = []
var app
var reference := {} # nome da malha -> material original compartilhado do modelo

func check(ok: bool, label: String) -> void:
	(passed if ok else failed).append(label)
	print(("PASS: " if ok else "FAIL: ") + label)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func meshes(dino: Node) -> Array:
	return dino.get_node("Visual").find_children("*", "MeshInstance3D", true, false)

## Todas as malhas com o material original do modelo (exceto as listadas).
func day_look(dino: Node, except := []) -> bool:
	for mi: MeshInstance3D in meshes(dino):
		if mi.name in except:
			continue
		if mi.material_override != reference.get(String(mi.name)):
			return false
	return not dino.get_node("Visual").night_threat

func night_look(dino: Node) -> bool:
	for mi: MeshInstance3D in meshes(dino):
		var m := mi.material_override as StandardMaterial3D
		if m == null or not m.resource_name.begins_with("night_"):
			return false
	return dino.get_node("Visual").night_threat

func shared_untouched() -> bool:
	var m: StandardMaterial3D = reference["Body"]
	return m.albedo_color.is_equal_approx(BODY_DAY) and not m.emission_enabled and not m.rim_enabled

func day_dinos(world: Node) -> Array:
	return world.get_node("EncounterSpawner").encounters.filter(func(d): return is_instance_valid(d) and not d.is_domesticated)

func wave_foes() -> Array:
	return get_tree().get_nodes_in_group("wave_enemy").filter(func(d): return is_instance_valid(d))

func start_world() -> Node3D:
	app.start_game()
	await frames(10)
	var world: Node3D = app.world
	world.get_node("Player")._invulnerable_left = INF
	return world

func night_wave(world: Node3D) -> Array:
	DayNightManager.start_night()
	var wm = world.get_node("WaveManager")
	for i in 60 * 12:
		await get_tree().physics_frame
		if wm._active_wave_enemies.size() >= wm.enemy_count:
			break
	return wm._active_wave_enemies.keys().filter(func(d): return is_instance_valid(d))

func _ready() -> void:
	var report := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report = arg.trim_prefix("--report=")
	var probe := DINO_VISUAL.instantiate()
	for mi: MeshInstance3D in probe.find_children("*", "MeshInstance3D", true, false):
		reference[String(mi.name)] = mi.material_override
	probe.free()
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	var world := await start_world()
	var tm = world.get_node("TerritoryManager")
	var guardians: Array = tm.guardians.values().filter(func(d): return is_instance_valid(d))
	var wild := day_dinos(world)
	# 1 e 3. Dia: selvagens e guardioes com o visual original.
	check(wild.size() >= 2 and wild.all(func(d): return day_look(d)), "Dia: %d selvagens diurnos com as cores originais" % wild.size())
	check(guardians.size() >= 1 and guardians.all(func(d): return day_look(d) and d.guardian_of != ""), "Dia: %d guardiao(oes) territorial(is) com visual proprio intacto" % guardians.size())
	# 4. Noite: todos os inimigos criados pela onda com a paleta noturna.
	var foes := await night_wave(world)
	var wm = world.get_node("WaveManager")
	check(foes.size() == wm.enemy_count and foes.size() > 0, "Onda da Noite 1 criou %d/%d inimigos (quantidade inalterada)" % [foes.size(), wm.enemy_count])
	check(foes.all(func(d): return night_look(d)), "Todos os inimigos da onda com a paleta azul-violeta em todas as malhas")
	# 2. Regra: selvagem que continua vivo a noite NAO fica roxo.
	var wild_night := day_dinos(world).filter(func(d): return not d.is_in_group("wave_enemy"))
	check(wild_night.size() >= 1 and wild_night.all(func(d): return day_look(d)), "Noite: %d selvagens diurnos ainda vivos mantem as cores originais" % wild_night.size())
	check(guardians.all(func(d): return not is_instance_valid(d) or day_look(d)), "Noite: guardioes continuam sem a paleta noturna")
	# 5. Leitura sob a luz da noite: corpo escuro, borda de luz, so os olhos brilham, sem neon.
	var body := foes[0].get_node("Visual/Body").material_override as StandardMaterial3D
	var eye := foes[0].get_node("Visual/Eye1").material_override as StandardMaterial3D
	check(body.get_meta("palette") == NIGHT_MAIN and body.albedo_color.is_equal_approx(VISUAL.night_albedo(NIGHT_MAIN)) and body.rim_enabled and not body.emission_enabled, "Corpo na paleta #18244D (albedo calibrado para o luar), borda de luz, sem emissao")
	check(eye.emission_enabled and eye.emission.is_equal_approx(NIGHT_ACCENT) and eye.emission_energy_multiplier <= 1.0, "So os olhos brilham, #6678C8, energia %.1f (sem neon)" % eye.emission_energy_multiplier)
	# Materiais compartilhados do modelo intocados.
	check(shared_untouched(), "Materiais compartilhados do modelo inalterados (corpo ainda terracota, sem emissao/borda)")
	# 2. Aliado: inimigo noturno domesticado volta as cores normais + marca de aliado.
	var hp_before: float = foes[1].hp
	foes[1].domesticate()
	await frames(2)
	var crest := foes[1].get_node("Visual/Crest").material_override as StandardMaterial3D
	check(day_look(foes[1], ["Crest"]) and crest.albedo_color.is_equal_approx(ALLY_CREST) and foes[1].get_node("Visual/Collar").visible, "Inimigo noturno domesticado: cores normais, crista jade e coleira de aliado")
	check(is_equal_approx(foes[1].hp, hp_before), "Domesticar nao muda a vida (%.0f)" % foes[1].hp)
	check(night_look(foes[0]) and night_look(foes[2]), "Os outros inimigos da onda continuam noturnos")
	# 6. Reiniciar a partida: mundo novo sem materiais trocados indevidamente.
	app.show_menu()
	await frames(5)
	world = await start_world()
	var fresh := day_dinos(world)
	var fresh_guardians: Array = world.get_node("TerritoryManager").guardians.values().filter(func(d): return is_instance_valid(d))
	check(fresh.size() >= 2 and fresh.all(func(d): return day_look(d)) and fresh_guardians.all(func(d): return day_look(d)), "Reinicio: selvagens e guardioes da nova partida com as cores originais")
	check(shared_untouched(), "Reinicio: materiais compartilhados do modelo continuam intactos")
	var foes2 := await night_wave(world)
	check(foes2.size() > 0 and foes2.all(func(d): return night_look(d)), "Reinicio: a onda da nova partida volta a ter a paleta noturna (%d)" % foes2.size())
	var body2 := foes2[0].get_node("Visual/Body").material_override as StandardMaterial3D
	check(body2.albedo_color.is_equal_approx(VISUAL.night_albedo(NIGHT_MAIN)) and not body2.emission_enabled, "Reinicio: material noturno sem alteracao acumulada")
	print("NIGHT LOOK RESULTS: %d passed; %d failed" % [passed.size(), failed.size()])
	if report != "":
		var f := FileAccess.open(report, FileAccess.WRITE)
		f.store_string(JSON.stringify({"passed": passed, "failed": failed}, "\t"))
		f.close()
	app.show_menu()
	get_tree().quit(0 if failed.is_empty() else 1)
