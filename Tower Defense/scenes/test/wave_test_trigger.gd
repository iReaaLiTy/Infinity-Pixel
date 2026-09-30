extends Node3D

# Gatilho TEMPORARIO de teste — nao pertence a nenhuma Spec.
# A onda real (Spec 005) e disparada por "Iniciar Noite" (Spec 006), via
# WaveManager. Este gatilho (tecla T) spawna sob demanda o WildDino domesticavel
# (enemy_scene na cena) para testar a domesticacao (Unidade 3). Para testar a
# variante nao domesticavel (RF-AGE-017), troque enemy_scene no Inspector para
# res://scenes/enemies/carnotauro.tscn.

# DEPURACAO: desligue aqui para desativar T. Mesmo ligado, so funciona em build
# de depuracao (editor/export debug) — nunca e necessario para o loop da AC1.
@export var debug_enabled := false
@export var enemy_scene: PackedScene
# NodePath (texto) em vez de referencia direta ao no: e resolvido aqui com
# get_node_or_null, o que e confiavel mesmo em cena editada a mao.
@export var spawn_point_path: NodePath = ^"../EnemySpawnPoint"

var _spawn_point: Node3D
var _current_enemy: Node3D

func _ready() -> void:
	_spawn_point = get_node_or_null(spawn_point_path) as Node3D
	if _spawn_point == null:
		push_error("WaveTestTrigger: ponto de spawn nao encontrado em '%s' (relativo a %s)." % [spawn_point_path, get_path()])
	if enemy_scene == null:
		push_error("WaveTestTrigger: enemy_scene nao configurada.")

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("test_spawn_enemy"):
		return
	if not debug_enabled or not OS.is_debug_build() or not DayNightManager.can_play():
		return
	if _spawn_point == null or enemy_scene == null:
		push_error("WaveTestTrigger: spawn cancelado, configuracao incompleta (ver erros do inicio).")
		return
	# Teste controlado: no maximo um dinossauro SELVAGEM de teste ativo. T remove o
	# anterior (se ainda for selvagem) e cria um novo, servindo tambem como "reiniciar
	# teste". Um dinossauro ja domesticado (Spec 003) e aliado e nao e removido.
	if is_instance_valid(_current_enemy) and _current_enemy.is_in_group("wild_dino"):
		_current_enemy.get_parent().remove_child(_current_enemy) # sai da arvore ja (libera o nome e para a IA)
		_current_enemy.queue_free()
		print("[Teste] dinossauro anterior removido.")
	var enemy := enemy_scene.instantiate() as Node3D
	get_parent().add_child(enemy)
	enemy.global_position = _spawn_point.global_position
	_current_enemy = enemy
	print("[Teste] %s spawnado em %s" % [enemy.name, _spawn_point.global_position])
