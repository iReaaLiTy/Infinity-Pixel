extends CharacterBody3D

# Spec: docs/specs/002-dinossauro-selvagem.md
# RF-AGE-003 — Spawn e avanco ate o territorio (CONFIRMADO)
# RF-AGE-004 — Deteccao e ataque corpo a corpo (PROVISORIO)
# Spec: docs/specs/003-domesticacao.md — RF-AGE-017 (is_domesticable)
# Spec: docs/specs/004-dinossauro-domesticado.md — RF-AGE-007/008 (aliado)
# Spec: docs/specs/006-ciclo-dia-noite.md — RF-AGE-018 (buff noturno)

const MAX_HP := 80.0 # RF-AGE-004 valor inicial. Teto de teste: ate 120.
const BASE_ATTACK_DAMAGE := 15.0 # RF-AGE-004 valor inicial. Teto de teste: ate 25.
const ATTACK_COOLDOWN := 1.0 # RF-AGE-004 valor inicial. Minimo de teste: 0,6 s.
const DETECTION_RANGE := 8.0 # RF-AGE-004 valor inicial. Teto de teste: ate 12.
const BASE_SPEED := 4.0 # RF-AGE-004 valor inicial. Teto de teste: 5,5 (sempre < 6 do jogador).
# NAO esta na Spec 002: alcance do golpe do inimigo. Provisorio, espelha os 2 m do jogador.
const ATTACK_REACH := 2.0
const TERRITORY_ARRIVAL_DISTANCE := 1.5 # distancia em que considera ter "chegado" ao territorio
const GRAVITY := 9.8
# Spec 003 RF-AGE-005 valor inicial: 30% de vida restante. Faixa de teste: 20% a 40%.
const DOMESTICATION_HP_FRACTION := 0.3
# RF-AGE-008 valor inicial: 8 m de raio de defesa a partir do ponto de "ficar".
const DEFENSE_RADIUS := 8.0
# NAO esta na Spec 004: distancia em que o aliado para de seguir o jogador. Provisorio.
const ALLY_FOLLOW_STOP_DISTANCE := 2.5
# NAO esta na Spec 004: alcance para o comando "ficar" atingir o aliado. Provisorio,
# reaproveita a mesma ordem de grandeza do alcance de domesticacao (3 m).
const ALLY_COMMAND_RANGE := 3.0

enum AllyState { FOLLOWING, STAYING }

# Usados pelo WaveManager para saber quando um inimigo da onda deixou de ser ameaca.
signal died(dino: Node3D)
signal domesticated(dino: Node3D)
# F recusado (noite/fim de jogo). Para feedback na interface.
signal command_rejected

@export var is_domesticable := true # RF-AGE-017: propriedade explicita, nao depende do nome do node/cena.
# AC1 (GDD secoes 3 e 6): encontro diurno domesticavel. Territorial = nao avanca
# ate a base; so persegue alvos dentro de leash_radius do ponto de origem e depois
# volta para ele. Inimigos de onda/teste usam o padrao (false) e nao mudam.
@export var territorial := false
@export var leash_radius := 12.0 # NAO esta em Spec: provisorio para o encontro AC1.

@onready var hp_label: Label3D = $HpLabel3D
@onready var prompt_label: Label3D = $PromptLabel3D
@onready var mesh: MeshInstance3D = $MeshInstance3D

var hp: float = MAX_HP
var is_domesticated := false
var is_being_domesticated := false # RF-AGE-006: true durante a canalizacao (segurando E)
var ally_state: AllyState = AllyState.FOLLOWING # RF-AGE-007
var _stay_position: Vector3
var _territory: Node3D
var _target: Node3D
var _attack_cooldown_left := 0.0
var _arrived := false
var _attack_announced := false # log "[ALIADO] Atacando" uma vez por alvo
var _returning_to_post := false # log "[ALIADO] Retornando" uma vez apos cada combate
var home_position: Vector3 # origem do encontro territorial (capturada no _ready)

func _ready() -> void:
	add_to_group("damageable") # ADR 0001
	add_to_group("wild_dino")
	home_position = global_position
	_territory = get_tree().get_first_node_in_group("territory") as Node3D
	if _territory == null and not territorial:
		push_warning("WildDino: nenhum no no grupo 'territory' na cena; o dinossauro nao tem para onde avancar.")
	_update_label()

