extends Node

# World 6.0 — barras de vida das criaturas, pegadas do Player, inventario e
# menu fosseis e o mundo expandido (regioes, cachoeira, vulcao, navegacao).
# Os valores de jogo sao comparados com as constantes originais.
# Uso: Godot [--headless] --path . res://tests/world6.tscn [-- --report=<arquivo>]
# Sem janela, as verificacoes de layout em 1280x720/1600x900/1920x1080 viram
# SKIP (nao contam como aprovadas); a rodada com janela as executa.

const WILD := preload("res://scenes/enemies/wild_dino.tscn")
const WildDino := preload("res://scenes/enemies/wild_dino.gd")
const WorldBiomes := preload("res://scenes/world/world_biomes.gd")
const Footprints := preload("res://scenes/world/player_footprints.gd")

var passed := []
var failed := []
var skipped := []
var app
var world
var player

func check(ok: bool, label: String) -> void:
	(passed if ok else failed).append(label)
	print(("PASS: " if ok else "FAIL: ") + label)

func skip(label: String) -> void:
	skipped.append(label)
	print("SKIP: " + label)

func frames(n := 3) -> void:
	for i in n: await get_tree().process_frame

func physics(n := 3) -> void:
	for i in n: await get_tree().physics_frame

func headless() -> bool:
	return DisplayServer.get_name() == "headless"

func _ready() -> void:
	var report := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report = arg.trim_prefix("--report=")
	app = load("res://scenes/ui/main.tscn").instantiate()
	add_child(app)
	await frames(10)
	if has_method("menu_checks"): await call("menu_checks")
	app.start_game()
	await frames(20)
	world = app.world
	player = world.get_node("Player")
	player._invulnerable_left = INF
	DayNightManager.clock_hold = true
	await health_bar_checks()
	await footprint_checks()
	if has_method("inventory_checks"): await call("inventory_checks")
	if has_method("map_checks"): await call("map_checks")
	print("WORLD6 RESULTS: %d passed; %d failed; %d skipped" % [passed.size(), failed.size(), skipped.size()])
	if report != "":
		var f := FileAccess.open(report, FileAccess.WRITE)
		f.store_string(JSON.stringify({"passed": passed, "failed": failed, "skipped": skipped}, "\t"))
		f.close()
	DayNightManager.clock_hold = false
	app.show_menu()
	get_tree().quit(0 if failed.is_empty() else 1)

func dino_at(offset: Vector3, ally := false) -> Node:
	var d = WILD.instantiate()
	world.add_child(d)
	d.global_position = player.global_position + offset
	d.set_physics_process(false)
	if ally:
		d.domesticate()
	return d

func bar_of(d: Node):
	return d.hp_label.get_node_or_null("HealthBar")

