extends Node3D

# Spec: docs/specs/013d-inventario-construcao-cura.md — RF-CON-006 / 007 (PROVISORIO)
#
# Armadilha de Espinhos: Area3D baixa (mascara: criaturas), SEM corpo solido e
# SEM obstaculo de navegacao — os inimigos passam por cima normalmente (navmesh
# intacta, sem rebake). So fere inimigos validos da ONDA (mesmo filtro das
# torres): nunca Player, aliados, domesticados, selvagens diurnos ou o refugio.
# 15 de dano por ativacao, no maximo 1 ativacao por inimigo por passagem e um
# intervalo curto entre ativacoes. 3 cargas: esgotada, quebra e some.

signal triggered(enemy: Node3D)
signal depleted

const DAMAGE := 15.0
const MAX_CHARGES := 3
const REARM := 0.35 # s entre ativacoes (nada de dezenas de hits no mesmo quadro)
const CREATURES := 1 << 2
const DefenseTower := preload("res://scenes/world/defense_tower.gd")

@export var preview := false

var charges := MAX_CHARGES
var _rearm_left := 0.0
var _area: Area3D
var _hit_this_passage := {} # corpo -> true enquanto estiver sobre a armadilha
var _spikes: Array[MeshInstance3D] = []
var _broken := false
var _spike_mat: StandardMaterial3D # Spec 014: mesma cor, leve brilho a noite

func _ready() -> void:
	_build_visual()
	if preview:
		set_physics_process(false)
		return
	add_to_group("built_structure")
	add_to_group("spike_trap")
	add_to_group("night_glow") # Spec 014: DayNightVisual chama set_night_glow()
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = CREATURES
	_area.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.0, 1.6)
	shape.shape = box
	shape.position.y = 0.5
	_area.add_child(shape)
	add_child(_area)
	_area.body_exited.connect(func(body): _hit_this_passage.erase(body))

func _physics_process(delta: float) -> void:
	if _broken or not DayNightManager.can_play():
		return
	_rearm_left = maxf(_rearm_left - delta, 0.0)
	if _rearm_left > 0.0:
		return
	for body in _area.get_overlapping_bodies():
		if DefenseTower.is_valid_target(body) and not _hit_this_passage.has(body):
			_trigger(body)
			return # uma ativacao por intervalo

func _trigger(enemy: Node3D) -> void:
	_hit_this_passage[enemy] = true
	_rearm_left = REARM
	charges -= 1
	print("[ARMADILHA] %s recebeu %.0f (cargas %d/%d)" % [enemy.name, DAMAGE, charges, MAX_CHARGES])
	enemy.take_damage(DAMAGE)
	triggered.emit(enemy)
	_snap()
	if charges <= 0:
		_break()

# Espinhos saltam e voltam: feedback de ativacao.
func _snap() -> void:
	for s in _spikes:
		var t := s.create_tween()
		t.tween_property(s, "position:y", s.position.y + 0.18, 0.06)
		t.tween_property(s, "position:y", s.position.y, 0.2)

# RF-CON-007: depois de 3 ativacoes quebra e some (libera o limite de 3).
func _break() -> void:
	_broken = true
	remove_from_group("built_structure")
	remove_from_group("spike_trap")
	print("[ARMADILHA] esgotada")
	depleted.emit()
	var t := create_tween()
	t.tween_property(self, "scale", Vector3(1.2, 0.05, 1.2), 0.35)
	t.tween_callback(queue_free)

func is_broken() -> bool:
	return _broken

# --- visual low-poly baixo: estrado de madeira, pontas e pedras de apoio ------
func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m

func _build_visual() -> void:
	var plank := BoxMesh.new()
	plank.size = Vector3(1.5, 0.08, 0.3)
	for i in 4:
		var p := MeshInstance3D.new()
		p.mesh = plank
		p.material_override = _mat(Color("7a5a3a") if i % 2 == 0 else Color("6a4f37"))
		p.position = Vector3(0, 0.05, -0.5 + i * 0.33)
		add_child(p)
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.07
	spike.height = 0.3
	spike.radial_segments = 4
	_spike_mat = _mat(Color("d9c9a8"))
	_spike_mat.emission_enabled = true
	_spike_mat.emission = Color("d9c9a8")
	_spike_mat.emission_energy_multiplier = 0.0
	for x in 3:
		for z in 3:
			var s := MeshInstance3D.new()
			s.mesh = spike
			s.material_override = _spike_mat
			s.position = Vector3(-0.45 + x * 0.45, 0.24, -0.45 + z * 0.45)
			add_child(s)
			_spikes.append(s)
	var rock := SphereMesh.new()
	rock.radius = 0.5
	rock.height = 1.0
	rock.radial_segments = 6
	rock.rings = 3
	for c in [Vector3(-0.8, 0.08, -0.7), Vector3(0.8, 0.08, 0.7), Vector3(0.8, 0.08, -0.7), Vector3(-0.8, 0.08, 0.7)]:
		var r := MeshInstance3D.new()
		r.mesh = rock
		r.material_override = _mat(Color("8d9a8f"))
		r.scale = Vector3(0.26, 0.18, 0.24)
		r.position = c
		add_child(r)

# Spec 014 RF-CEU-010: a noite as pontas ficam levemente claras para a armadilha
# continuar legivel. Sem luz propria; dano e cargas nao leem isto.
func set_night_glow(f: float) -> void:
	_spike_mat.emission_energy_multiplier = 0.35 * f