func _physics_process(delta: float) -> void:
	if not DayNightManager.can_play():
		return
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta

	if is_domesticated:
		_process_ally(delta)
		return

	if is_being_domesticated:
		# RF-AGE-006: enquanto o Player canaliza a domesticacao, o WildDino fica
		# parado e nao ataca (nem persegue), mas continua vivo e sem queue_free().
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	_target = _find_nearest_target()

	var move_dir := Vector3.ZERO
	if _target != null:
		# RF-AGE-004: ameaca detectada — deixa de seguir para o territorio e vai ate o alvo.
		var to_target := _flat_offset(_target.global_position)
		if to_target.length() > ATTACK_REACH:
			move_dir = to_target.normalized()
		_face(to_target)
		if to_target.length() <= ATTACK_REACH:
			_try_attack(_target)
		_arrived = false
	elif territorial:
		# Encontro diurno: sem alvo, volta ao ponto de origem e fica ali.
		var to_home := _flat_offset(home_position)
		if to_home.length() > 0.5:
			move_dir = to_home.normalized()
			_face(to_home)
	elif _territory != null:
		var to_territory := _flat_offset(_territory.global_position)
		if to_territory.length() > TERRITORY_ARRIVAL_DISTANCE:
			move_dir = to_territory.normalized()
			_face(to_territory)
			_arrived = false
		else:
			if not _arrived:
				_arrived = true
				print("%s chegou ao territorio." % name)
			# RF-AGE-012: dinossauro que chega a base passa a ataca-la (mesmo padrao
			# de cooldown do ataque ao jogador, reaproveitando _try_attack).
			_try_attack(_territory)

	velocity.x = move_dir.x * _current_speed()
	velocity.z = move_dir.z * _current_speed()
	move_and_slide()

# Spec 004 RF-AGE-008: o aliado mantem o mesmo HP/atributos de selvagem e pode
# ser ferido por hostis. O jogador nao fere aliados (filtro em player.gd).
func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return # ja derrotado neste frame (queue_free pendente)
	$Visual.flash()
	hp -= amount
	if is_domesticated:
		print("[ALIADO] recebeu %.0f de dano. HP: %.0f/%.0f" % [amount, maxf(hp, 0.0), MAX_HP])
	else:
		print("%s recebeu %.0f de dano. HP: %.0f/%.0f" % [name, amount, maxf(hp, 0.0), MAX_HP])
	_update_label()
	if hp <= 0.0:
		if is_domesticated:
			print("[ALIADO] %s foi derrotado" % name)
			remove_from_group("domesticated") # hostis param de mira-lo ja neste frame
		else:
			print("%s foi derrotado." % name)
		died.emit(self)
		queue_free()

# RF-AGE-005 + RF-AGE-017: precisa de vida no limiar ou abaixo E ser de uma
# especie/variante domesticavel (`is_domesticable`), consultado diretamente
# aqui — nunca por nome de node ou de cena.
func can_be_domesticated() -> bool:
	return is_domesticable and not is_domesticated and hp > 0.0 and hp <= MAX_HP * DOMESTICATION_HP_FRACTION

# RF-AGE-006: chamado quando a canalizacao termina. Mantem a vida atual (a Spec nao
# define cura ao domesticar).
func domesticate() -> void:
	hp = maxf(hp, 1.0) # garante que nunca fique com 0 HP ao concluir a domesticacao
	is_being_domesticated = false
	is_domesticated = true
	ally_state = AllyState.FOLLOWING # RF-AGE-007: comeca seguindo o jogador
	print("%s foi domesticado com %.0f/%.0f HP (nao removido)." % [name, hp, MAX_HP])
	print("[DOMESTICACAO] Estado: DOMESTICADO")
	print("[ALIADO] %s domesticado" % name)
	print("[ALIADO] Modo: SEGUINDO")
	remove_from_group("wild_dino")
	add_to_group("domesticated") # alvo dos selvagens, aliado do jogador (Spec 004)
	name = "DinoDomesticado"
	prompt_label.text = ""
	$Visual.set_ally()
	get_tree().call_group("audio_director", "effect", true)
	_update_label()
	domesticated.emit(self)

func set_prompt(text: String) -> void:
	prompt_label.text = text

# RF-AGE-007/RF-AGE-008: comportamento de aliado (seguir/ficar + defesa por area).
func _process_ally(delta: float) -> void:
	var player := _find_player()

	# F alterna seguir/ficar. is_action_just_pressed garante uma unica troca por pressao.
	if player != null and Input.is_action_just_pressed("command_stay") \
			and _flat_offset(player.global_position).length() <= ALLY_COMMAND_RANGE:
		if not DayNightManager.can_command_allies():
			# Spec 005 RF-AGE-009: com a onda em andamento nao e permitido reposicionar.
			print("[ALIADO] Comando F ignorado: reposicionar nao e permitido durante a noite/fim de jogo.")
			command_rejected.emit()
		else:
			_target = null
			_returning_to_post = false
			if ally_state == AllyState.FOLLOWING:
				ally_state = AllyState.STAYING
				_stay_position = global_position
				print("[ALIADO] Modo alterado: FICAR")
				print("[ALIADO] Posição de defesa definida: %s" % _stay_position)
			else:
				ally_state = AllyState.FOLLOWING
				print("[ALIADO] Modo alterado: SEGUINDO")

	match ally_state:
		AllyState.FOLLOWING:
			_ally_follow(player)
		AllyState.STAYING:
			_ally_defend(delta)

func _ally_follow(player: Node3D) -> void:
	var move_dir := Vector3.ZERO
	if player != null:
		var to_player := _flat_offset(player.global_position)
		if to_player.length() > ALLY_FOLLOW_STOP_DISTANCE:
			move_dir = to_player.normalized()
			_face(to_player)
	velocity.x = move_dir.x * BASE_SPEED
	velocity.z = move_dir.z * BASE_SPEED
	move_and_slide()