# --- Barras de vida -------------------------------------------------------------
func health_bar_checks() -> void:
	player.global_position = Vector3(0, 0.1, -9)
	await physics(2)
	var ally = dino_at(Vector3(1.4, 0.4, 0.6), true)
	await frames(4)
	var bar = bar_of(ally)
	check(bar != null and ally.hp_label.visible and ally.hp_label.text == "ALIADO  ·  80/80", "Aliado em foco: identificacao + numero (80/80) e barra grafica")
	check(bar != null and is_equal_approx(bar.target, 1.0) and bar.faction == &"ally", "100%: barra cheia na cor jade do aliado")
	ally.take_damage(40.0)
	await frames(2)
	check(ally.hp_label.text.ends_with("40/80") and is_equal_approx(bar.target, 0.5) and bar.shown > 0.55, "Dano: numero atualiza na hora (40/80); barra desce suave (%.2f ainda)" % bar.shown)
	check(bar.ghost >= 0.99 and bar._flash > 0.5, "Dano: rastro claro do valor anterior e piscada do golpe")
	for i in 60: await get_tree().process_frame
	check(is_equal_approx(bar.shown, 0.5) and bar.ghost < 0.9, "50%%: barra chega a metade; o rastro desce (%.2f)" % bar.ghost)
	ally.take_damage(28.0)
	for i in 60: await get_tree().process_frame
	check(ally.hp_label.text.ends_with("12/80") and bar.shown < 0.2, "HP critico: 12/80 e barra curta (%.2f)" % bar.shown)
	var hp_before: float = ally.hp
	var healed: float = ally.heal_ally(30.0)
	await frames(2)
	check(healed == 30.0 and ally.hp == hp_before + 30.0 and bar._heal > 0.5 and bar.shown < bar.target, "Cura: valor real +30 (regra intacta), brilho jade e barra subindo suave")
	for i in 90: await get_tree().process_frame
	check(is_equal_approx(bar.shown, 42.0 / 80.0), "Cura: barra chega a 42/80")
	check(WildDino.MAX_HP == 80.0, "Vida maxima das criaturas inalterada (80)")
	# Faccoes: selvagem (terracota), guardiao (ambar), invasor (azul-violeta).
	var wild = dino_at(Vector3(-2.5, 0.4, 1.0))
	wild.take_damage(10.0)
	var guard = dino_at(Vector3(3.0, 0.4, -1.5))
	guard.guardian_of = "TESTE"
	guard._update_label()
	var foe = dino_at(Vector3(-3.5, 0.4, -2.5))
	foe.add_to_group("wave_enemy")
	await frames(4)
	check(bar_of(wild) != null and bar_of(wild).faction == &"wild" and wild.hp_label.visible, "Selvagem golpeado: barra terracota visivel")
	check(bar_of(guard) != null and bar_of(guard).faction == &"guardian", "Guardiao em confronto (perto): barra ambar")
	check(bar_of(foe) != null and bar_of(foe).faction == &"invader", "Invasor: barra azul-violeta")
	var tones = preload("res://scenes/visuals/creature_health_bar.gd").TONES
	check(tones[&"ally"] != tones[&"wild"] and tones[&"wild"] != tones[&"guardian"] and tones[&"guardian"] != tones[&"invader"], "Quatro cores de faccao distintas")
	# Selvagem com vida cheia e longe: escondido (sem poluir a tela).
	var calm = dino_at(Vector3(10.0, 0.4, 6.0))
	await frames(4)
	check(not calm.hp_label.visible, "Selvagem calmo e longe: sem rotulo nem barra")
	# Onda grande: no maximo MAX_LABELS rotulos ao mesmo tempo.
	var horde := []
	for i in 16:
		var h = dino_at(Vector3(-6.0 + (i % 4) * 4.0, 0.4, -6.0 + (i / 4) * 3.0))
		h.add_to_group("wave_enemy")
		horde.append(h)
	await frames(4)
	var shown := 0
	var bars := 0
	for d in get_tree().get_nodes_in_group("wild_dino"):
		if d.hp_label.visible and not d.hp_label.get_meta("bar_only", false): shown += 1
		elif d.hp_label.visible: bars += 1
	check(shown <= app.hud.MAX_LABELS and bars <= app.hud.MAX_BARS_ONLY, "Onda grande: %d rotulos com texto (limite %d) + %d so com a barra (limite %d)" % [shown, app.hud.MAX_LABELS, bars, app.hud.MAX_BARS_ONLY])
	check(bars > 0, "Onda grande: criaturas sem espaco para o texto ainda mostram a barra")
	# Varios aliados: so o em foco e os feridos aparecem.
	for h in horde + [wild, guard, foe, calm]:
		h.queue_free()
	ally.queue_free() # o primeiro aliado sai: o foco passa a ser o do time
	await frames(2)
	var team := []
	team.append(dino_at(Vector3(1.2, 0.4, 0.8), true)) # em foco (< 3,3 m)
	team.append(dino_at(Vector3(6.0, 0.4, 2.0), true)) # sadio e longe
	team.append(dino_at(Vector3(-6.0, 0.4, 3.0), true)) # ferido
	team[2].take_damage(30.0)
	await frames(4)
	var vis := team.filter(func(a): return a.hp_label.visible)
	check(vis.size() == 2 and team[0] in vis and team[2] in vis, "Varios aliados: foco + ferido visiveis, sadio distante escondido")
	for a in team:
		a.queue_free()
	await frames(2)
	# Domesticacao: o rotulo vira ALIADO e a barra troca de cor.
	var tamed = dino_at(Vector3(-1.5, 0.4, 1.2))
	tamed.take_damage(65.0)
	await frames(3)
	tamed.domesticate()
	await frames(3)
	check(tamed.hp_label.text.begins_with("ALIADO") and bar_of(tamed) != null and bar_of(tamed).faction == &"ally", "Domesticacao: rotulo ALIADO e barra jade")
	# Noite: barras continuam legiveis (sem luz, por cima da cena).
	var night_ok: bool = (bar_of(tamed).material_override as ShaderMaterial).shader.code.contains("unshaded")
	check(night_ok, "Noite: barra sem iluminacao (legivel no escuro)")
	for a in [tamed]:
		a.queue_free()
	await frames(2)

