extends SceneTree

# Visual Overhaul 3.0: gera os modelos das criaturas (dino.tscn e carno.tscn)
# com as malhas de scenes/visuals/creature_forge.gd. Substitui a parte de
# dinossauros do antigo tools/build_visuals.py (esferas/caixas/cones).
#   Godot_console --headless --path . --script res://tools/build_creatures.gd
# Os nomes dos nos e um material por papel continuam os do modelo antigo:
# a paleta noturna (actor_visual.gd), os testes e as animacoes dependem deles.

const Forge := preload("res://scenes/visuals/creature_forge.gd")
const VISUAL_SCRIPT := preload("res://scenes/visuals/actor_visual.gd")

func _initialize() -> void:
	_build(Forge.WILD, "res://scenes/visuals/dino.tscn")
	_build(Forge.CARNO, "res://scenes/visuals/carno.tscn")
	_build_player("res://scenes/visuals/guardian.tscn") # o Player (nome antigo do arquivo)
	quit()

func _mat(color: Color, vertex := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.88
	m.vertex_color_use_as_albedo = vertex
	m.vertex_color_is_srgb = true
	return m

func _part(root: Node3D, parent: Node3D, label: String, mesh: Mesh, mat: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = label
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	# partes pequenas nao projetam sombra (desempenho; a sombra nem aparece)
	for small in ["Eye", "Pupil", "Teeth", "Claw", "Muzzle", "Crest", "HatBand", "Buckle", "Lantern", "Wrapping", "Straps"]:
		if label.begins_with(small):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.owner = root
	return mi

func _build(sp: Dictionary, path: String) -> void:
	var root := Node3D.new()
	root.name = "Visual"
	root.set_script(VISUAL_SCRIPT)
	var main := _mat(sp.main)
	var belly := _mat(sp.belly)
	var cream := _mat(sp.cream)
	var dark := _mat(Color(sp.main).darkened(0.35))
	var crest := _mat(sp.crest)
	var jade := _mat(sp.jade)
	var eye := _mat(sp.eye)
	var pupil := _mat(sp.dark, false)
	_part(root, root, "Body", Forge.body_mesh(sp), main)
	_part(root, root, "Belly", Forge.belly_mesh(sp), belly)
	_part(root, root, "Neck", Forge.neck_mesh(sp), main)
	_part(root, root, "Head", Forge.head_mesh(sp), main)
	_part(root, root, "Muzzle", Forge.brow_mesh(sp), main)
	_part(root, root, "Jaw", Forge.jaw_mesh(sp), main, Forge.JAW_PIVOT)
	_part(root, root, "Teeth", Forge.teeth_mesh(sp, false), cream)
	var jaw := root.get_node("Jaw") as Node3D
	_part(root, jaw, "TeethLow", Forge.teeth_mesh(sp, true), cream)
	_part(root, root, "Tail", Forge.tail_mesh(sp), main, Forge.TAIL_PIVOT)
	_part(root, root, "Crest", Forge.crest_mesh(sp), crest)
	var collar := _part(root, root, "Collar", Forge.collar_mesh(), jade)
	collar.visible = false
	var L: float = sp.head_len
	for side in [-1, 1]:
		var tag := str(side) # "-1" / "1": nomes antigos (Eye-1, Eye1...)
		var e := _part(root, root, "Eye" + tag, Forge.eye_mesh(), eye, Vector3(side * 0.2, 1.8, -0.6 - 0.2 * L))
		var p := _part(root, root, "Pupil" + tag, Forge.pupil_mesh(), pupil, Vector3(side * 0.235, 1.8, -0.6 - 0.2 * L))
		if side < 0:
			e.rotation.y = PI
			p.rotation.y = PI
		_part(root, root, "Arm" + tag, Forge.arm_mesh(side, sp), main)
		if sp.horns:
			_part(root, root, "Horn" + tag, Forge.horn_mesh(side), cream)
		var leg := Node3D.new()
		leg.name = "LegL" if side < 0 else "LegR"
		leg.position = Vector3(Forge.HIP.x * side * Vector3(sp.body_scale).x, Forge.HIP.y, Forge.HIP.z)
		root.add_child(leg)
		leg.owner = root
		_part(root, leg, "Thigh" + tag, Forge.thigh_mesh(sp), main)
		_part(root, leg, "Shin" + tag, Forge.shin_mesh(sp), main)
		_part(root, leg, "Foot" + tag, Forge.foot_mesh(sp), dark)
		var toes := [Vector3(-0.09, 0, -0.2), Vector3(0, 0, -0.26), Vector3(0.09, 0, -0.2)]
		# tres garras numa malha so (menos chamadas de desenho)
		var claws := SurfaceTool.new()
		claws.begin(Mesh.PRIMITIVE_TRIANGLES)
		for t in toes.size():
			claws.append_from(Forge.claw_mesh(toes[t]), 0, Transform3D.IDENTITY)
		_part(root, leg, "Claw" + tag, claws.commit(), cream)
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err == OK:
		err = ResourceSaver.save(scene, path)
	print("[CRIATURAS] %s: %s" % [path, "ok" if err == OK else "ERRO %d" % err])
	root.free()

func _build_player(path: String) -> void:
	var c: Dictionary = Forge.EXPLORER
	var root := Node3D.new()
	root.name = "Visual"
	root.set_script(VISUAL_SCRIPT)
	var m := {}
	for k in c:
		m[k] = _mat(c[k])
	m["glow"] = _mat(Color("a8e6cf"))
	m["glow"].emission_enabled = true
	m["glow"].emission = Color("7fd8b0")
	m["glow"].emission_energy_multiplier = 0.6
	_part(root, root, "Tunic", Forge.x_tunic(), m.tunic)
	_part(root, root, "Vest", Forge.x_vest(), m.vest)
	_part(root, root, "Belt", Forge.x_belt(), m.vest)
	_part(root, root, "Buckle", Forge.x_lantern(), m.band, Vector3(-0.24, -0.18, -0.6))
	_part(root, root, "Head", Forge.x_head(), m.skin)
	_part(root, root, "Hair", Forge.x_hair(), m.hair)
	_part(root, root, "Hat", Forge.x_hat(), m.hat)
	_part(root, root, "HatBand", Forge.x_hat_band(), m.band)
	_part(root, root, "Scarf", Forge.x_scarf(), m.scarf)
	_part(root, root, "ScarfTail", Forge.x_scarf_tail(), m.scarf)
	_part(root, root, "Cape", Forge.x_cape(), m.cape, Vector3(0, 1.38, 0.24))
	_part(root, root, "Satchel", Forge.x_pack(), m.pack)
	_part(root, root, "Bedroll", Forge.x_roll(), m.roll)
	_part(root, root, "Straps", Forge.x_strap(), m.strap)
	_part(root, root, "Lantern", Forge.x_lantern(), m.glow)
	for side in [-1, 1]:
		var tag := "L" if side < 0 else "R"
		_part(root, root, "Eye" + str(side), Forge.x_eye(), m.eye, Vector3(side * 0.095, 1.68, -0.235))
		var leg := Node3D.new()
		leg.name = "Leg" + tag
		leg.position = Vector3(Forge.HIP_P.x * side, Forge.HIP_P.y, Forge.HIP_P.z)
		root.add_child(leg)
		leg.owner = root
		_part(root, leg, "Leg" + tag + "Part", Forge.x_leg(), m.pants)
		_part(root, leg, "Leg" + tag + "Boot", Forge.x_boot(), m.boots)
		var arm := Node3D.new()
		arm.name = "Arm" + tag
		arm.position = Vector3(Forge.SHOULDER.x * side, Forge.SHOULDER.y, Forge.SHOULDER.z)
		root.add_child(arm)
		arm.owner = root
		_part(root, arm, "Arm" + tag + "Part", Forge.x_sleeve(), m.tunic)
		_part(root, arm, "Arm" + tag + "Bracer", Forge.x_bracer(), m.vest)
		_part(root, arm, "Arm" + tag + "Hand", Forge.x_hand(), m.skin)
		if side > 0:
			_part(root, arm, "Haft", Forge.x_haft(), m.wood)
			_part(root, arm, "Hatchet", Forge.x_axe_head(), m.stone)
			_part(root, arm, "Wrapping", Forge.x_wrap(), m.strap)
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err == OK:
		err = ResourceSaver.save(scene, path)
	print("[CRIATURAS] %s: %s" % [path, "ok" if err == OK else "ERRO %d" % err])
	root.free()