func _ally_defend(delta: float) -> void:
	# Alvo atual deixa de valer se morreu, foi domesticado (saiu de "wild_dino") ou
	# saiu do raio de defesa em volta do ponto de "ficar" (RF-AGE-008).
	if _target != null:
		if not is_instance_valid(_target):
			_target = null # derrotado (queue_free)
		elif not _is_valid_defense_target(_target):
			if _target.is_in_group("wild_dino"):
				print("[ALIADO] Alvo saiu da área - retornando")
			_target = null
	if _target == null:
		_target = _find_nearest_wild_dino_in_radius(_stay_position, DEFENSE_RADIUS)
		if _target != null:
			print("[ALIADO] Inimigo detectado: %s" % _target.name)
			_attack_announced = false
			_returning_to_post = true

	var move_dir := Vector3.ZERO
	if _target != null:
		var to_target := _flat_offset(_target.global_position)
		if to_target.length() > ATTACK_REACH:
			move_dir = to_target.normalized()
		_face(to_target)
		if to_target.length() <= ATTACK_REACH:
			if not _attack_announced:
				_attack_announced = true
				print("[ALIADO] Atacando: %s" % _target.name)
			_try_attack(_target)
	else:
		var to_stay := _flat_offset(_stay_position)
		if to_stay.length() > 0.2:
			if _returning_to_post:
				_returning_to_post = false
				print("[ALIADO] Retornando à posição de defesa")
			move_dir = to_stay.normalized()
			_face(to_stay)
		else:
			_returning_to_post = false

	velocity.x = move_dir.x * BASE_SPEED
	velocity.z = move_dir.z * BASE_SPEED
	move_and_slide()

func _is_valid_defense_target(target: Node3D) -> bool:
	return target != self and target.is_in_group("wild_dino") \
		and _flat_offset_from(_stay_position, target.global_position).length() <= DEFENSE_RADIUS

func _find_player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D

func _find_nearest_wild_dino_in_radius(center: Vector3, radius: float) -> Node3D:
	var nearest: Node3D = null
	var nearest_dist := radius
	for candidate in get_tree().get_nodes_in_group("wild_dino"):
		var dino := candidate as Node3D
		if dino == null or not is_instance_valid(dino):
			continue
		var dist := _flat_offset_from(center, dino.global_position).length()
		if dist <= nearest_dist:
			nearest = dino
			nearest_dist = dist
	return nearest

func _find_nearest_target() -> Node3D:
	var nearest: Node3D = null
	var nearest_dist := DETECTION_RANGE
	for group_name in ["player", "domesticated"]:
		for candidate in get_tree().get_nodes_in_group(group_name):
			var body := candidate as Node3D
			if body == null or not is_instance_valid(body):
				continue
			if territorial and _flat_offset_from(home_position, body.global_position).length() > leash_radius:
				continue # encontro territorial nao persegue para fora da sua area
			var dist := _flat_offset(body.global_position).length()
			if dist <= nearest_dist:
				nearest = body
				nearest_dist = dist
	return nearest

func _try_attack(target: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		return
	if _attack_cooldown_left > 0.0:
		return # RF-AGE-004: cooldown ainda ativo, ataque nao e acionado
	if not target.has_method("take_damage"):
		return
	$Visual.strike()
	_attack_cooldown_left = ATTACK_COOLDOWN
	print("%s atacou %s." % [name, target.name])
	target.take_damage(_current_attack_damage())

# RF-AGE-018: dano/velocidade sempre calculados a partir do valor-base; nunca
# acumulam entre noites. Aliados (is_domesticated) nunca recebem o buff, mesmo
# chamando _try_attack/_current_attack_damage na defesa por area (RF-AGE-008).
func _current_attack_damage() -> float:
	if is_domesticated:
		return BASE_ATTACK_DAMAGE
	if DayNightManager.is_night():
		return BASE_ATTACK_DAMAGE * DayNightManager.night_damage_multiplier
	return BASE_ATTACK_DAMAGE

func _current_speed() -> float:
	if DayNightManager.is_night():
		return BASE_SPEED * DayNightManager.night_speed_multiplier
	return BASE_SPEED

func _flat_offset(world_pos: Vector3) -> Vector3:
	var offset := world_pos - global_position
	offset.y = 0.0
	return offset

func _flat_offset_from(origin: Vector3, world_pos: Vector3) -> Vector3:
	var offset := world_pos - origin
	offset.y = 0.0
	return offset

func _face(flat_dir: Vector3) -> void:
	if flat_dir.length_squared() > 0.0001:
		look_at(global_position + flat_dir, Vector3.UP)

func _update_label() -> void:
	var status := "ALIADO" if is_domesticated else ("SELVAGEM" if is_domesticable else "CARNOTAURO • NÃO DOMESTICÁVEL")
	hp_label.text = "%s  ·  %d/%d" % [status, maxi(int(hp), 0), int(MAX_HP)]
	hp_label.modulate = Color("a5e7c3") if is_domesticated else Color("fff0cf")