# --- Pegadas ----------------------------------------------------------------------
func walk(dir: Vector3, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		player.global_position += dir * 6.0 * (1.0 / 60.0)
		await get_tree().physics_frame
		t += 1.0 / 60.0

func footprint_checks() -> void:
	var prints = world.get_node_or_null("PlayerFootprints")
	check(prints != null and prints.multimesh != null and prints.multimesh.instance_count == Footprints.MAX_PRINTS, "Pegadas: uma MultiMesh com %d instancias fixas (pool)" % Footprints.MAX_PRINTS)
	if prints == null:
		return
	player.set_physics_process(false)
	player.global_position = Vector3(0, 0.1, -6)
	await physics(4)
	var before: int = prints.active
	await physics(30)
	check(prints.active == before, "Parado: nenhuma pegada nova")
	var first: int = prints._next
	await walk(Vector3(1, 0, 0), 1.0)
	var made: int = (prints._next - first + Footprints.MAX_PRINTS) % Footprints.MAX_PRINTS
	check(made >= 5 and made <= 9, "Andando 6 m: %d pegadas (passada de %.2f m), nao uma por quadro" % [made, Footprints.STRIDE])
	var a: Transform3D = prints.xforms[(prints._next - 1 + Footprints.MAX_PRINTS) % Footprints.MAX_PRINTS]
	var b: Transform3D = prints.xforms[(prints._next - 2 + Footprints.MAX_PRINTS) % Footprints.MAX_PRINTS]
	check(signf(a.basis.determinant()) != signf(b.basis.determinant()) and absf(a.origin.z - b.origin.z) > 0.15, "Alterna pe esquerdo e direito (lados opostos da trilha)")
	var forward := a.basis.z.normalized()
	check(forward.x > 0.95, "Pegada virada para a direcao real do movimento (+X)")
	check(a.origin.x < player.global_position.x, "Pegada atras dos pes")
	# Superficies por regiao.
	var spots := {&"forest": Vector2(-22.0, 14.0), &"stone": Vector2(27.0, 12.0), &"water": WorldBiomes.LAKE_CENTER + Vector2(WorldBiomes.LAKE_RADII.x + 1.2, 0.0), &"volcano": Vector2(10.0, -35.0)}
	for s in spots:
		check(WorldBiomes.surface_at(spots[s]) == s, "Superficie %s reconhecida em %s" % [s, spots[s]])
	check(Footprints.TONES[&"stone"].a < Footprints.TONES[&"forest"].a and Footprints.TONES[&"water"].a > Footprints.TONES[&"forest"].a, "Pedra mais sutil (poeira); margem mais escura (umida)")
	# Desaparece aos poucos e respeita o limite.
	await walk(Vector3(0, 0, -1), 8.0)
	check(prints.active <= Footprints.MAX_PRINTS and prints.node_count() == 1, "Limite: %d pegadas ativas (max %d), nenhum no acumulado" % [prints.active, Footprints.MAX_PRINTS])
	await physics(int((Footprints.LIFE + 1.0) * 60))
	check(prints.active == 0, "Pegadas antigas somem sozinhas")
	player.set_physics_process(true)
